import 'dart:convert';

import 'package:http/http.dart' as http;

class DiaryService {
  const DiaryService();

  Future<DiaryArchiveResponse> archiveDiary({
    required DateTime eventDate,
    required String rawText,
    String? emotionLabel,
    String? eventText,
    String? feelingText,
    String? reasonText,
    String? nextActionText,
  }) async {
    final payload = <String, dynamic>{
      'event_date': _formatDate(eventDate),
      'raw_text': rawText,
      if (emotionLabel != null && emotionLabel.isNotEmpty)
        'emotion_label': emotionLabel,
      if (eventText != null && eventText.isNotEmpty) 'event_text': eventText,
      if (feelingText != null && feelingText.isNotEmpty)
        'feeling_text': feelingText,
      if (reasonText != null && reasonText.isNotEmpty)
        'reason_text': reasonText,
      if (nextActionText != null && nextActionText.isNotEmpty)
        'next_action_text': nextActionText,
    };
    final response = await http.post(
      Uri.parse('/api/archive/diary'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Diary archive failed (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DiaryArchiveResponse.fromJson(data);
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class DiaryArchiveResponse {
  const DiaryArchiveResponse({
    required this.id,
    required this.personId,
    required this.storagePath,
    required this.createdAt,
    required this.sha256,
    required this.eventDate,
    this.emotionLabel,
    this.eventText,
    this.feelingText,
    this.reasonText,
    this.nextActionText,
  });

  factory DiaryArchiveResponse.fromJson(Map<String, dynamic> json) {
    return DiaryArchiveResponse(
      id: json['id']?.toString() ?? '',
      personId: json['person_id']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      sha256: json['sha256']?.toString() ?? '',
      eventDate: DateTime.tryParse(json['event_date']?.toString() ?? '') ??
          DateTime.now(),
      emotionLabel: json['emotion_label']?.toString(),
      eventText: json['event_text']?.toString(),
      feelingText: json['feeling_text']?.toString(),
      reasonText: json['reason_text']?.toString(),
      nextActionText: json['next_action_text']?.toString(),
    );
  }

  final String id;
  final String personId;
  final String storagePath;
  final DateTime createdAt;
  final String sha256;
  final DateTime eventDate;
  final String? emotionLabel;
  final String? eventText;
  final String? feelingText;
  final String? reasonText;
  final String? nextActionText;
}
