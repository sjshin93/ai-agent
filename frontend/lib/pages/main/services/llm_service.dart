import 'dart:convert';

import 'package:http/http.dart' as http;

class LlmService {
  Future<String> query(String prompt, {String? model}) async {
    final res = await http.post(
      Uri.parse('/api/llm/query'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, if (model != null) 'model': model}),
    );
    if (res.statusCode != 200) {
      throw Exception('LLM query failed: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['output']?.toString() ?? '';
  }
}
