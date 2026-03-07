import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  Future<({bool authenticated, String? username})> me() async {
    final res = await http.get(Uri.parse('/api/auth/me'));
    if (res.statusCode != 200) {
      return (authenticated: false, username: null);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final authenticated = data['authenticated'] == true;
    return (
      authenticated: authenticated,
      username: data['username']?.toString(),
    );
  }

  Future<void> logout() async {
    await http.post(Uri.parse('/api/auth/logout'));
  }
}
