import 'package:workmanager/workmanager.dart';
import '../models/transaction_status.dart';
import 'ussd_record_service.dart';

/// Registers/cancels the background WorkManager task that polls for
/// delayed confirmation SMS on service-tagged transactions (Cash Power,
/// Canalbox, Umutekano, custom, ...) while the app isn't in the foreground.
///
/// Android enforces a 15-minute floor on periodic tasks — this is the
/// background cadence; the foreground 5s SmsListenerService loop and the
/// on-resume catch-up scan cover faster confirmations while the app is open.
class ServicePollingScheduler {
  static const String taskName = 'servicePollTask';

  static Future<void> ensureRegistered() async {
    try {
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }

  /// Cancels the background poll task if no service-tagged pending
  /// transaction remains. Call after every scan (foreground or background).
  static Future<void> cancelIfIdle() async {
    try {
      final records = await UssdRecordService.getUssdRecords();
      final hasPending = records.any((r) =>
          r.status == TransactionStatus.pending && r.serviceKey != null);
      if (!hasPending) {
        await Workmanager().cancelByUniqueName(taskName);
      }
    } catch (_) {}
  }
}
