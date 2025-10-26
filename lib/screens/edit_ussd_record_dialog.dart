import 'package:flutter/material.dart';
import '../models/ussd_record.dart';
import '../services/ussd_record_service.dart';

class EditUssdRecordDialog extends StatefulWidget {
  final UssdRecord record;

  const EditUssdRecordDialog({
    super.key,
    required this.record,
  });

  @override
  State<EditUssdRecordDialog> createState() => _EditUssdRecordDialogState();
}

class _EditUssdRecordDialogState extends State<EditUssdRecordDialog> {
  late TextEditingController amountController;
  late TextEditingController recipientController;
  late TextEditingController contactNameController;
  late TextEditingController reasonController;
  String recipientType = 'phone';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    amountController =
        TextEditingController(text: widget.record.amount.toStringAsFixed(0));
    recipientController = TextEditingController(text: widget.record.recipient);
    contactNameController = TextEditingController(text: widget.record.contactName ?? '');
    reasonController = TextEditingController(text: widget.record.reason ?? '');
    recipientType = widget.record.recipientType;
  }

  @override
  void dispose() {
    amountController.dispose();
    recipientController.dispose();
    contactNameController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      return cleaned.length == 12;
    } else if (cleaned.startsWith('078') ||
        cleaned.startsWith('079') ||
        cleaned.startsWith('072') ||
        cleaned.startsWith('073')) {
      return cleaned.length == 10;
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      return cleaned.length == 9;
    }

    return false;
  }

  bool _isValidMomoCode(String momoCode) {
    String cleaned = momoCode.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 3;
  }

  bool _isValidAmount() {
    if (amountController.text.isEmpty) return false;
    final amount = double.tryParse(amountController.text);
    return amount != null && amount >= 1;
  }

  String _maskPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length >= 10) {
      String first = cleaned.substring(0, 3);
      String last = cleaned.substring(cleaned.length - 2);
      String masked = '*' * (cleaned.length - 5);
      return '$first$masked$last';
    }
    return phoneNumber;
  }

  String _formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('2507')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      cleaned = '0' + cleaned;
    } else if (cleaned.startsWith('8') ||
        cleaned.startsWith('9') ||
        cleaned.startsWith('2') ||
        cleaned.startsWith('3')) {
      cleaned = '07' + cleaned;
    }

    if (cleaned.length == 10 &&
        (cleaned.startsWith('078') ||
            cleaned.startsWith('079') ||
            cleaned.startsWith('072') ||
            cleaned.startsWith('073'))) {
      return cleaned;
    }

    return '';
  }

  String _getServiceType(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('25078') ||
        cleaned.startsWith('25079') ||
        cleaned.startsWith('25072') ||
        cleaned.startsWith('25073')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('2507')) {
      cleaned = '0' + cleaned.substring(3);
    } else if (cleaned.startsWith('78') ||
        cleaned.startsWith('79') ||
        cleaned.startsWith('72') ||
        cleaned.startsWith('73')) {
      cleaned = '0' + cleaned;
    }

    if (cleaned.startsWith('072') || cleaned.startsWith('073')) {
      return '2'; // Airtel
    } else if (cleaned.startsWith('078') || cleaned.startsWith('079')) {
      return '1'; // MTN
    }

    return '1'; // Default to MTN
  }

  String _generateUssdCode() {
    String input = recipientController.text.trim();
    String amount = amountController.text.trim();

    if (recipientType == 'phone' && _isValidPhoneNumber(input)) {
      String formattedPhone = _formatPhoneNumber(input);
      String serviceType = _getServiceType(formattedPhone);
      return '*182*1*$serviceType*$formattedPhone*$amount#';
    } else if (recipientType == 'momo' && _isValidMomoCode(input)) {
      return '*182*8*1*$input*$amount#';
    }

    return widget.record.ussdCode;
  }

  Future<void> _saveChanges() async {
    if (!_isValidAmount()) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    String recipient = recipientController.text.trim();
    if (recipientType == 'phone' && !_isValidPhoneNumber(recipient)) {
      _showErrorSnackBar('Please enter a valid phone number');
      return;
    }

    if (recipientType == 'momo' && !_isValidMomoCode(recipient)) {
      _showErrorSnackBar('Please enter a valid momo code');
      return;
    }

    setState(() => isLoading = true);

    try {
      final updatedRecord = widget.record.copyWith(
        amount: double.parse(amountController.text),
        recipient: recipient,
        recipientType: recipientType,
        ussdCode: _generateUssdCode(),
        contactName: contactNameController.text.trim().isEmpty
            ? null
            : contactNameController.text.trim(),
        maskedRecipient:
            recipientType == 'phone' ? _maskPhoneNumber(recipient) : null,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      await UssdRecordService.updateUssdRecord(updatedRecord);

      if (mounted) {
        Navigator.of(context)
            .pop(true); // Return true to indicate changes were made
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Edit Transaction'),
        ],
      ),
      content: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: double.maxFinite),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount Field
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (RWF)',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText:
                      amountController.text.isNotEmpty && !_isValidAmount()
                          ? 'Enter valid amount'
                          : null,
                ),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Payment Type Selector
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Phone Payment'),
                      subtitle: const Text('078xxxxxxx'),
                      value: 'phone',
                      groupValue: recipientType,
                      onChanged: (value) {
                        setState(() {
                          recipientType = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Momo Payment'),
                      subtitle: const Text('Momo Code'),
                      value: 'momo',
                      groupValue: recipientType,
                      onChanged: (value) {
                        setState(() {
                          recipientType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Contact Name Field (optional)
              TextField(
                controller: contactNameController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Contact Name (Optional)',
                  prefixIcon: Icon(Icons.person_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Enter name for this contact',
                ),
              ),
              const SizedBox(height: 12),

              // Recipient Field
              TextField(
                controller: recipientController,
                keyboardType: recipientType == 'phone'
                    ? TextInputType.phone
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText:
                      recipientType == 'phone' ? 'Phone Number' : 'Momo Code',
                  prefixIcon: Icon(recipientType == 'phone'
                      ? Icons.phone_rounded
                      : Icons.qr_code_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: recipientType == 'phone' ? '078xxxxxxx' : '123456',
                  errorText: recipientController.text.isNotEmpty &&
                          ((recipientType == 'phone' &&
                                  !_isValidPhoneNumber(
                                      recipientController.text)) ||
                              (recipientType == 'momo' &&
                                  !_isValidMomoCode(recipientController.text)))
                      ? 'Enter valid ${recipientType == 'phone' ? 'phone number' : 'momo code'}'
                      : null,
                ),
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Reason field (optional)
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  prefixIcon: Icon(Icons.note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Optional note about this transaction',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _saveChanges,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
