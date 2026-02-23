import 'dart:convert';

import 'package:http/http.dart' as http;

class SshService {
  Future<String> fetchTop(String siteId, String username) async {
    return fetchCommand(siteId, 'top', username);
  }

  Future<String> fetchCommand(
    String siteId,
    String command,
    String username,
  ) async {
    final res = await http.post(
      Uri.parse('/api/ssh/top'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'site_id': siteId,
        'command': command,
        'username': username,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final detail = data['detail']?.toString() ?? res.body;
        throw Exception('SSH top failed: $detail');
      } catch (_) {
        throw Exception('SSH top failed: ${res.body}');
      }
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['output']?.toString() ?? '';
  }
}
