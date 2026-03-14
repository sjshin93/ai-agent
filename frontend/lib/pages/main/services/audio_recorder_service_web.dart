import 'dart:async';
import 'dart:developer' as developer;
import 'dart:html' as html;
import 'dart:typed_data';

import 'audio_recorder_service.dart';

AudioRecorderService createAudioRecorderService() => _WebAudioRecorderService();

class _WebAudioRecorderService implements AudioRecorderService {
  static const html.EventStreamProvider<html.Event> _dataAvailableEvent =
      html.EventStreamProvider<html.Event>('dataavailable');
  static const html.EventStreamProvider<html.Event> _stopEvent =
      html.EventStreamProvider<html.Event>('stop');

  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  StreamSubscription<html.Event>? _dataSub;
  StreamSubscription<html.Event>? _stopSub;
  final List<html.Blob> _chunks = [];
  Completer<RecordedAudio>? _stopCompleter;
  String _mimeType = 'audio/webm';
  String _fileExt = 'webm';

  @override
  bool get isRecording => _recorder?.state == 'recording';

  @override
  Future<void> start() async {
    if (isRecording) {
      return;
    }
    _dataSub?.cancel();
    _stopSub?.cancel();
    _chunks.clear();
    _mimeType = _selectMimeType();
    _fileExt = _mimeToExt(_mimeType);
    developer.log(
      'start requested mimeType=$_mimeType fileExt=$_fileExt',
      name: 'voice_recorder',
    );
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      developer.log(
        'start failed: mediaDevices unavailable',
        name: 'voice_recorder',
        level: 1000,
      );
      throw StateError('This browser does not support microphone access.');
    }
    _stream = await mediaDevices.getUserMedia({'audio': true});
    final tracks = _stream?.getAudioTracks() ?? const <html.MediaStreamTrack>[];
    for (final track in tracks) {
      developer.log(
        'audio track state enabled=${track.enabled} muted=${track.muted} readyState=${track.readyState}',
        name: 'voice_recorder',
      );
    }
    developer.log(
      'microphone stream acquired tracks=${_stream?.getTracks().length ?? 0}',
      name: 'voice_recorder',
    );
    _recorder = html.MediaRecorder(
      _stream!,
      {'mimeType': _mimeType},
    );
    _dataSub = _dataAvailableEvent.forTarget(_recorder!).listen((event) {
      final dynamic blobEvent = event;
      final data = blobEvent.data as html.Blob?;
      if (data != null && data.size > 0) {
        _chunks.add(data);
        developer.log(
          'data chunk received size=${data.size} totalChunks=${_chunks.length}',
          name: 'voice_recorder',
        );
      } else {
        developer.log(
          'dataavailable event with empty chunk',
          name: 'voice_recorder',
          level: 900,
        );
      }
    });
    _stopCompleter = Completer<RecordedAudio>();
    _stopSub = _stopEvent.forTarget(_recorder!).listen((_) async {
      try {
        // Some browsers dispatch the final data chunk right around stop;
        // wait briefly so pending dataavailable handlers can append chunks.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final audio = await _buildAudio();
        developer.log(
          'recording stopped bytes=${audio.bytes.length} mimeType=${audio.mimeType}',
          name: 'voice_recorder',
        );
        _stopCompleter?.complete(audio);
      } catch (error, stackTrace) {
        developer.log(
          'failed to build audio on stop: $error',
          name: 'voice_recorder',
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
        _stopCompleter?.completeError(error, stackTrace);
      } finally {
        _cleanupTracks();
      }
    });
    // Emit chunks periodically for better cross-browser reliability.
    _recorder!.start(250);
    developer.log(
      'recorder started state=${_recorder?.state}',
      name: 'voice_recorder',
    );
  }

  @override
  Future<RecordedAudio> stop() async {
    if (!isRecording || _recorder == null) {
      developer.log(
        'stop requested while recorder is not running',
        name: 'voice_recorder',
        level: 1000,
      );
      throw StateError('Recorder is not running.');
    }
    developer.log('stop requested', name: 'voice_recorder');
    try {
      _recorder!.requestData();
    } catch (error, stackTrace) {
      developer.log(
        'requestData failed before stop: $error',
        name: 'voice_recorder',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    }
    // Give the browser a short moment to emit the final dataavailable event.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _recorder!.stop();
    return _stopCompleter!.future;
  }

  @override
  Future<void> play(RecordedAudio audio) async {
    final blob = html.Blob([audio.bytes], audio.mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final player = html.AudioElement(url)
      ..controls = false
      ..autoplay = true;
    await player.play();
    player.onEnded.first.then((_) => html.Url.revokeObjectUrl(url));
  }

  Future<RecordedAudio> _buildAudio() async {
    if (_chunks.isEmpty) {
      developer.log(
        'no chunks available when building audio',
        name: 'voice_recorder',
        level: 1000,
      );
      throw StateError('No audio data recorded.');
    }
    final blob = html.Blob(_chunks, _mimeType);
    final buffer = await _blobToBytes(blob);
    if (buffer.isEmpty) {
      developer.log(
        'blob converted to empty bytes blobSize=${blob.size} chunks=${_chunks.length}',
        name: 'voice_recorder',
        level: 1000,
      );
      throw StateError('Recorded audio bytes are empty.');
    }
    return RecordedAudio(
      bytes: buffer,
      mimeType: _mimeType,
      fileExt: _fileExt,
    );
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.completeError(
          StateError(
            'Unexpected FileReader result type: ${result.runtimeType}',
          ),
        );
      }
    });
    reader.onError.first.then((_) {
      completer.completeError(StateError('Failed to read recorded audio blob.'));
    });
    return completer.future;
  }

  String _selectMimeType() {
    const preferred = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/wav',
    ];
    for (final mime in preferred) {
      if (html.MediaRecorder.isTypeSupported(mime)) {
        return mime;
      }
    }
    return 'audio/webm';
  }

  String _mimeToExt(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('wav')) {
      return 'wav';
    }
    if (lower.contains('ogg')) {
      return 'ogg';
    }
    if (lower.contains('mp4') || lower.contains('m4a')) {
      return 'm4a';
    }
    return 'webm';
  }

  void _cleanupTracks() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
  }

  @override
  void dispose() {
    _cleanupTracks();
    _dataSub?.cancel();
    _stopSub?.cancel();
    _recorder = null;
  }
}
