/// Data-driven SMS detection rules.
///
/// Everything the app knows about *which* messages are transactions — sender
/// IDs, keyword gates, where the amount sits — used to be literals inside
/// `SmsParserService`. That baked one person's bank (BK) and one person's
/// telco into the code. A rule moves all of it into data that ships as a
/// built-in pack, can be disabled, and can be added to by the user without
/// touching Dart.
library;

import 'dart:convert';

/// What a matching message means for the ledger.
enum RuleDirection {
  /// Money left the wallet/account — record it as a payment.
  spend,

  /// Money arrived. Never spending; kept out of the totals.
  moneyIn,

  /// Moving your own money around (bank ↔ wallet). Only the fee is real.
  feeOnly,

  /// A delayed follow-up SMS that completes an existing record
  /// (Cash Power token, Canalbox renewal, …) rather than creating one.
  enrichment,

  /// Explicitly not a transaction — a way to silence noisy senders.
  ignore;

  static RuleDirection fromJson(String? raw) {
    switch (raw) {
      case 'spend':
        return RuleDirection.spend;
      case 'moneyIn':
        return RuleDirection.moneyIn;
      case 'feeOnly':
        return RuleDirection.feeOnly;
      case 'ignore':
        return RuleDirection.ignore;
      default:
        return RuleDirection.enrichment;
    }
  }

  String toJson() => name;
}

/// Where a rule came from. Built-ins can be disabled but not deleted or
/// edited; the user always keeps a way back to the shipped behaviour.
enum RuleSource {
  builtin,
  user,
  pack;

  static RuleSource fromJson(String? raw) => RuleSource.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => RuleSource.user,
      );

  String toJson() => name;
}

/// How a captured value is interpreted.
enum FieldType {
  /// "12,500" / "12500.00" → 12500.0
  amount,

  /// Numeric, rendered with 2 decimals when it is one (e.g. Cash Power units).
  decimal,

  /// Transaction / reference id.
  ref,

  /// Phone number in any local or international form.
  phone,

  /// Free text (names, descriptions).
  text;

  static FieldType fromJson(String? raw) => FieldType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => FieldType.text,
      );

  String toJson() => name;

  /// The regex fragment a placeholder of this type expands to. [toLineEnd]
  /// is used when nothing follows the placeholder in the template, where a
  /// lazy pattern would otherwise match a single character.
  String pattern({bool toLineEnd = false}) {
    switch (this) {
      case FieldType.amount:
      case FieldType.decimal:
        return r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)';
      case FieldType.ref:
        return r'([A-Za-z0-9][A-Za-z0-9\-_/]*)';
      case FieldType.phone:
        return r'(\+?\d[\d\s\-]{7,})';
      case FieldType.text:
        return toLineEnd ? r'([^\n]+)' : r'(.+?)';
    }
  }
}

/// One extractable value, pulled independently of the others.
///
/// Label-anchored fields (`Token: ABC`) survive reordering and line breaks far
/// better than one whole-message template, which is why the built-in service
/// rules use them. [pattern] wins when present; otherwise [after]/[before]
/// build an anchored pattern from surrounding literal text.
class RuleField {
  final String name;
  final FieldType type;

  /// Explicit regex with exactly one capturing group.
  final String? pattern;

  /// Literal text immediately preceding the value (e.g. `"Token:"`).
  final String? after;

  /// Literal text immediately following the value (e.g. `"was completed"`).
  final String? before;

  const RuleField({
    required this.name,
    this.type = FieldType.text,
    this.pattern,
    this.after,
    this.before,
  });

