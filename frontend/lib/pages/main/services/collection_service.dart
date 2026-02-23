import 'dart:convert';

import 'package:http/http.dart' as http;

class CollectionService {
  Future<List<CollectionItem>> fetchItems() async {
    final res = await http.get(Uri.parse('/api/collection/items'));
    if (res.statusCode != 200) {
      throw Exception('Collection load failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return items;
  }

  Future<CollectionExecuteResult> execute({
    required String id,
    required Map<String, String> params,
    int? siteId,
    String? body,
    String? accessToken,
    required bool verifySsl,
  }) async {
    final res = await http.post(
      Uri.parse('/api/collection/execute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'params': params,
        'site_id': siteId,
        'body': body,
        'access_token': accessToken,
        'verify_ssl': verifySsl,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Execute failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return CollectionExecuteResult(
      statusCode: data['status_code'] as int? ?? 0,
      url: data['url']?.toString() ?? '',
      headers: (data['headers'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value.toString())),
      body: data['body']?.toString() ?? '',
    );
  }
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
    required this.params,
    required this.body,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      method: json['method']?.toString() ?? 'GET',
      url: json['url']?.toString() ?? '',
      params: (json['params'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      body: json['body']?.toString(),
    );
  }

  final String id;
  final String name;
  final String method;
  final String url;
  final List<String> params;
  final String? body;
}

class CollectionExecuteResult {
  const CollectionExecuteResult({
    required this.statusCode,
    required this.url,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final String url;
  final Map<String, String> headers;
  final String body;
}
