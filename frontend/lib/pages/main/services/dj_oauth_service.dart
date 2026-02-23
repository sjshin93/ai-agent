import 'dart:convert';

import 'package:http/http.dart' as http;

class DjOauthService {
  Future<DjOauthResult> login({
    required String userId,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('/api/dj-oauth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {
          'userId': userId,
          'password': password,
          'clientType': 'IPhone',
          'isHashedPwd': false,
        },
      ),
    );
    if (res.statusCode != 200) {
      return const DjOauthResult(ok: false, detail: 'Login failed');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DjOauthResult(
      ok: data['ok'] == true,
      detail: data['detail']?.toString(),
      accessToken: data['access_token']?.toString(),
    );
  }
}

class DjOauthResult {
  const DjOauthResult({required this.ok, this.detail, this.accessToken});

  final bool ok;
  final String? detail;
  final String? accessToken;
}
