import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminService {
  Future<List<AdminUser>> fetchUsers() async {
    final res = await http.get(Uri.parse('/api/admin/users'));
    if (res.statusCode != 200) {
      throw Exception('Admin users failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final users = (data['users'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList();
    return users;
  }
}

class AdminUser {
  const AdminUser({
    required this.userId,
    required this.provider,
    required this.role,
    required this.nickname,
    required this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      userId: json['user_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      nickname: json['nickname']?.toString() ?? '',
      lastLoginAt: json['last_login_at']?.toString() ?? '',
    );
  }

  final String userId;
  final String provider;
  final String role;
  final String nickname;
  final String lastLoginAt;
}
