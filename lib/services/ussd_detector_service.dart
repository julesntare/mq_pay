import 'package:flutter/services.dart';
import 'ussd_transaction_manager.dart';

class UssdDetectorService {
  static const MethodChannel _channel = MethodChannel('com.jnserve.mq_pay/ussd_detector');
  static bool _initialized = false;
  static Function(String)? _onUssdResponseCallback;

  static Future<bool> initialize({Function(String)? onUssdResponse}) async {
    if (_initialized) return true;

    try {
      _onUssdResponseCallback = onUssdResponse;
      _channel.setMethodCallHandler(_handleMethodCall);
      final bool isEnabled = await isAccessibilityEnabled();
      _initialized = true;
      return isEnabled;
    } catch (e) {
      return false;
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUssdResponse':
        final String ussdText = call.arguments as String;
        final result = await UssdTransactionManager.validateUssdResponse(ussdText);
        if (_onUssdResponseCallback != null) {
          _onUssdResponseCallback!(ussdText);
        }
        return result == true;

      case 'onUssdDialogOpened':
      case 'onUssdDialogClosed':
        return null;

      default:
        return null;
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isAccessibilityEnabled');
      return isEnabled;
    } catch (e) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
    } catch (_) {}
  }

  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (_) {}
  }

  static void setCallback(Function(String) callback) {
    _onUssdResponseCallback = callback;
  }

  static void dispose() {
    _onUssdResponseCallback = null;
    _initialized = false;
  }
}
