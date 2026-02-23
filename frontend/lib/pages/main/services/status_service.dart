import 'dart:convert';

import 'package:http/http.dart' as http;

class StatusService {
  const StatusService();

  Future<StatusResult> fetch() async {
    final res = await http.get(Uri.parse('/api/status'));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return StatusResult(
      llmOk: data['llm_ok'] == true,
      danjiOk: data['danji_ok'] == true,
      version: data['version']?.toString() ?? '--',
    );
  }
}

class StatusResult {
  const StatusResult({
    required this.llmOk,
    required this.danjiOk,
    required this.version,
  });

  final bool llmOk;
  final bool danjiOk;
  final String version;
}
