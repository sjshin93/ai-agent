import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  Future<({bool authenticated, String? userId, String? nickname, String? role})> me() async {
    final res = await http.get(Uri.parse('/api/auth/me'));
    if (res.statusCode != 200) {
      return (authenticated: false, userId: null, nickname: null, role: null);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final authenticated = data['authenticated'] == true;
    return (
      authenticated: authenticated,
      userId: data['user_id']?.toString(),
      nickname: data['nickname']?.toString(),
      role: data['role']?.toString(),
    );
  }

  Future<void> logout() async {
    await http.post(Uri.parse('/api/auth/logout'));
  }
}
