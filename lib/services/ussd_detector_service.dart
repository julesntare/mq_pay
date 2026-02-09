import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ussd_keyword_detector.dart';
import 'ussd_transaction_manager.dart';

/// Service to detect and process USSD popup responses using Android Accessibility Service
class UssdDetectorService {
  static const MethodChannel _channel = MethodChannel('com.jnserve.mq_pay/ussd_detector');
  static bool _initialized = false;
  static Function(String)? _onUssdResponseCallback;

  /// Initialize the USSD detector service
  static Future<bool> initialize({Function(String)? onUssdResponse}) async {
    if (_initialized) {
      debugPrint('[UssdDetectorService] Already initialized');
      return true;
    }

    try {
      // Set callback for USSD responses
      _onUssdResponseCallback = onUssdResponse;

      // Set method call handler to receive USSD responses from native code
      _channel.setMethodCallHandler(_handleMethodCall);

      // Check if accessibility service is enabled
      final bool isEnabled = await isAccessibilityEnabled();

      _initialized = true;
      debugPrint('[UssdDetectorService] Initialized. Accessibility enabled: $isEnabled');

      return isEnabled;
    } catch (e) {
      debugPrint('[UssdDetectorService] Initialization error: $e');
      return false;
    }
  }

  /// Handles method calls from native Android code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUssdResponse':
        final String ussdText = call.arguments as String;
        debugPrint('[UssdDetectorService] Received USSD response: $ussdText');

        // Validate the USSD response and confirm/reject pending transaction
        final result = await UssdTransactionManager.validateUssdResponse(ussdText);
        final shouldSave = result == true;
        UssdKeywordDetector.logValidation(ussdText, shouldSave);

        // Invoke callback if set
        if (_onUssdResponseCallback != null) {
          _onUssdResponseCallback!(ussdText);
        }

        return shouldSave;

      case 'onUssdDialogOpened':
        debugPrint('[UssdDetectorService] USSD dialog opened');
        return null;

      case 'onUssdDialogClosed':
        debugPrint('[UssdDetectorService] USSD dialog closed');
        return null;

      default:
        debugPrint('[UssdDetectorService] Unknown method: ${call.method}');
        return null;
    }
  }

  /// Check if accessibility service is enabled
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isAccessibilityEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('[UssdDetectorService] Error checking accessibility status: $e');
      return false;
    }
  }

  /// Open accessibility settings to allow user to enable the service
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      debugPrint('[UssdDetectorService] Opening accessibility settings');
    } catch (e) {
      debugPrint('[UssdDetectorService] Error opening accessibility settings: $e');
    }
  }

  /// Start monitoring for USSD responses
  static Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
      debugPrint('[UssdDetectorService] Started monitoring USSD responses');
    } catch (e) {
      debugPrint('[UssdDetectorService] Error starting monitoring: $e');
    }
  }

  /// Stop monitoring for USSD responses
  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
      debugPrint('[UssdDetectorService] Stopped monitoring USSD responses');
    } catch (e) {
      debugPrint('[UssdDetectorService] Error stopping monitoring: $e');
    }
  }

  /// Set the callback function for USSD responses
  static void setCallback(Function(String) callback) {
    _onUssdResponseCallback = callback;
  }

  /// Dispose of the service
  static void dispose() {
    _onUssdResponseCallback = null;
    _initialized = false;
    debugPrint('[UssdDetectorService] Disposed');
  }
}
