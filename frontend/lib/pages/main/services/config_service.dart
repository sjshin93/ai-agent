import 'dart:convert';

import 'package:http/http.dart' as http;

class ConfigService {
  Future<int> getAutoLogoutSeconds() async {
    try {
      final res = await http.get(Uri.parse('/api/config/auto-logout'));
      if (res.statusCode != 200) {
        return 300;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final value = data['auto_logout_seconds'];
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value) ?? 300;
      }
      return 300;
    } catch (_) {
      return 300;
    }
  }

  Future<String> getVersion() async {
    try {
      final res = await http.get(Uri.parse('/api/config/version'));
      if (res.statusCode != 200) {
        return '--';
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['version']?.toString() ?? '--';
    } catch (_) {
      return '--';
    }
  }

  Future<bool> touchSession() async {
    try {
      final res = await http.post(Uri.parse('/api/config/session-touch'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<({bool enabled, String? siteKey})> getTurnstileConfig() async {
    try {
      final res = await http.get(Uri.parse('/api/config/turnstile'));
      if (res.statusCode != 200) {
        return (enabled: false, siteKey: null);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (
        enabled: data['enabled'] == true,
        siteKey: data['site_key']?.toString(),
      );
    } catch (_) {
      return (enabled: false, siteKey: null);
    }
  }

  Future<void> postTurnstileClientLog(Map<String, dynamic> payload) async {
    try {
      await http.post(
        Uri.parse('/api/config/turnstile-client-log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      // Intentionally ignore debug log transport failures.
    }
  }
}
