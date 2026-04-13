import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import '../services/ussd_detector_service.dart';

/// Widget to check and request Accessibility Service permission
class AccessibilityPermissionCard extends StatefulWidget {
  const AccessibilityPermissionCard({super.key});

  @override
  State<AccessibilityPermissionCard> createState() => _AccessibilityPermissionCardState();
}

class _AccessibilityPermissionCardState extends State<AccessibilityPermissionCard> {
  bool _isEnabled = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isChecking = true);
    final isEnabled = await UssdDetectorService.isAccessibilityEnabled();
    setState(() {
      _isEnabled = isEnabled;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isEnabled
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isEnabled ? Icons.check_circle_rounded : Icons.accessibility_new_rounded,
                    color: _isEnabled ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context).ussdAutoDetection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isChecking
                            ? S.of(context).checkingStatus
                            : _isEnabled
                                ? S.of(context).activeStatus
                                : S.of(context).notEnabled,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isEnabled ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isChecking)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded),
                    onPressed: _checkPermissionStatus,
                    tooltip: S.of(context).refreshStatus,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).ussdAutoDetectionDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (!_isEnabled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(S.of(context).tapToEnable,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(S.of(context).openAccessibilitySettings),
                  onPressed: () async {
                    await UssdDetectorService.openAccessibilitySettings();
                    // Check status again after a delay (user might enable it)
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        _checkPermissionStatus();
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context).stepsToEnable,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        S.of(context).ussdDetectionActive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
