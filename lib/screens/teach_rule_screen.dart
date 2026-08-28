import 'package:flutter/material.dart';

import '../models/sms_rule.dart';
import '../services/sms_rule_builder.dart';
import '../services/sms_rule_preview_service.dart';
import '../services/sms_rule_service.dart';

/// Teach the app to read a message it doesn't understand.
///
/// The user taps the words that carry meaning — the amount, who was paid, the
/// reference — and the rule is derived from the literal text around them. No
/// regex is ever shown, because nobody outside this file should have to think
/// in patterns to track their own spending.
class TeachRuleScreen extends StatefulWidget {
  final String smsBody;
  final String sender;

  /// How many inbox messages share this one's wording. Shown so the user knows
  /// a rule taught here covers all of them.
  final int similarCount;

  const TeachRuleScreen({
    super.key,
    required this.smsBody,
    required this.sender,
    this.similarCount = 1,
  });

  @override
  State<TeachRuleScreen> createState() => _TeachRuleScreenState();
}

class _TeachRuleScreenState extends State<TeachRuleScreen> {
  static const Map<String, Color> _roleColors = {
    'amount': Color(0xFF2E7D32),
    'recipient': Color(0xFF1565C0),
    'ref': Color(0xFF6A1B9A),
    'fee': Color(0xFFEF6C00),
  };

  late final List<SmsToken> _tokens;
  final Map<int, String> _rolesByToken = {};
  final TextEditingController _nameController = TextEditingController();

  RuleDirection _direction = RuleDirection.spend;
  RulePreview? _preview;
  bool _previewing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tokens = SmsRuleBuilder.tokenize(widget.smsBody);
    _nameController.text = _defaultName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultName() {
    final sender = widget.sender.trim();
    return sender.isEmpty ? 'My rule' : sender;
  }

  bool get _hasAmount => _rolesByToken.values.contains('amount');

  /// A rule is only meaningful once the money itself has been pointed at —
  /// except for an ignore rule, whose whole purpose is to match and do
  /// nothing.
  bool get _canSave =>
      _direction == RuleDirection.ignore || _hasAmount;

  SmsRule _candidateRule() {
    final selections = <FieldSelection>[];
    _rolesByToken.forEach((index, role) {
      final token = _tokens[index];
      selections.add(
        FieldSelection(role: role, start: token.start, end: token.end),
      );
    });

    return SmsRuleBuilder.build(
      body: widget.smsBody,
      sender: widget.sender,
      selections: selections,
      direction: _direction,
      label: _nameController.text,
    );
  }

  Future<void> _pickRole(int index) async {
    final current = _rolesByToken[index];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'What is "${_tokens[index].text}"?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              for (final role in SmsRuleBuilder.roles)
                ListTile(
                  leading: Icon(Icons.circle, size: 14, color: _roleColors[role]),
                  title: Text(SmsRuleBuilder.roleLabels[role]!),
                  trailing: current == role
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                  onTap: () => Navigator.pop(ctx, role),
                ),
              if (current != null)
                ListTile(
                  leading: const Icon(Icons.backspace_outlined, size: 18),
                  title: const Text('Not important'),
                  onTap: () => Navigator.pop(ctx, '__clear__'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      if (picked == '__clear__') {
        _rolesByToken.remove(index);
      } else {
        _rolesByToken[index] = picked;
      }
      // Any change invalidates a preview taken against the old shape.
      _preview = null;
    });
  }

  Future<void> _runPreview() async {
    setState(() => _previewing = true);
    try {
      final preview = await SmsRulePreviewService.preview(_candidateRule());
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not test: $e')));
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SmsRuleService.saveUserRule(_candidateRule());
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Teach this message')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _instructions(theme),
          const SizedBox(height: 16),
          _messageCard(theme),
          const SizedBox(height: 16),
          _assignedSummary(theme),
          const SizedBox(height: 16),
          _directionCard(theme),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Rule name',
              hintText: 'e.g. Equity card purchase',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _previewCard(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _previewing || !_canSave ? null : _runPreview,
                  icon: _previewing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: const Text('Test it'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving || !_canSave ? null : _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save rule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructions(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the words that matter',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Point at the amount, and at whoever was paid. Everything around '
          'them is used to recognise the next message like this one.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (widget.similarCount > 1) ...[
          const SizedBox(height: 6),
          Text(
            'You have ${widget.similarCount} messages worded like this one.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _messageCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.sender.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'From ${widget.sender}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5)),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _tokens.length; i++)
                  _tokenChip(theme, i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tokenChip(ThemeData theme, int index) {
    final token = _tokens[index];
    final role = _rolesByToken[index];
    final color = role == null ? null : _roleColors[role];

    if (token.isEmpty) {
      // Pure punctuation: shown so the message reads correctly, but there is
      // nothing to extract from it.
      return Text(token.raw, style: theme.textTheme.bodyMedium);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _pickRole(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: color == null ? 1 : 1.5,
          ),
        ),
        child: Text(
          token.raw,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: color == null ? null : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _assignedSummary(ThemeData theme) {
    final assigned = <String, List<String>>{};
    _rolesByToken.forEach((index, role) {
      assigned.putIfAbsent(role, () => []).add(_tokens[index].text);
    });

    if (assigned.isEmpty) {
      return Text(
        'Nothing tapped yet.',
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in SmsRuleBuilder.roles)
          if (assigned.containsKey(role))
            Chip(
              avatar: Icon(Icons.circle, size: 12, color: _roleColors[role]),
              label: Text(
                '${SmsRuleBuilder.roleLabels[role]}: ${assigned[role]!.join(' ')}',
              ),
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }

  Widget _directionCard(ThemeData theme) {
    const options = {
      RuleDirection.spend: 'Money out',
      RuleDirection.moneyIn: 'Money in',
      RuleDirection.feeOnly: 'Fee only',
      RuleDirection.ignore: 'Ignore these',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What does this message mean?',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _direction == entry.key,
                onSelected: (_) => setState(() {
                  _direction = entry.key;
                  _preview = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _directionHelp,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  String get _directionHelp {
    switch (_direction) {
      case RuleDirection.spend:
        return 'Recorded as a payment, counted in your totals.';
      case RuleDirection.moneyIn:
        return 'Money arriving. Kept out of your spending totals.';
      case RuleDirection.feeOnly:
        return 'Moving your own money — only the fee is recorded.';
      case RuleDirection.ignore:
        return 'Never treated as a transaction.';
      case RuleDirection.enrichment:
        return '';
    }
  }

  Widget _previewCard(ThemeData theme) {
    final preview = _preview;
    if (preview == null) {
      return Text(
        _canSave
            ? 'Tip: test the rule against your inbox before saving. A rule '
                'that matches far more than you expect is one to narrow down.'
            : 'Tap the amount to continue.',
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      );
    }

    if (preview.permissionDenied) {
      return Text(
        'SMS permission is off, so the rule can\'t be tested here.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.error),
      );
    }

    final matches = preview.matches;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matches ${matches.length} of your last ${preview.scanned} messages',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (matches.isEmpty)
              Text(
                'Nothing matched — including the message you taught it from. '
                'Try tapping fewer words, or a word that is always there.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else
              for (final match in matches.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (match.amount != null)
                            '${match.amount!.toStringAsFixed(0)} RWF',
                          if (match.recipient != null) '→ ${match.recipient}',
                          if (match.reference != null) '(${match.reference})',
                        ].join(' '),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        match.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
            if (matches.length > 6)
              Text('…and ${matches.length - 6} more',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'New rules stay in review: matches wait for your approval '
              'before they are recorded.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
