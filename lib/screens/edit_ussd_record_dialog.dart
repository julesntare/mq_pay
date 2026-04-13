import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import '../models/ussd_record.dart';
import '../models/transaction_status.dart';
import '../services/ussd_record_service.dart';
import '../widgets/scroll_indicator.dart';

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
  late bool applyFee; // Track whether to apply fee
  late TransactionStatus status; // Track transaction status
  late bool isLoan;
  late bool loanRecovered;

  @override
  void initState() {
    super.initState();
    amountController =
        TextEditingController(text: widget.record.amount.toStringAsFixed(0));
    recipientController = TextEditingController(text: widget.record.recipient);
    contactNameController =
        TextEditingController(text: widget.record.contactName ?? '');
    reasonController = TextEditingController(text: widget.record.reason ?? '');
    recipientType = widget.record.recipientType;
    applyFee = widget.record.applyFee; // Initialize from existing record
    status = widget.record.status; // Initialize from existing record
    isLoan = widget.record.isLoan;
    loanRecovered = widget.record.loanRecovered;
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
      _showErrorSnackBar(S.of(context).invalidAmount);
      return;
    }

    String recipient = recipientController.text.trim();
    if (recipientType == 'phone' && !_isValidPhoneNumber(recipient)) {
      _showErrorSnackBar(S.of(context).pleaseEnterValidPhone);
      return;
    }

    if (recipientType == 'momo' && !_isValidMomoCode(recipient)) {
      _showErrorSnackBar(S.of(context).pleaseEnterValidMomo);
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
        applyFee: applyFee,
        status: status,
        statusUpdatedAt: status != widget.record.status ? DateTime.now() : widget.record.statusUpdatedAt,
        isLoan: isLoan,
        loanRecovered: isLoan ? loanRecovered : false,
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
          Text(S.of(context).editTransaction),
        ],
      ),
      content: ScrollIndicatorWrapper(
        showTopIndicator: true,
        showBottomIndicator: true,
        child: SingleChildScrollView(
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
                    labelText: S.of(context).amountRwf,
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

                // Fee Toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apply Transaction Fee',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              applyFee
                                  ? 'Fee will be included in total'
                                  : 'No fee will be applied',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: applyFee,
                        onChanged: (value) {
                          setState(() {
                            applyFee = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Loan Toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mark as Loan',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLoan
                                      ? 'This transaction is a loan'
                                      : 'Not a loan',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isLoan,
                            onChanged: (value) {
                              setState(() {
                                isLoan = value;
                                if (!value) loanRecovered = false;
                              });
                            },
                          ),
                        ],
                      ),
                      if (isLoan) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mark as Recovered',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    loanRecovered
                                        ? 'Excluded from daily total'
                                        : 'Still counted in daily total',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: loanRecovered
                                          ? Colors.teal
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: loanRecovered,
                              activeThumbColor: Colors.teal,
                              onChanged: (value) {
                                setState(() {
                                  loanRecovered = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction Status Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Status',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: TransactionStatus.values.map((s) {
                          final isSelected = s == status;
                          Color color;
                          IconData icon;

                          switch (s) {
                            case TransactionStatus.pending:
                              color = Colors.orange;
                              icon = Icons.schedule;
                              break;
                            case TransactionStatus.success:
                              color = Colors.green;
                              icon = Icons.check_circle;
                              break;
                            case TransactionStatus.failed:
                              color = Colors.red;
                              icon = Icons.error;
                              break;
                          }

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  status = s;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : theme.colorScheme.outline,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      icon,
                                      color: isSelected
                                          ? color
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.displayName,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isSelected
                                            ? color
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
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
                        title: Text(S.of(context).phonePayment),
                        subtitle: Text(S.of(context).phoneNumberHint),
                        value: 'phone',
                        groupValue: recipientType,
                        onChanged: (value) {
                          setState(() {
                            recipientType = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: Text(S.of(context).momoPayment),
                        subtitle: Text(S.of(context).momoCode),
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
                    labelText: S.of(context).contactNameOptional,
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: S.of(context).enterNameForContact,
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
                    labelText: recipientType == 'phone'
                        ? S.of(context).phoneNumberLabel
                        : S.of(context).momoCode,
                    prefixIcon: Icon(recipientType == 'phone'
                        ? Icons.phone_rounded
                        : Icons.qr_code_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: recipientType == 'phone'
                        ? S.of(context).phoneNumberHint
                        : '123456',
                    errorText: recipientController.text.isNotEmpty &&
                            ((recipientType == 'phone' &&
                                    !_isValidPhoneNumber(
                                        recipientController.text)) ||
                                (recipientType == 'momo' &&
                                    !_isValidMomoCode(
                                        recipientController.text)))
                        ? (recipientType == 'phone'
                            ? S.of(context).pleaseEnterValidPhone
                            : S.of(context).pleaseEnterValidMomo)
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Reason field (optional) with suggestions
                FutureBuilder<List<String>>(
                  future: UssdRecordService.getUniqueReasons(),
                  builder: (context, snapshot) {
                    final options = snapshot.data ?? [];
                    return Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return options.where((String option) {
                          return option
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        reasonController.text = selection;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        controller.text = reasonController.text;
                        controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length));
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: S.of(context).reasonOptional,
                            hintText: S.of(context).optionalTransactionNote,
                            prefixIcon: Icon(Icons.note_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (v) => reasonController.text = v,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(S.of(context).cancel),
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
              : Text(S.of(context).saveChanges),
        ),
      ],
    );
  }
}
