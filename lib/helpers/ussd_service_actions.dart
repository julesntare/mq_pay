import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ussd_record.dart';
import '../models/ussd_service_shortcut.dart';
import '../services/ussd_record_service.dart';
import '../services/ussd_transaction_manager.dart';
import '../services/service_polling_scheduler.dart';
import 'launcher.dart';

/// Expands shorthand amount input like "5k" -> "5000", "2.5m" -> "2500000".
String expandAmountShorthand(String input) {
  final lower = input.toLowerCase().trim();
  if (lower.endsWith('k')) {
    final num = double.tryParse(lower.substring(0, lower.length - 1));
    if (num != null && num > 0) return (num * 1000).round().toString();
  } else if (lower.endsWith('m')) {
    final num = double.tryParse(lower.substring(0, lower.length - 1));
    if (num != null && num > 0) return (num * 1000000).round().toString();
  }
  return input;
}

/// Formats a raw numeric string with thousands separators, e.g. "10000" -> "10,000".
String formatAmountWithCommas(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final n = int.tryParse(digits);
  if (n == null) return digits;
  return n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );
}

/// As soon as the user finishes typing a "k"/"m" suffix (e.g. "10k"),
/// live-expands and reformats the field to "10,000" — mirrors the main
/// payment form's amount field behavior in `home.dart`.
void _liveFormatShorthand(TextEditingController controller, String value) {
  final trimmed = value.replaceAll(',', '').trim();
  final lower = trimmed.toLowerCase();
  if (lower.endsWith('k') || lower.endsWith('m')) {
    final expanded = expandAmountShorthand(trimmed);
    final n = int.tryParse(expanded);
    if (n != null) {
      final formatted = formatAmountWithCommas(n.toString());
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }
}

final List<TextInputFormatter> _amountInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9kKmM.,]')),
];

/// Prompts for an amount and returns the parsed double, or null if
/// cancelled/invalid. Used for dial-based services, where the amount is
/// always required (it's entered into the USSD menu itself).
Future<double?> promptServiceAmount(
    BuildContext context, UssdServiceShortcut service) async {
  final amountCtrl = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(service.label),
      content: TextField(
        controller: amountCtrl,
        autofocus: true,
        decoration: const InputDecoration(
            labelText: 'Amount', hintText: 'e.g. 5000 or 5k'),
        keyboardType: TextInputType.text,
        inputFormatters: _amountInputFormatters,
        onChanged: (value) => _liveFormatShorthand(amountCtrl, value),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue')),
      ],
    ),
  );

  if (confirmed != true) return null;
  return double.tryParse(
      expandAmountShorthand(amountCtrl.text.trim().replaceAll(',', '')));
}

/// Result of [promptManualTrigger] — `amount` is null when the user left it
/// blank (unknown upfront, to be filled in once a confirmation SMS matches).
class ManualTriggerInput {
  final double? amount;
  final double? fee;
  const ManualTriggerInput({this.amount, this.fee});
}

/// Prompts for an optional amount and optional fee, for no-code/manual
/// services (e.g. Yego Cab, BK Bank) where the amount is often only known
/// once the confirmation SMS arrives. Returns null if cancelled.
Future<ManualTriggerInput?> promptManualTrigger(
    BuildContext context, UssdServiceShortcut service) async {
  final amountCtrl = TextEditingController();
  final feeCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(service.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountCtrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Amount (optional)',
                hintText: "Leave blank if unknown — we'll fill it in once confirmed"),
            keyboardType: TextInputType.text,
            inputFormatters: _amountInputFormatters,
            onChanged: (value) => _liveFormatShorthand(amountCtrl, value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: feeCtrl,
            decoration: const InputDecoration(
                labelText: 'Fee (optional)',
                hintText: 'e.g. 200 — leave blank if none/unknown'),
            keyboardType: TextInputType.text,
            inputFormatters: _amountInputFormatters,
            onChanged: (value) => _liveFormatShorthand(feeCtrl, value),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue')),
      ],
    ),
  );

  if (confirmed != true) return null;

  final rawAmount = amountCtrl.text.trim();
  final amount = rawAmount.isEmpty
      ? null
      : double.tryParse(expandAmountShorthand(rawAmount.replaceAll(',', '')));

  final rawFee = feeCtrl.text.trim();
  final fee = rawFee.isEmpty
      ? null
      : double.tryParse(expandAmountShorthand(rawFee.replaceAll(',', '')));

  return ManualTriggerInput(amount: amount, fee: fee);
}

/// Amount value used to mark a manual-trigger record's amount as "not yet
/// known" — filled in once a matching confirmation SMS arrives. Safe as a
/// sentinel since a real transaction amount is always > 0 in this app.
const double kUnknownServiceAmount = 0.0;

/// For dial-based services: prompts for the (required) amount, dials the
/// USSD code, and saves a pending record (accessibility-watched).
/// For no-code/manual services (e.g. Yego Cab, BK Bank): prompts for an
/// optional amount/fee and saves the pending record directly with no dial —
/// amount left blank is filled in automatically once a confirmation SMS matches.
/// Registers the background poll task either way.
Future<void> triggerUssdService(
    BuildContext context, UssdServiceShortcut service) async {
  if (service.ussdCode != null) {
    final amount = await promptServiceAmount(context, service);
    if (amount == null || amount <= 0) return;

    final record = UssdRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ussdCode: service.ussdCode!,
      recipient: service.label,
      recipientType: 'misc',
      amount: amount,
      timestamp: DateTime.now(),
      serviceKey: service.serviceKey,
    );

    await UssdRecordService.saveUssdRecord(record);
    await UssdTransactionManager.savePendingTransaction(record);
    if (!context.mounted) return;
    launchUSSD(service.ussdCode!, context);
  } else {
    final input = await promptManualTrigger(context, service);
    if (input == null) return;
    if (input.amount != null && input.amount! <= 0) return;

    final record = UssdRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ussdCode: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      recipient: service.label,
      recipientType: 'misc',
      amount: input.amount ?? kUnknownServiceAmount,
      timestamp: DateTime.now(),
      serviceKey: service.serviceKey,
      fee: input.fee,
      applyFee: input.fee != null,
    );

    await UssdRecordService.saveUssdRecord(record);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${service.label} marked as pending — '
              "you'll be notified when confirmed"),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  await ServicePollingScheduler.ensureRegistered();
}
