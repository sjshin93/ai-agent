import 'dart:typed_data';

import 'audio_recorder_service_stub.dart'
    if (dart.library.html) 'audio_recorder_service_web.dart' as impl;

class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.mimeType,
    required this.fileExt,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileExt;
}

abstract class AudioRecorderService {
  bool get isRecording;
  Future<void> start();
  Future<RecordedAudio> stop();
  Future<void> play(RecordedAudio audio);
  void dispose();
}

AudioRecorderService createAudioRecorderService() => impl.createAudioRecorderService();
