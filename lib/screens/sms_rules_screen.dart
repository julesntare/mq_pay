import 'package:flutter/material.dart';

import '../models/sms_rule.dart';
import '../models/transaction_suggestion.dart';
import '../services/rule_pack_sync_service.dart';
import '../services/rule_sharing_service.dart';
import '../services/sms_rule_builder.dart';
import '../services/sms_rule_preview_service.dart';
import '../services/sms_rule_service.dart';
import '../services/suggestion_service.dart';
import '../services/unrecognized_sms_service.dart';
import 'teach_rule_screen.dart';

/// Where the user sees and changes what the app detects.
///
/// Three things live here, in the order they matter: transactions waiting for
/// approval, a way to teach a message the app missed, and the rule list
/// itself.
class SmsRulesScreen extends StatefulWidget {
  const SmsRulesScreen({super.key});

  @override
  State<SmsRulesScreen> createState() => _SmsRulesScreenState();
}

class _SmsRulesScreenState extends State<SmsRulesScreen> {
  List<SmsRule> _rules = const [];
  List<TransactionSuggestion> _suggestions = const [];
  RulePackInfo? _pack;
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SmsRuleService.load();
    final suggestions = await SuggestionService.all();
    final pack = await RulePackSyncService.currentPack();
    if (!mounted) return;
    setState(() {
      _rules = SmsRuleService.allRules();
      _suggestions = suggestions;
      _pack = pack;
      _loading = false;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Suggestions -------------------------------------------------------

  Future<void> _acceptSuggestion(TransactionSuggestion suggestion) async {
    final record = await SuggestionService.accept(suggestion.id);
    await _load();
    _toast(record == null ? 'That suggestion is gone.' : 'Recorded.');
  }

  Future<void> _dismissSuggestion(TransactionSuggestion suggestion) async {
    await SuggestionService.dismiss(suggestion.id);
    await _load();
    _toast('Discarded.');
  }

  /// Stops a rule asking for approval on every match. Offered right where the
  /// user has just approved one, because that is the moment they know whether
  /// the rule is right.
  Future<void> _trustRule(String ruleId) async {
    final rule =
        SmsRuleService.userRules().where((r) => r.id == ruleId).toList();
    if (rule.isEmpty) {
      _toast('Only rules you made can be trusted this way.');
      return;
    }
    await SmsRuleService.saveUserRule(
      rule.first.copyWith(needsConfirmation: false),
    );
    await _load();
    _toast('"${rule.first.label}" will now record without asking.');
  }

  // --- Teaching ----------------------------------------------------------

  Future<void> _findUnrecognized() async {
    setState(() => _scanning = true);
    try {
      final found = await UnrecognizedSmsService.find();
      if (!mounted) return;
      if (found.isEmpty) {
        _toast('Nothing unrecognised in the last 30 days.');
        return;
      }
      await _showUnrecognizedPicker(found);
    } catch (e) {
      _toast('Could not scan: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showUnrecognizedPicker(List<UnrecognizedSms> found) async {
    final chosen = await showModalBottomSheet<UnrecognizedSms>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UnrecognizedPickerSheet(messages: found),
    );

    if (chosen == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TeachRuleScreen(
          smsBody: chosen.body,
          sender: chosen.sender,
          similarCount: chosen.similarCount,
        ),
      ),
    );
    if (saved == true) {
      await _load();
      _toast('Rule saved. Its matches will wait for your approval.');
    }
  }

  // --- Rule list actions -------------------------------------------------

  Future<void> _toggleRule(SmsRule rule, bool enabled) async {
    await SmsRuleService.setEnabled(rule.id, enabled);
    await _load();
  }

  Future<void> _deleteRule(SmsRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${rule.label}"?'),
        content: const Text(
            'Messages it used to detect will stop being recorded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await SmsRuleService.deleteUserRule(rule.id);
    await _load();
  }

  Future<void> _openRule(SmsRule rule) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RuleDetailSheet(
        rule: rule,
        onTrust: rule.source == RuleSource.user && rule.needsConfirmation
            ? () async {
                Navigator.pop(ctx);
                await _trustRule(rule.id);
              }
            : null,
      ),
    );
  }

  // --- Sharing and packs -------------------------------------------------

  Future<void> _exportRules() async {
    if (SmsRuleService.userRules().isEmpty) {
      _toast('You haven\'t taught any rules yet.');
      return;
    }
    try {
      final path = await RuleSharingService.exportToFile();
      _toast(path == null ? 'Export cancelled.' : 'Saved to $path');
    } catch (e) {
      _toast('Export failed: $e');
    }
  }

  Future<void> _importRules() async {
    try {
      final count = await RuleSharingService.importFromFile();
      if (count == null) return;
      await _load();
      _toast('Imported $count rule${count == 1 ? '' : 's'}.');
    } catch (e) {
      _toast('Import failed: $e');
    }
  }

  Future<void> _updatePack() async {
    try {
      final info = await RulePackSyncService.fetchLatest();
      await _load();
      _toast('Updated to pack v${info.version} (${info.ruleCount} rules).');
    } catch (e) {
      _toast('Update failed: $e');
    }
  }

  Future<void> _resetPack() async {
    await RulePackSyncService.resetToBuiltIn();
    await _load();
    _toast('Back to the rules built into this app.');
  }

  // --- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS detection'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importRules();
                case 'export':
                  _exportRules();
                case 'update':
                  _updatePack();
                case 'reset':
                  _resetPack();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'import', child: Text('Import rules…')),
              const PopupMenuItem(
                  value: 'export', child: Text('Export my rules…')),
              if (RulePackSyncService.isAvailable)
                const PopupMenuItem(
                    value: 'update', child: Text('Check for pack update')),
              if (_pack != null)
                const PopupMenuItem(
                    value: 'reset', child: Text('Use built-in pack')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_suggestions.isNotEmpty) ...[
                    _sectionTitle(theme, 'Waiting for you'),
                    for (final suggestion in _suggestions)
                      _suggestionCard(theme, suggestion),
                    const SizedBox(height: 20),
                  ],
                  _teachCard(theme),
                  const SizedBox(height: 20),
                  _sectionTitle(theme, 'Rules'),
                  ..._rules.map((rule) => _ruleTile(theme, rule)),
                  if (_pack != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Rule pack v${_pack!.version}, downloaded '
                      '${_pack!.fetchedAt.toLocal().toString().split('.').first}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      );

  Widget _suggestionCard(ThemeData theme, TransactionSuggestion suggestion) {
    final amount = suggestion.amount;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (amount != null) '${amount.toStringAsFixed(0)} RWF',
                if (suggestion.recipient != null) '→ ${suggestion.recipient}',
              ].join(' '),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Found by "${suggestion.ruleLabel}" · ${suggestion.sender}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 6),
            Text(
              suggestion.smsBody,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => _dismissSuggestion(suggestion),
                    child: const Text('Discard')),
                FilledButton(
                    onPressed: () => _acceptSuggestion(suggestion),
                    child: const Text('Record it')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teachCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: _scanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.school_rounded,
                  color: theme.colorScheme.primary, size: 20),
        ),
        title: const Text('Teach a new message'),
        subtitle: const Text('Find payments the app isn\'t reading yet'),
        trailing: Icon(Icons.chevron_right_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        onTap: _scanning ? null : _findUnrecognized,
      ),
    );
  }

  Widget _ruleTile(ThemeData theme, SmsRule rule) {
    final isUser = rule.source == RuleSource.user;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(rule.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (rule.needsConfirmation) ...[
              const SizedBox(width: 6),
              Icon(Icons.help_outline_rounded,
                  size: 15, color: theme.colorScheme.primary),
            ],
          ],
        ),
        subtitle: Text(
          '${isUser ? 'Yours' : 'Built in'} · ${SmsRuleBuilder.describe(rule)}',
          style: theme.textTheme.bodySmall,
        ),
        onTap: () => _openRule(rule),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () => _deleteRule(rule),
              ),
            Switch(
              value: rule.enabled,
              onChanged: (value) => _toggleRule(rule, value),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks which unread-by-the-app message to teach from.
///
/// The list can run to dozens of rows on a busy phone, and the user usually
/// arrives knowing exactly which payment went missing — so searching by sender
/// or by any word in the message beats scrolling for it.
class _UnrecognizedPickerSheet extends StatefulWidget {
  final List<UnrecognizedSms> messages;

  const _UnrecognizedPickerSheet({required this.messages});

  @override
  State<_UnrecognizedPickerSheet> createState() =>
      _UnrecognizedPickerSheetState();
}

class _UnrecognizedPickerSheetState extends State<_UnrecognizedPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = UnrecognizedSmsService.search(widget.messages, _query);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, controller) => Padding(
        // Keeps the search field above the keyboard once it opens.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages the app can\'t read',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Pick one to teach. Messages worded the same way are '
                    'grouped together.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search sender or message',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${matches.length} of ${widget.messages.length} messages',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: matches.isEmpty
                  ? ListView(
                      controller: controller,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                          child: Text(
                            'No unrecognised message matches "${_query.trim()}".',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: controller,
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final sms = matches[i];
                        return ListTile(
                          title: Text(
                            sms.sender.isEmpty ? 'Unknown sender' : sms.sender,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            sms.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: sms.similarCount > 1
                              ? Chip(
                                  label: Text('×${sms.similarCount}'),
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, sms),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a rule does, in words, plus a live check against the inbox.
class _RuleDetailSheet extends StatefulWidget {
  final SmsRule rule;
  final Future<void> Function()? onTrust;

  const _RuleDetailSheet({required this.rule, this.onTrust});

  @override
  State<_RuleDetailSheet> createState() => _RuleDetailSheetState();
}

class _RuleDetailSheetState extends State<_RuleDetailSheet> {
  RulePreview? _preview;
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final preview = await SmsRulePreviewService.preview(widget.rule);
      if (mounted) setState(() => _preview = preview);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rule = widget.rule;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rule.label,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _line(theme, 'Means', _directionText(rule.direction)),
            if (rule.senderMatch.isNotEmpty)
              _line(theme, 'From', rule.senderMatch.join(', ')),
            if (rule.mustContain.isNotEmpty)
              _line(theme, 'Contains', rule.mustContain.join(' + ')),
            _line(theme, 'Reads', SmsRuleBuilder.describe(rule)),
            if (rule.needsConfirmation)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'In review — its matches wait for your approval.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            const SizedBox(height: 16),
            if (_preview != null)
              Text(
                'Matches ${_preview!.matches.length} of your last '
                '${_preview!.scanned} messages.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              )
            else
              Text('Check how often this fires before trusting it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _run,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.playlist_add_check_rounded,
                            size: 18),
                    label: const Text('Test on my inbox'),
                  ),
                ),
                if (widget.onTrust != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => widget.onTrust!(),
                      child: const Text('Trust it'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5))),
              TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  String _directionText(RuleDirection direction) {
    switch (direction) {
      case RuleDirection.spend:
        return 'Money out — recorded as a payment';
      case RuleDirection.moneyIn:
        return 'Money in — kept out of totals';
      case RuleDirection.feeOnly:
        return 'Own money moved — fee only';
      case RuleDirection.enrichment:
        return 'Extra detail for an existing record';
      case RuleDirection.ignore:
        return 'Never a transaction';
    }
  }
}
