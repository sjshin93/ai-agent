import 'dart:convert';

import 'package:http/http.dart' as http;

class SlackNotificationService {
  Future<void> sendSlackMessage(String message) async {
    final res = await http.post(
      Uri.parse('/api/slack-notification/slack'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode != 200) {
      throw Exception('Slack notify failed: ${res.statusCode}');
    }
  }
}