  factory RuleField.fromJson(Map<String, dynamic> json) => RuleField(
        name: json['name'] as String,
        type: FieldType.fromJson(json['type'] as String?),
        pattern: json['pattern'] as String?,
        after: json['after'] as String?,
        before: json['before'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.toJson(),
        if (pattern != null) 'pattern': pattern,
        if (after != null) 'after': after,
        if (before != null) 'before': before,
      };

  /// Compiled matcher, or null when the field carries no usable spec.
  RegExp? compile() {
    if (pattern != null && pattern!.isNotEmpty) {
      return RegExp(pattern!, caseSensitive: false, dotAll: true);
    }
    final hasAfter = after != null && after!.trim().isNotEmpty;
    final hasBefore = before != null && before!.trim().isNotEmpty;
    if (!hasAfter && !hasBefore) return null;

    final buffer = StringBuffer();
    if (hasAfter) {
      buffer.write(SmsRule.literalToPattern(after!));
      buffer.write(r'\s*');
    }
    buffer.write(
      type.pattern(toLineEnd: !hasBefore && type == FieldType.text),
    );
    if (hasBefore) {
      buffer.write(r'\s*');
      // Word boundaries matter on the closing anchor and only there: a lazy
      // text capture would otherwise stop at the first "on" *inside* a payee
      // called LONDON SHOP. The opening anchor deliberately has none, so
      // "RWF7,500" still matches an anchor ending in "RWF".
      final word = RegExp(r'\w');
      final literal = before!.trim();
      if (word.hasMatch(literal[0])) buffer.write(r'\b');
      buffer.write(SmsRule.literalToPattern(before!));
      if (word.hasMatch(literal[literal.length - 1])) buffer.write(r'\b');
    }
    return RegExp(buffer.toString(), caseSensitive: false, dotAll: true);
  }
}

/// A single detection rule.
class SmsRule {
  final String id;
  final String label;
  final bool enabled;

  /// Higher runs first. Built-ins sit at 0; a user rule that must beat a
  /// built-in is saved above it.
  final int priority;
  final RuleSource source;

  /// Lower-cased substrings; the sender must contain one of them.
  /// Empty means any sender — content alone decides.
  final List<String> senderMatch;

  /// Every entry must appear in the body (case-insensitive).
  final List<String> mustContain;

  /// At least one entry must appear, when the list is non-empty.
  final List<String> anyOf;

  /// No entry may appear.
  final List<String> mustNotContain;

  final RuleDirection direction;

  /// Whole-message template with `{field}` placeholders, e.g.
  /// `"You have received {amount} RWF from {name}"`. What the teach-from-SMS
  /// flow writes.
  final String? template;

  /// Types for template placeholders whose name isn't self-describing.
  final Map<String, FieldType> templateTypes;

  /// Independently anchored fields, merged over the template's captures.
  final List<RuleField> fields;

  /// Fields without which the match is discarded. A Cash Power SMS with no
  /// token isn't the message we're looking for, however well the rest fits.
  final List<String> requiredFields;

  /// Name of a proven imperative parser to delegate to instead of doing
  /// declarative extraction. Used by the built-ins whose logic is too subtle
  /// to express as patterns (BK's self-pull vs. real send, for one) — they
  /// still live in the rule list, so they can be disabled like any other.
  final String? builtinParser;

  /// Fee to apply when the message carries no fee of its own.
  final double? fixedFee;

  /// Ties matching records to a service (`efashe`, `bk-pull`, …).
  final String? serviceKey;

  /// Recipient to record when the message has no extractable one
  /// (e.g. "Bank of Kigali" for a pull).
  final String? recipientLabel;

  /// Rendered into `extraDetails`. Segments separated by ` · ` are dropped
  /// when a placeholder inside them didn't resolve.
  final String? detailsTemplate;

  /// Which captured field identifies the underlying event, so the same
  /// payment reported by two senders (bank *and* wallet) is recorded once.
  final String? eventKeyField;

  /// While true, matches surface as suggestions instead of silently landing
  /// in the ledger. New user rules start here.
  final bool needsConfirmation;

  const SmsRule({
    required this.id,
    required this.label,
    this.enabled = true,
    this.priority = 0,
    this.source = RuleSource.user,
    this.senderMatch = const [],
    this.mustContain = const [],
    this.anyOf = const [],
    this.mustNotContain = const [],
    this.direction = RuleDirection.spend,
    this.template,
    this.templateTypes = const {},
    this.fields = const [],
    this.requiredFields = const [],
    this.builtinParser,
    this.fixedFee,
    this.serviceKey,
    this.recipientLabel,
    this.detailsTemplate,
    this.eventKeyField,
    this.needsConfirmation = false,
  });

