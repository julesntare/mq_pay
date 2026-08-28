import '../models/sms_rule.dart';

/// One tappable word in a message, with where it sits in the raw body.
///
/// [start]/[end] cover the token *without* its surrounding punctuation, so
/// tapping "7,500." selects `7,500` and the trailing full stop stays behind as
/// literal anchor text.
class SmsToken {
  final String raw;
  final String text;
  final int start;
  final int end;

  const SmsToken({
    required this.raw,
    required this.text,
    required this.start,
    required this.end,
  });

  bool get isEmpty => text.isEmpty;
}

/// A span of the message the user has assigned a meaning to.
class FieldSelection {
  /// One of [SmsRuleBuilder.roles].
  final String role;
  final int start;
  final int end;

  const FieldSelection({
    required this.role,
    required this.start,
    required this.end,
  });

  bool overlaps(int from, int to) => from < end && to > start;
}

/// Turns "the user tapped these words" into a rule.
///
/// This is the whole point of the rules feature: nobody writes a regex. The
/// user points at the amount, the payee and the reference in a message they
/// actually received, and the anchors are read off the literal text sitting
/// around each one.
class SmsRuleBuilder {
  /// Roles a tapped word can be given, in the order the picker shows them.
  static const List<String> roles = ['amount', 'recipient', 'ref', 'fee'];

  static const Map<String, String> roleLabels = {
    'amount': 'Amount',
    'recipient': 'Paid to',
    'ref': 'Reference',
    'fee': 'Fee',
  };

  /// How many words of surrounding text an anchor keeps. Enough to be
  /// distinctive, few enough that a reworded sentence elsewhere in the
  /// message doesn't break the match.
  static const int anchorWords = 3;

  /// A closing anchor only has to stop a lazy capture, so it stays short —
  /// every extra word is another thing the next message might reword.
  static const int closingAnchorWords = 2;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _leadingJunk = RegExp(r'^[^\w]+');
  static final RegExp _trailingJunk = RegExp(r'[^\w]+$');

  /// Splits [body] into tappable words. Punctuation is kept in [SmsToken.raw]
  /// for display but excluded from the selectable span.
  static List<SmsToken> tokenize(String body) {
    final tokens = <SmsToken>[];
    var index = 0;
    while (index < body.length) {
      // Skip whitespace.
      if (_whitespace.matchAsPrefix(body, index) != null) {
        index = _whitespace.matchAsPrefix(body, index)!.end;
        continue;
      }
      var end = index;
      while (end < body.length &&
          _whitespace.matchAsPrefix(body, end) == null) {
        end++;
      }
      final raw = body.substring(index, end);
      var start = index;
      var coreEnd = end;
      final lead = _leadingJunk.firstMatch(raw);
      if (lead != null) start += lead.end;
      final trail = _trailingJunk.firstMatch(raw);
      if (trail != null) coreEnd -= (raw.length - trail.start);
      if (coreEnd < start) coreEnd = start;
      tokens.add(SmsToken(
        raw: raw,
        text: body.substring(start, coreEnd),
        start: start,
        end: coreEnd,
      ));
      index = end;
    }
    return tokens;
  }

  /// Merges selections of the same role that sit side by side, so tapping
  /// "SIMBA" then "SUPERMARKET" yields one payee, not two.
  static List<FieldSelection> mergeAdjacent(
    List<FieldSelection> selections,
    String body,
  ) {
    if (selections.isEmpty) return const [];
    final sorted = [...selections]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <FieldSelection>[sorted.first];
    for (final selection in sorted.skip(1)) {
      final previous = merged.last;
      final between = body.substring(previous.end, selection.start);
      if (previous.role == selection.role && between.trim().isEmpty) {
        merged[merged.length - 1] = FieldSelection(
          role: previous.role,
          start: previous.start,
          end: selection.end,
        );
      } else {
        merged.add(selection);
      }
    }
    return merged;
  }

  /// Builds a rule from tapped spans.
  ///
  /// Every rule made this way starts with [SmsRule.needsConfirmation] set:
  /// its first matches arrive as suggestions to approve, never straight into
  /// the ledger. A rule taught from one message has, by definition, been
  /// tested against exactly one message.
  static SmsRule build({
    required String body,
    required String sender,
    required List<FieldSelection> selections,
    required RuleDirection direction,
    required String label,
    String? id,
    bool needsConfirmation = true,
  }) {
    final spans = mergeAdjacent(selections, body);
    final fields = <RuleField>[];

    for (final span in spans) {
      final type = _typeFor(span.role);
      final after = _anchorBefore(body, span, spans);
      // A number or a reference is self-delimiting, so an opening anchor is
      // enough and a closing one only adds something else that can change.
      // Free text is not: without a word to stop at, "SIMBA SUPERMARKET"
      // would swallow the rest of the line.
      final needsClosing = type == FieldType.text || after.isEmpty;
      final before = needsClosing ? _anchorAfter(body, span, spans) : '';
      fields.add(RuleField(
        name: span.role,
        type: type,
        after: after.isEmpty ? null : after,
        before: before.isEmpty ? null : before,
      ));
    }

    final hasRef = spans.any((s) => s.role == 'ref');

    return SmsRule(
      id: id ?? 'user.${DateTime.now().millisecondsSinceEpoch}',
      label: label.trim().isEmpty ? 'Untitled rule' : label.trim(),
      source: RuleSource.user,
      // Above the built-ins, so a rule the user wrote for their own bank
      // beats a shipped rule that happens to match the same message.
      priority: 200,
      direction: direction,
      senderMatch: sender.trim().isEmpty ? const [] : [sender.trim().toLowerCase()],
      mustContain: _gatePhrases(body, spans),
      fields: fields,
      requiredFields: _requiredFor(direction, spans),
      eventKeyField: hasRef ? 'ref' : null,
      needsConfirmation: needsConfirmation,
    );
  }

