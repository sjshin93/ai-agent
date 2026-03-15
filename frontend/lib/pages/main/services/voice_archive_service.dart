import 'dart:convert';
import 'dart:developer' as developer;
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
    developer.log(
      'upload requested bytes=${bytes.length} fileExt=$fileExt tags=$tags capturedAt=${capturedAt?.toUtc().toIso8601String()}',
      name: 'voice_archive',
    );
    if (bytes.isEmpty) {
      developer.log(
        'upload blocked: audio bytes are empty',
        name: 'voice_archive',
        level: 1000,
      );
      throw StateError('Recorded audio is empty before upload.');
    }
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
      developer.log(
        'upload failed status=${response.statusCode} body=${response.body}',
        name: 'voice_archive',
        level: 1000,
      );
      throw Exception(
        'Voice archive failed (${response.statusCode}): ${response.body}',
      );
    }
    developer.log(
      'upload succeeded status=${response.statusCode}',
      name: 'voice_archive',
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceArchiveResponse.fromJson(data);
  }

  Future<VoiceArchiveDeleteResponse> deleteByStorageKey({
    required String storageKey,
  }) async {
    final uri = Uri.parse('/api/archive/voice').replace(
      queryParameters: {
        'storage_key': storageKey,
      },
    );
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Voice archive delete failed (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceArchiveDeleteResponse.fromJson(data);
  }

  Future<VoiceArchiveBulkDeleteResponse> deleteByCategory({
    required String category,
  }) async {
    final uri = Uri.parse('/api/archive/voice/category/$category');
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Voice archive bulk delete failed (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VoiceArchiveBulkDeleteResponse.fromJson(data);
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

class VoiceArchiveDeleteResponse {
  const VoiceArchiveDeleteResponse({
    required this.deleted,
    required this.storageKey,
  });

  factory VoiceArchiveDeleteResponse.fromJson(Map<String, dynamic> json) {
    return VoiceArchiveDeleteResponse(
      deleted: json['deleted'] == true,
      storageKey: json['storage_key']?.toString() ?? '',
    );
  }

  final bool deleted;
  final String storageKey;
}

class VoiceArchiveBulkDeleteResponse {
  const VoiceArchiveBulkDeleteResponse({
    required this.deletedCount,
    required this.tags,
  });

  factory VoiceArchiveBulkDeleteResponse.fromJson(Map<String, dynamic> json) {
    return VoiceArchiveBulkDeleteResponse(
      deletedCount: (json['deleted_count'] as num?)?.toInt() ?? 0,
      tags: json['tags']?.toString() ?? '',
    );
  }

  final int deletedCount;
  final String tags;
}