  SmsRule copyWith({
    String? label,
    bool? enabled,
    int? priority,
    List<String>? senderMatch,
    List<String>? mustContain,
    List<String>? anyOf,
    List<String>? mustNotContain,
    RuleDirection? direction,
    String? template,
    Map<String, FieldType>? templateTypes,
    List<RuleField>? fields,
    List<String>? requiredFields,
    double? fixedFee,
    String? serviceKey,
    String? recipientLabel,
    String? detailsTemplate,
    String? eventKeyField,
    bool? needsConfirmation,
  }) {
    return SmsRule(
      id: id,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      source: source,
      senderMatch: senderMatch ?? this.senderMatch,
      mustContain: mustContain ?? this.mustContain,
      anyOf: anyOf ?? this.anyOf,
      mustNotContain: mustNotContain ?? this.mustNotContain,
      direction: direction ?? this.direction,
      template: template ?? this.template,
      templateTypes: templateTypes ?? this.templateTypes,
      fields: fields ?? this.fields,
      requiredFields: requiredFields ?? this.requiredFields,
      builtinParser: builtinParser,
      fixedFee: fixedFee ?? this.fixedFee,
      serviceKey: serviceKey ?? this.serviceKey,
      recipientLabel: recipientLabel ?? this.recipientLabel,
      detailsTemplate: detailsTemplate ?? this.detailsTemplate,
      eventKeyField: eventKeyField ?? this.eventKeyField,
      needsConfirmation: needsConfirmation ?? this.needsConfirmation,
    );
  }

