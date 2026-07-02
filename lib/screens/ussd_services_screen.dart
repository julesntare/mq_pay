import 'package:flutter/material.dart';
import '../models/ussd_service_shortcut.dart';
import '../services/ussd_services_catalog_service.dart';
import '../helpers/ussd_service_actions.dart';

/// Full catalog of "other" USSD services (Cash Power, Canalbox, Umutekano,
/// Yego Cab, custom). Reached via the "See all" link on the home screen's
/// favorites-only quick-access row. Every management action (favorite,
/// edit, reset, delete) is a visible icon here — nothing hidden behind
/// long-press.
class UssdServicesScreen extends StatefulWidget {
  const UssdServicesScreen({super.key});

  @override
  State<UssdServicesScreen> createState() => _UssdServicesScreenState();
}

class _UssdServicesScreenState extends State<UssdServicesScreen> {
  List<UssdServiceShortcut> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = await UssdServicesCatalogService.getServices();
    if (mounted) setState(() {
      _services = services;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(UssdServiceShortcut service) async {
    await UssdServicesCatalogService.updateService(
        service.copyWith(isFavorite: !service.isFavorite));
    await _load();
  }

  Future<void> _editCode(UssdServiceShortcut service) async {
    final codeCtrl = TextEditingController(text: service.ussdCode ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit "${service.label}" code'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'USSD code',
              hintText: 'e.g. *123#  — leave blank for no-dial'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    final newCode = codeCtrl.text.trim();
    await UssdServicesCatalogService.updateService(service.copyWith(
      ussdCode: newCode.isEmpty ? null : newCode,
      clearUssdCode: newCode.isEmpty,
    ));
    await _load();
  }

  Future<void> _resetCode(UssdServiceShortcut service) async {
    await UssdServicesCatalogService.updateService(service.copyWith(
      ussdCode: service.defaultUssdCode,
      clearUssdCode: service.defaultUssdCode == null,
    ));
    await _load();
  }

  Future<void> _deleteService(UssdServiceShortcut service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${service.label}"?'),
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
    if (confirmed == true) {
      await UssdServicesCatalogService.deleteService(service.id);
      await _load();
    }
  }

  Future<void> _addService() async {
    final labelCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Label', hintText: 'e.g. WASAC'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                  labelText: 'USSD code (optional)',
                  hintText: 'e.g. *123#  — leave blank for no-dial services'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;
    final label = labelCtrl.text.trim();
    if (label.isEmpty) return;
    final code = codeCtrl.text.trim();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await UssdServicesCatalogService.addService(UssdServiceShortcut(
      id: id,
      label: label,
      serviceKey: 'custom:$id',
      ussdCode: code.isEmpty ? null : code,
    ));
    await _load();
  }

  Future<void> _restoreDefaults() async {
    await UssdServicesCatalogService.restoreDefaults();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Default services restored'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Other services'),
        actions: [
          IconButton(
            tooltip: 'Restore default services',
            icon: const Icon(Icons.restore_rounded),
            onPressed: _restoreDefaults,
          ),
          IconButton(
            tooltip: 'Add service',
            icon: const Icon(Icons.add_rounded),
            onPressed: _addService,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(
                  child: Text('No services yet — tap + to add one',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _services.length,
                  itemBuilder: (context, i) {
                    final s = _services[i];
                    return ListTile(
                      leading: IconButton(
                        icon: Icon(
                          s.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: s.isFavorite ? Colors.amber : null,
                        ),
                        tooltip: s.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                        onPressed: () => _toggleFavorite(s),
                      ),
                      title: Text(s.label),
                      subtitle: Text(s.ussdCode ?? 'Manual trigger (no dial)'),
                      onTap: () => triggerUssdService(context, s),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              _editCode(s);
                              break;
                            case 'reset':
                              _resetCode(s);
                              break;
                            case 'delete':
                              _deleteService(s);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit USSD code')),
                          if (s.defaultUssdCode != null)
                            const PopupMenuItem(
                                value: 'reset', child: Text('Reset to default')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
