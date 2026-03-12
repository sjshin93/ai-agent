import 'dart:async';
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
    _chunks.clear();
    _mimeType = _selectMimeType();
    _fileExt = _mimeToExt(_mimeType);
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw StateError('This browser does not support microphone access.');
    }
    _stream = await mediaDevices.getUserMedia({'audio': true});
    _recorder = html.MediaRecorder(
      _stream!,
      {'mimeType': _mimeType},
    );
    _dataSub = _dataAvailableEvent.forTarget(_recorder!).listen((event) {
      final dynamic blobEvent = event;
      final data = blobEvent.data as html.Blob?;
      if (data != null && data.size > 0) {
        _chunks.add(data);
      }
    });
    _stopCompleter = Completer<RecordedAudio>();
    _stopSub = _stopEvent.forTarget(_recorder!).listen((_) async {
      final audio = await _buildAudio();
      _stopCompleter?.complete(audio);
      _cleanupTracks();
    });
    _recorder!.start();
  }

  @override
  Future<RecordedAudio> stop() async {
    if (!isRecording || _recorder == null) {
      throw StateError('Recorder is not running.');
    }
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
      throw StateError('No audio data recorded.');
    }
    final blob = html.Blob(_chunks, _mimeType);
    final buffer = await _blobToBytes(blob);
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
      } else {
        completer.complete(Uint8List(0));
      }
    });
    reader.onError.first.then((_) {
      completer.completeError(StateError('Failed to read recorded audio blob.'));
    });
    return completer.future;
  }

  String _selectMimeType() {
    const preferred = [
      'audio/wav',
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
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