  factory SmsRule.fromJson(Map<String, dynamic> json) {
    return SmsRule(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['id'] as String,
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      source: RuleSource.fromJson(json['source'] as String?),
      senderMatch: _stringList(json['senderMatch']),
      mustContain: _stringList(json['mustContain']),
      anyOf: _stringList(json['anyOf']),
      mustNotContain: _stringList(json['mustNotContain']),
      direction: RuleDirection.fromJson(json['direction'] as String?),
      template: json['template'] as String?,
      templateTypes: {
        for (final entry
            in ((json['templateTypes'] as Map?) ?? const {}).entries)
          entry.key as String: FieldType.fromJson(entry.value as String?),
      },
      fields: [
        for (final f in (json['fields'] as List?) ?? const [])
          RuleField.fromJson(Map<String, dynamic>.from(f as Map)),
      ],
      requiredFields: [
        for (final v in (json['requiredFields'] as List?) ?? const [])
          v as String,
      ],
      builtinParser: json['builtinParser'] as String?,
      fixedFee: (json['fixedFee'] as num?)?.toDouble(),
      serviceKey: json['serviceKey'] as String?,
      recipientLabel: json['recipientLabel'] as String?,
      detailsTemplate: json['detailsTemplate'] as String?,
      eventKeyField: json['eventKeyField'] as String?,
      needsConfirmation: json['needsConfirmation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'enabled': enabled,
        'priority': priority,
        'source': source.toJson(),
        if (senderMatch.isNotEmpty) 'senderMatch': senderMatch,
        if (mustContain.isNotEmpty) 'mustContain': mustContain,
        if (anyOf.isNotEmpty) 'anyOf': anyOf,
        if (mustNotContain.isNotEmpty) 'mustNotContain': mustNotContain,
        'direction': direction.toJson(),
        if (template != null) 'template': template,
        if (templateTypes.isNotEmpty)
          'templateTypes': templateTypes.map((k, v) => MapEntry(k, v.toJson())),
        if (fields.isNotEmpty) 'fields': fields.map((f) => f.toJson()).toList(),
        if (requiredFields.isNotEmpty) 'requiredFields': requiredFields,
        if (builtinParser != null) 'builtinParser': builtinParser,
        if (fixedFee != null) 'fixedFee': fixedFee,
        if (serviceKey != null) 'serviceKey': serviceKey,
        if (recipientLabel != null) 'recipientLabel': recipientLabel,
        if (detailsTemplate != null) 'detailsTemplate': detailsTemplate,
        if (eventKeyField != null) 'eventKeyField': eventKeyField,
        if (needsConfirmation) 'needsConfirmation': needsConfirmation,
      };

  String encode() => jsonEncode(toJson());

  static List<String> _stringList(dynamic raw) => [
        for (final v in (raw as List?) ?? const [])
          (v as String).toLowerCase(),
      ];

  /// Whether the cheap gates pass. [lowerBody] is expected pre-lowercased.
  bool gatesPass(String sender, String lowerBody) {
    // An unknown sender doesn't fail the gate: some scans have no sender to
    // check, and content signatures are what actually identify the message —
    // the sender is defence in depth against an unrelated SMS matching by
    // coincidence, not the primary test.
    final s = sender.toLowerCase().trim();
    if (senderMatch.isNotEmpty && s.isNotEmpty) {
      if (!senderMatch.any(s.contains)) return false;
    }
    for (final needle in mustContain) {
      if (!lowerBody.contains(needle)) return false;
    }
    if (anyOf.isNotEmpty && !anyOf.any(lowerBody.contains)) return false;
    for (final needle in mustNotContain) {
      if (lowerBody.contains(needle)) return false;
    }
    return true;
  }

  /// Placeholder tokens in a template: `{amount}`, `{ref}`, …
  static final RegExp placeholderPattern = RegExp(r'\{(\w+)\}');

  /// Turns literal SMS text into a forgiving regex fragment: every character
  /// escaped, runs of whitespace relaxed to `\s+`, and whitespace at the
  /// edges made optional so `"5000RWF"` and `"5000 RWF"` both match.
  static String literalToPattern(String literal) {
    if (literal.isEmpty) return '';
    if (literal.trim().isEmpty) return r'\s*';
    final whitespace = RegExp(r'\s');
    final leading = whitespace.hasMatch(literal[0]) ? r'\s*' : '';
    final trailing =
        whitespace.hasMatch(literal[literal.length - 1]) ? r'\s*' : '';
    final words =
        literal.trim().split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
    return '$leading$words$trailing';
  }

  /// Field type for a template placeholder: the rule's explicit override
  /// first, then the name itself (`amount`, `fee`, `ref`, `phone` are
  /// self-describing), then free text.
  FieldType typeForPlaceholder(String name) {
    final explicit = templateTypes[name];
    if (explicit != null) return explicit;
    switch (name.toLowerCase()) {
      case 'amount':
      case 'total':
      case 'balance':
        return FieldType.amount;
      case 'fee':
      case 'charge':
      case 'units':
        return FieldType.decimal;
      case 'ref':
      case 'refid':
      case 'code':
      case 'token':
      case 'txid':
        return FieldType.ref;
      case 'phone':
      case 'number':
      case 'msisdn':
        return FieldType.phone;
      default:
        return FieldType.text;
    }
  }

  /// Compiles [template] into a regex plus the capture-group order.
  /// Returns null when the rule has no usable template.
  ({RegExp regex, List<String> groups})? compileTemplate() {
    final tpl = template;
    if (tpl == null || tpl.trim().isEmpty) return null;

    final groups = <String>[];
    final buffer = StringBuffer();
    var cursor = 0;

    for (final match in placeholderPattern.allMatches(tpl)) {
      buffer.write(literalToPattern(tpl.substring(cursor, match.start)));
      final name = match.group(1)!;
      final isLast =
          match.end >= tpl.length || tpl.substring(match.end).trim().isEmpty;
      groups.add(name);
      buffer.write(typeForPlaceholder(name).pattern(toLineEnd: isLast));
      cursor = match.end;
    }
    if (groups.isEmpty) return null;
    buffer.write(literalToPattern(tpl.substring(cursor)));

    return (
      regex: RegExp(buffer.toString(), caseSensitive: false, dotAll: true),
      groups: groups,
    );
  }
}
