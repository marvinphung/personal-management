import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UserWidgetBridge {
  static const MethodChannel _channel = MethodChannel('app.quanlytao.user/widget');
  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool _initialRouteConsumed = false;

  static Future<void> clearWidget() async {
    if (!isPlatformSupported) return;
    try {
      await _channel.invokeMethod('clearWidget');
    } catch (e) {
      debugPrint('UserWidgetBridge.clearWidget error: $e');
    }
  }

  static Future<void> updateWidgetCount(
    int count, {
    String? owner,
    int? generation,
  }) async {
    if (!isPlatformSupported) return;
    try {
      final args = <String, Object>{'count': count};
      if (owner != null) args['owner'] = owner;
      if (generation != null) args['generation'] = generation;
      await _channel.invokeMethod('updateWidgetCount', args);
    } catch (e) {
      debugPrint('UserWidgetBridge.updateWidgetCount error: $e');
    }
  }

  static Future<void> setWidgetCredentials({
    required String token,
    required String baseUrl,
    String? owner,
    int? generation,
  }) async {
    if (!isPlatformSupported) return;
    try {
      final args = <String, Object>{
        'token': token,
        'baseUrl': baseUrl,
      };
      if (owner != null) args['owner'] = owner;
      if (generation != null) args['generation'] = generation;
      await _channel.invokeMethod('setWidgetCredentials', args);
    } catch (e) {
      debugPrint('UserWidgetBridge.setWidgetCredentials error: $e');
    }
  }

  static Future<String?> getInitialRoute() async {
    if (!isPlatformSupported || _initialRouteConsumed) return null;
    try {
      final route = await _channel.invokeMethod<String>('getInitialRoute');
      if (route != null && route.isNotEmpty) {
        _initialRouteConsumed = true;
        return route;
      }
      return null;
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
