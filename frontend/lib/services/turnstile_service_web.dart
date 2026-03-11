// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class TurnstileService {
  Object? _bridge() {
    final bridge = js_util.getProperty<Object?>(html.window, '__cfTurnstileBridge');
    if (bridge == null) {
      return null;
    }
    return bridge;
  }

  Future<void> configure(String siteKey) async {
    final bridge = _bridge();
    if (bridge == null) {
      return;
    }
    js_util.callMethod<void>(bridge, 'setSiteKey', [siteKey]);
    js_util.callMethod<void>(bridge, 'execute', const []);
  }

  String? getToken() {
    final bridge = _bridge();
    if (bridge == null) {
      return null;
    }
    final token = js_util.callMethod<Object?>(bridge, 'getToken', const []);
    final value = token?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  bool execute() {
    final bridge = _bridge();
    if (bridge == null) {
      return false;
    }
    final result = js_util.callMethod<Object?>(bridge, 'execute', const []);
    return result == true;
  }

  void reset() {
    final bridge = _bridge();
    if (bridge == null) {
      return;
    }
    js_util.callMethod<void>(bridge, 'reset', const []);
  }
}
