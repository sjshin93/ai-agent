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

  Future<List<AdminLogEntry>> fetchLogs(
    String logType, {
    int limit = 80,
  }) async {
    final uri = Uri.parse('/api/admin/logs').replace(
      queryParameters: {
        'type': logType,
        'limit': limit.toString(),
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Admin logs failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdminLogEntry.fromJson)
        .toList();
    return entries;
  }

  Future<AdminStats> fetchStats() async {
    final res = await http.get(Uri.parse('/api/admin/stats'));
    if (res.statusCode != 200) {
      throw Exception('Admin stats failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminStats.fromJson(data);
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

class AdminLogEntry {
  const AdminLogEntry({
    required this.occurredAt,
    required this.userId,
    required this.sessionId,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.clientIp,
    required this.userAgent,
  });

  factory AdminLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminLogEntry(
      occurredAt: DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.now(),
      userId: json['user_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      statusCode: int.tryParse(json['status_code']?.toString() ?? '') ?? 0,
      durationMs: int.tryParse(json['duration_ms']?.toString() ?? '') ?? 0,
      clientIp: json['client_ip']?.toString() ?? '',
      userAgent: json['user_agent']?.toString() ?? '',
    );
  }

  final DateTime occurredAt;
  final String userId;
  final String sessionId;
  final String method;
  final String path;
  final int statusCode;
  final int durationMs;
  final String clientIp;
  final String userAgent;
}

class AdminStats {
  const AdminStats({
    required this.subscriberCount,
    required this.visitorCount,
    required this.apiCallCount,
    required this.traffic,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final trafficData = (json['traffic'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TrafficPoint.fromJson)
        .toList();
    return AdminStats(
      subscriberCount:
          int.tryParse(json['subscriber_count']?.toString() ?? '') ?? 0,
      visitorCount: int.tryParse(json['visitor_count']?.toString() ?? '') ?? 0,
      apiCallCount:
          int.tryParse(json['api_call_count']?.toString() ?? '') ?? 0,
      traffic: trafficData,
    );
  }

  final int subscriberCount;
  final int visitorCount;
  final int apiCallCount;
  final List<TrafficPoint> traffic;
}

class TrafficPoint {
  const TrafficPoint({
    required this.timestamp,
    required this.apiCalls,
  });

  factory TrafficPoint.fromJson(Map<String, dynamic> json) {
    return TrafficPoint(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      apiCalls: int.tryParse(json['api_calls']?.toString() ?? '') ?? 0,
    );
  }

  final DateTime timestamp;
  final int apiCalls;
}
