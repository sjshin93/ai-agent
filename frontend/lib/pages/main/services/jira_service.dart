import 'dart:convert';

import 'package:http/http.dart' as http;

class JiraService {
  Future<JiraFieldOptions> fetchFieldOptions() async {
    final res = await http.get(Uri.parse('/api/jira/field-options'));
    if (res.statusCode != 200) {
      throw Exception('Jira options failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final customerParts = (data['customer_parts'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final reqTypes = (data['req_types'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return JiraFieldOptions(customerParts: customerParts, reqTypes: reqTypes);
  }

  Future<JiraIssueResult> createIssue({
    required String title,
    required String description,
    required String customerPart,
    required String reqType,
  }) async {
    final res = await http.post(
      Uri.parse('/api/jira/issues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'customer_part': customerPart,
        'req_type': reqType,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Jira issue failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return JiraIssueResult(
      key: data['key']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
    );
  }

  Future<JiraIssueResult> createIssueWithAttachments({
    required String title,
    required String description,
    required String customerPart,
    required String reqType,
    required List<JiraAttachment> attachments,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('/api/jira/issues-with-attachments'),
    );
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['customer_part'] = customerPart;
    request.fields['req_type'] = reqType;
    for (final attachment in attachments) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          attachment.bytes,
          filename: attachment.name,
        ),
      );
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('Jira issue failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return JiraIssueResult(
      key: data['key']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
    );
  }
}

class JiraIssueResult {
  const JiraIssueResult({required this.key, required this.url});

  final String key;
  final String url;
}

class JiraAttachment {
  const JiraAttachment({
    required this.name,
    required this.bytes,
    required this.size,
  });

  final String name;
  final List<int> bytes;
  final int size;
}

class JiraFieldOptions {
  const JiraFieldOptions({
    required this.customerParts,
    required this.reqTypes,
  });

  final List<String> customerParts;
  final List<String> reqTypes;
}
