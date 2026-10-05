import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UserWidgetBridge {
  static const MethodChannel _channel = MethodChannel('app.quanlytao.user/widget');
  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> clearWidget() async {
    if (!isPlatformSupported) return;
    try {
      await _channel.invokeMethod('clearWidget');
    } catch (e) {
      debugPrint('UserWidgetBridge.clearWidget error: $e');
    }
  }

  static Future<void> updateWidgetCount(int count) async {
    if (!isPlatformSupported) return;
    try {
      await _channel.invokeMethod('updateWidgetCount', {'count': count});
    } catch (e) {
      debugPrint('UserWidgetBridge.updateWidgetCount error: $e');
    }
  }

  static Future<void> setWidgetCredentials({
    required String token,
    required String baseUrl,
  }) async {
    if (!isPlatformSupported) return;
    try {
      await _channel.invokeMethod('setWidgetCredentials', {
        'token': token,
        'baseUrl': baseUrl,
      });
    } catch (e) {
      debugPrint('UserWidgetBridge.setWidgetCredentials error: $e');
    }
  }

  static Future<String?> getInitialRoute() async {
    if (!isPlatformSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialRoute');
    } catch (e) {
      debugPrint('UserWidgetBridge.getInitialRoute error: $e');
      return null;
    }
  }

  static void setDeepLinkHandler(void Function(String route) onDeepLink) {
    if (!isPlatformSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final route = call.arguments as String? ?? '/pending';
        onDeepLink(route);
      }
    });
  }

  static void removeDeepLinkHandler() {
    if (!isPlatformSupported) return;
    _channel.setMethodCallHandler(null);
  }
}
