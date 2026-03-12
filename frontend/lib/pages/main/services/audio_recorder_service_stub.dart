import 'audio_recorder_service.dart';

AudioRecorderService createAudioRecorderService() => _UnsupportedAudioRecorderService();

class _UnsupportedAudioRecorderService implements AudioRecorderService {
  @override
  bool get isRecording => false;

  @override
  void dispose() {}

  @override
  Future<void> play(RecordedAudio audio) async {
    throw UnsupportedError('Audio recorder is only supported on web.');
  }

  @override
  Future<void> start() async {
    throw UnsupportedError('Audio recorder is only supported on web.');
  }

  @override
  Future<RecordedAudio> stop() async {
    throw UnsupportedError('Audio recorder is only supported on web.');
  }
}
