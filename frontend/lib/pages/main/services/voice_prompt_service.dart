import 'dart:convert';

import 'package:http/http.dart' as http;

class VoicePromptService {
  const VoicePromptService();

  Future<VoicePromptListResponse> fetchByCategory(String category) async {
    final response = await http.get(
      Uri.parse('/api/archive/voice-prompts/$category'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Voice prompts fetch failed (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoicePromptListResponse.fromJson(data);
  }
}

class VoicePromptListResponse {
  const VoicePromptListResponse({
    required this.category,
    required this.count,
    required this.items,
  });

  factory VoicePromptListResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VoicePromptItem.fromJson)
        .toList();
    return VoicePromptListResponse(
      category: json['category']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? list.length,
      items: list,
    );
  }

  final String category;
  final int count;
  final List<VoicePromptItem> items;
}

class VoicePromptItem {
  const VoicePromptItem({
    required this.id,
    required this.version,
    required this.type,
    this.emotionLevel,
    this.emotionIntensity,
    required this.direction,
    required this.text,
  });

  factory VoicePromptItem.fromJson(Map<String, dynamic> json) {
    return VoicePromptItem(
      id: json['id']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      emotionLevel: _nullableText(json['emotion_level']),
      emotionIntensity: _nullableText(json['emotion_intensity']),
      direction: json['direction']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }

  final String id;
  final String version;
  final String type;
  final String? emotionLevel;
  final String? emotionIntensity;
  final String direction;
  final String text;

  static String? _nullableText(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
