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

final RegExp _amountShape = RegExp(r'^\d*(?:\.\d*)?[kKmM]?$');
final RegExp _amountSuffix = RegExp(r'[kKmM]$');
final RegExp _amountDigit = RegExp(r'\d');

/// Whether [text] is something [expandAmountShorthand] can actually read:
/// digits with at most one decimal point and an optional single trailing
/// k/m, plus the thousands commas the live formatter inserts.
///
/// Deliberately *not* enforced as an input formatter — swallowing the second
/// "." in ".6.50k" would leave ".650k" and quietly dial 650 instead of the
/// 6,500 the user meant. Better to let the text stand and call it invalid.
///
/// Half-typed states of a valid entry pass ("", ".", ".6", "1.", "1.5"), so
/// this only reads as an error once the user stops mid-nonsense.
bool isWellFormedAmount(String text) {
  final s = text.replaceAll(',', '').trim();
  if (!_amountShape.hasMatch(s)) return false;
  // "k"/"m" only means something once there's a number to scale.
  return !_amountSuffix.hasMatch(s) || _amountDigit.hasMatch(s);
}

final List<TextInputFormatter> _amountInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9kKmM.,]')),
];

/// Validation message for a service dialog's amount/fee field, or null when
/// [text] is acceptable. A blank field is only an error where the amount is
/// [required].
String? _amountFieldError(String text, {required bool required}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return required ? 'Enter an amount' : null;
  if (!isWellFormedAmount(trimmed)) {
    return 'Invalid amount — use one decimal point, e.g. 6.5k for 6,500';
  }
  final value =
      double.tryParse(expandAmountShorthand(trimmed.replaceAll(',', '')));
  if (value == null || value <= 0) return 'Enter an amount of at least 1 RWF';
  return null;
}

/// Prompts for an amount and returns the parsed double, or null if
/// cancelled/invalid. Used for dial-based services, where the amount is
/// always required (it's entered into the USSD menu itself).
Future<double?> promptServiceAmount(
    BuildContext context, UssdServiceShortcut service) async {
  final amountCtrl = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Without this the dialog just closed and nothing happened on an
        // unreadable amount — say so in the field instead.
        final error = _amountFieldError(amountCtrl.text, required: true);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(service.label),
          content: TextField(
            controller: amountCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'e.g. 5000 or 5k',
              errorText: amountCtrl.text.isEmpty ? null : error,
            ),
            keyboardType: TextInputType.text,
            inputFormatters: _amountInputFormatters,
            onChanged: (value) {
              _liveFormatShorthand(amountCtrl, value);
              setState(() {});
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed:
                    error == null ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Continue')),
          ],
        );
      },
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
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Both fields are optional, so blank is fine — but an unreadable
        // entry used to be dropped on the floor without a word.
        final amountError = _amountFieldError(amountCtrl.text, required: false);
        final feeError = _amountFieldError(feeCtrl.text, required: false);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(service.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount (optional)',
                  hintText:
                      "Leave blank if unknown — we'll fill it in once confirmed",
                  errorText: amountError,
                ),
                keyboardType: TextInputType.text,
                inputFormatters: _amountInputFormatters,
                onChanged: (value) {
                  _liveFormatShorthand(amountCtrl, value);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                decoration: InputDecoration(
                  labelText: 'Fee (optional)',
                  hintText: 'e.g. 200 — leave blank if none/unknown',
                  errorText: feeError,
                ),
                keyboardType: TextInputType.text,
                inputFormatters: _amountInputFormatters,
                onChanged: (value) {
                  _liveFormatShorthand(feeCtrl, value);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: (amountError == null && feeError == null)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Continue')),
          ],
        );
      },
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
      fee: service.fee ?? 0.0,
      applyFee: true,
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
      fee: input.fee ?? service.fee,
      applyFee: (input.fee ?? service.fee) != null,
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
