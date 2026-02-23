import 'dart:convert';

import 'package:http/http.dart' as http;

class HtOauthService {
  Future<HtOauthResult> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('/api/ht-oauth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      return const HtOauthResult(ok: false, detail: 'Login failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return HtOauthResult(
      ok: data['ok'] == true,
      detail: data['detail']?.toString(),
      accessToken: data['access_token']?.toString(),
    );
  }

  Future<void> logout({required String username}) async {
    await http.post(
      Uri.parse('/api/ht-oauth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
  }
}

class HtOauthResult {
  const HtOauthResult({required this.ok, this.detail, this.accessToken});

  final bool ok;
  final String? detail;
  final String? accessToken;
}
