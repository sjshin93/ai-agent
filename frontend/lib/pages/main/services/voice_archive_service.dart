import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class VoiceArchiveService {
  const VoiceArchiveService();

  Future<VoiceArchiveResponse> upload({
    required Uint8List bytes,
    required String fileExt,
    required String tags,
    String? emotion,
    String? referenceText,
    String? sttText,
    DateTime? capturedAt,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('/api/archive/voice'),
    );
    request.fields['tags'] = tags;
    request.fields['file_ext'] = fileExt;
    if (emotion != null && emotion.trim().isNotEmpty) {
      request.fields['emotion'] = emotion.trim();
    }
    if (referenceText != null && referenceText.trim().isNotEmpty) {
      request.fields['reference_text'] = referenceText.trim();
    }
    if (sttText != null && sttText.trim().isNotEmpty) {
      request.fields['stt_text'] = sttText.trim();
    }
    if (capturedAt != null) {
      request.fields['captured_at'] = capturedAt.toUtc().toIso8601String();
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'recorded.$fileExt',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception(
        'Voice archive failed (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceArchiveResponse.fromJson(data);
  }
}

class VoiceArchiveResponse {
  const VoiceArchiveResponse({
    required this.id,
    required this.personId,
    required this.fileName,
    required this.fileExt,
    required this.storageKey,
    required this.sha256,
    required this.createdAt,
    this.capturedAt,
  });

  factory VoiceArchiveResponse.fromJson(Map<String, dynamic> json) {
    return VoiceArchiveResponse(
      id: json['id']?.toString() ?? '',
      personId: json['person_id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      fileExt: json['file_ext']?.toString() ?? '',
      storageKey: json['storage_key']?.toString() ?? '',
      sha256: json['sha256']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      capturedAt: DateTime.tryParse(json['captured_at']?.toString() ?? ''),
    );
  }

  final String id;
  final String personId;
  final String fileName;
  final String fileExt;
  final String storageKey;
  final String sha256;
  final DateTime createdAt;
  final DateTime? capturedAt;
}
