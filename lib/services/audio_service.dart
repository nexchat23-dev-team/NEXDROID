import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  Future<void> initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    _isRecorderInitialized = true;
    await Permission.microphone.request();
  }

  Future<void> disposeRecorder() async {
    if (_recorder != null) {
      await _recorder!.closeRecorder();
      _recorder = null;
      _isRecorderInitialized = false;
    }
  }

  Future<String?> startRecording(String filePath) async {
    if (!_isRecorderInitialized) await initRecorder();
    await _recorder!.startRecorder(toFile: filePath, codec: Codec.aacMP4);
    return filePath;
  }

  Future<void> stopRecording() async {
    if (_recorder != null && _recorder!.isRecording) {
      await _recorder!.stopRecorder();
    }
  }

  Future<void> initPlayer() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    _isPlayerInitialized = true;
  }

  Future<void> disposePlayer() async {
    if (_player != null) {
      await _player!.closePlayer();
      _player = null;
      _isPlayerInitialized = false;
    }
  }

  Future<void> play(String filePath) async {
    if (!_isPlayerInitialized) await initPlayer();
    await _player!.startPlayer(fromURI: filePath, codec: Codec.aacMP4);
  }

  Future<void> stopPlayer() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
    }
  }
}
