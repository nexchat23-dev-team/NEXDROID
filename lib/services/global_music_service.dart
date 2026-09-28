import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'music_notification_service.dart';

class GlobalMusicService extends ChangeNotifier {
  static final GlobalMusicService _instance = GlobalMusicService._internal();
  factory GlobalMusicService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  String? _currentTrackTitle;
  String? _currentTrackArtist;
  String? _currentTrackPath;
  String? _currentTrackUrl;
  String? _currentTrackArt;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  bool _isLoop = false;
  double _playbackSpeed = 1.0;
  String _activePreset = 'STUDIO FLAT';

  List<Map<String, dynamic>> _queue = [];
  int _currentIndex = -1;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  GlobalMusicService._internal() {
    _initListeners();
    MusicNotificationService.initialize();
  }

  void _initListeners() {
    _posSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _stateSub = _player.playerStateStream.listen((state) {
      final playing = state.playing && state.processingState != ProcessingState.completed;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }

      if (state.processingState == ProcessingState.completed) {
        if (_isLoop) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          playNext();
        }
      }
    });
  }

  // Getters
  AudioPlayer get player => _player;
  String? get currentTrackTitle => _currentTrackTitle;
  String? get currentTrackArtist => _currentTrackArtist;
  String? get currentTrackPath => _currentTrackPath;
  String? get currentTrackUrl => _currentTrackUrl;
  String? get currentTrackArt => _currentTrackArt;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  bool get isLoop => _isLoop;
  double get playbackSpeed => _playbackSpeed;
  String get activePreset => _activePreset;
  List<Map<String, dynamic>> get queue => _queue;
  int get currentIndex => _currentIndex;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  void setQueue(List<Map<String, dynamic>> newQueue, int startIndex) {
    _queue = List.from(newQueue);
    if (startIndex >= 0 && startIndex < _queue.length) {
      _currentIndex = startIndex;
      final item = _queue[_currentIndex];
      playTrack(
        title: item['title']?.toString() ?? 'Unknown Track',
        artist: item['artist']?.toString() ?? 'Unknown Artist',
        filePath: item['path']?.toString(),
        url: item['url']?.toString(),
        artUrl: item['artUrl']?.toString(),
      );
    }
  }

  Future<void> playTrack({
    required String title,
    required String artist,
    String? filePath,
    String? url,
    String? artUrl,
  }) async {
    try {
      _currentTrackTitle = title;
      _currentTrackArtist = artist;
      _currentTrackPath = filePath;
      _currentTrackUrl = url;
      _currentTrackArt = artUrl;
      notifyListeners();

      if (filePath != null && filePath.isNotEmpty && File(filePath).existsSync()) {
        await _player.setFilePath(filePath);
      } else if (url != null && url.isNotEmpty) {
        await _player.setUrl(url);
      } else {
        debugPrint('[GlobalMusicService] No valid audio source provided.');
        return;
      }

      await _player.setSpeed(_playbackSpeed);
      await _player.play();

      MusicNotificationService.showNowPlaying(title: title, artist: artist);
    } catch (e) {
      debugPrint('[GlobalMusicService] Error playing track: $e');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e) {
      debugPrint('[GlobalMusicService] Error toggling play/pause: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[GlobalMusicService] Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('[GlobalMusicService] Error resuming: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      MusicNotificationService.dismiss();
      notifyListeners();
    } catch (e) {
      debugPrint('[GlobalMusicService] Error stopping: $e');
    }
  }

  Future<void> seek(Duration pos) async {
    try {
      await _player.seek(pos);
    } catch (e) {
      debugPrint('[GlobalMusicService] Error seeking: $e');
    }
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
    notifyListeners();
  }

  void setPreset(String preset) {
    _activePreset = preset;
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }
    final item = _queue[_currentIndex];
    await playTrack(
      title: item['title']?.toString() ?? 'Unknown Track',
      artist: item['artist']?.toString() ?? 'Unknown Artist',
      filePath: item['path']?.toString(),
      url: item['url']?.toString(),
      artUrl: item['artUrl']?.toString(),
    );
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (_isShuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch) % _queue.length;
    } else {
      _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    }
    final item = _queue[_currentIndex];
    await playTrack(
      title: item['title']?.toString() ?? 'Unknown Track',
      artist: item['artist']?.toString() ?? 'Unknown Artist',
      filePath: item['path']?.toString(),
      url: item['url']?.toString(),
      artUrl: item['artUrl']?.toString(),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
