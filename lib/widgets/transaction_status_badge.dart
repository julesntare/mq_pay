import 'package:flutter/material.dart';
import '../models/transaction_status.dart';

class TransactionStatusBadge extends StatelessWidget {
  final TransactionStatus status;
  final bool compact;

  const TransactionStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    IconData icon;

    switch (status) {
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

    if (compact) {
      // Just show icon for compact mode
      return Icon(
        icon,
        color: color,
        size: 16,
      );
    }

    // Full badge with icon and text
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