  static FieldType _typeFor(String role) {
    switch (role) {
      case 'amount':
      case 'fee':
        return FieldType.amount;
      case 'ref':
        return FieldType.ref;
      default:
        return FieldType.text;
    }
  }

  static List<String> _requiredFor(
    RuleDirection direction,
    List<FieldSelection> spans,
  ) {
    // The engine already refuses a spend rule that found no amount; naming it
    // here too makes the rule say so out loud when the user reads it back.
    if (direction == RuleDirection.spend &&
        spans.any((s) => s.role == 'amount')) {
      return const ['amount'];
    }
    return const [];
  }

  /// Up to [anchorWords] words of literal text immediately before [span],
  /// stopping at a line break or at another selected span — an anchor must be
  /// text that stays the same from message to message.
  static String _anchorBefore(
    String body,
    FieldSelection span,
    List<FieldSelection> spans,
  ) {
    var floor = 0;
    for (final other in spans) {
      if (identical(other, span)) continue;
      if (other.end <= span.start && other.end > floor) floor = other.end;
    }
    var text = body.substring(floor, span.start);
    final lineBreak = text.lastIndexOf('\n');
    if (lineBreak != -1) text = text.substring(lineBreak + 1);
    return _lastWords(text, anchorWords);
  }

  /// The mirror image, for a value that opens the message and so has nothing
  /// in front of it to anchor on.
  static String _anchorAfter(
    String body,
    FieldSelection span,
    List<FieldSelection> spans,
  ) {
    var ceiling = body.length;
    for (final other in spans) {
      if (identical(other, span)) continue;
      if (other.start >= span.end && other.start < ceiling) {
        ceiling = other.start;
      }
    }
    var text = body.substring(span.end, ceiling);
    final lineBreak = text.indexOf('\n');
    if (lineBreak != -1) text = text.substring(0, lineBreak);
    return _firstWords(text, closingAnchorWords);
  }

  static String _lastWords(String text, int count) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(_whitespace);
    final kept =
        words.length <= count ? words : words.sublist(words.length - count);
    return _dropVaryingWords(kept, keepTrailing: true).join(' ');
  }

  static String _firstWords(String text, int count) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(_whitespace);
    final kept = words.length <= count ? words : words.sublist(0, count);
    return _dropVaryingWords(kept, keepTrailing: false).join(' ');
  }

  /// Trims an anchor back to its run of digit-free words, counting inward
  /// from the value being anchored.
  ///
  /// Anchors are literal text, so a date or a running balance inside one makes
  /// the rule match exactly one message — the message it was taught from. The
  /// nearest word is kept regardless: a weak anchor still beats none.
  static List<String> _dropVaryingWords(
    List<String> words, {
    required bool keepTrailing,
  }) {
    if (words.isEmpty) return words;
    final digit = RegExp(r'\d');
    final scan = keepTrailing ? words.reversed.toList() : words;
    final kept = <String>[];
    for (final word in scan) {
      if (digit.hasMatch(word)) break;
      kept.add(word);
    }
    if (kept.isEmpty) return [scan.first];
    return keepTrailing ? kept.reversed.toList() : kept;
  }

  /// A cheap keyword gate so the rule doesn't even try to extract from
  /// unrelated messages. Uses the wording around the amount, which is the
  /// most characteristic part of a receipt ("has been debited RWF").
  ///
  /// Gate lists are compared against a lower-cased body, so they are stored
  /// lower-cased here.
  static List<String> _gatePhrases(String body, List<FieldSelection> spans) {
    final amount = spans.where((s) => s.role == 'amount').toList();
    if (amount.isNotEmpty) {
      final anchor = _anchorBefore(body, amount.first, spans);
      final words = anchor.trim().isEmpty ? <String>[] : anchor.trim().split(_whitespace);
      final alphabetic = words.where((w) => RegExp(r'[A-Za-z]').hasMatch(w)).toList();
      if (alphabetic.length >= 2) return [alphabetic.join(' ').toLowerCase()];
    }
    final opening = _firstWords(body, 4).toLowerCase();
    return opening.isEmpty ? const [] : [opening];
  }

  /// Human-readable summary of what a rule will pull out, for the rules list.
  static String describe(SmsRule rule) {
    if (rule.builtinParser != null) return 'Built-in format';
    final parts = <String>[];
    for (final field in rule.fields) {
      final label = roleLabels[field.name] ?? field.name;
      parts.add(label);
    }
    if (rule.template != null && parts.isEmpty) parts.add('Template');
    return parts.isEmpty ? 'Keyword match' : 'Reads ${parts.join(', ')}';
  }
}
