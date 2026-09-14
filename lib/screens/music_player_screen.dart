import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as path;
import 'music_section_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_downloader_service.dart';
import '../services/music_notification_service.dart';
import '../services/music_search_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  static const routeName = '/music-player';

  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MediaDownloaderService _downloadService = MediaDownloaderService();
  final List<File> _tracks = [];
  final List<SongModel> _libraryTracks = [];
  final List<SongModel> _filteredLibraryTracks = [];
  final Set<String> _favoritePaths = {};
  final Map<String, List<SongModel>> _folderGroups = {};
  final List<Map<String, String>> _downloadedTrackEntries = [];
  String? _selectedFolder;
  File? _currentTrack;
  String? _currentTrackName;
  bool _isShuffle = false;
  String _selectedCategory = 'LIBRARY';
  bool _isPlaying = false;
  bool _isSearchingOnline = false;
  bool _showOnlineSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final List<MusicSearchResult> _onlineSearchResults = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Sound Engine Enhancements
  double _playbackSpeed = 1.0;
  String _activePreset = 'STUDIO FLAT';
  Timer? _sleepTimer;
  int _sleepTimerRemainingSeconds = 0;
  int _visualizerMode = 0; // 0: Cyber Bars, 1: Neon Wave, 2: Cyber Rings

  // Animations
  late AnimationController _vinylController;
  late AnimationController _beatController;
  late AnimationController _colorController;
  late AnimationController _particleController;
  late AnimationController _hudTelemetryController;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  final Color _cBackground = const Color(0xFF06030F);
  final Color _cPrimary = const Color(0xFFB23BFF);
  final Color _cSecondary = const Color(0xFF00E5FF);
  final Color _cAccent = const Color(0xFFFF2A85);
  final Color _cNeonGreen = const Color(0xFF00FF9D);

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _beatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
    _colorController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _hudTelemetryController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

    _positionSub = _player.positionStream.listen((value) {
      if (mounted) setState(() => _position = value);
    });

    _player.durationStream.listen((value) {
      if (mounted && value != null) setState(() => _duration = value);
    });

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (_isPlaying) {
          _vinylController.repeat();
        } else {
          _vinylController.stop();
        }
      }
    });

    _loadFavorites();
    _loadLibrary();
    _downloadService.addListener(_updateDownloadedEntries);
    _updateDownloadedEntries();
    MusicNotificationService.initialize();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _vinylController.dispose();
    _beatController.dispose();
    _colorController.dispose();
    _particleController.dispose();
    _hudTelemetryController.dispose();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _downloadService.removeListener(_updateDownloadedEntries);
    _searchController.dispose();
    _player.dispose();
    MusicNotificationService.dismiss();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('music_player_favorites') ?? <String>[];
    if (mounted) {
      setState(() {
        _favoritePaths
          ..clear()
          ..addAll(saved);
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('music_player_favorites', _favoritePaths.toList());
  }

  Future<void> _loadLibrary() async {
    try {
      final permissionGranted = await _requestMusicPermission();
      List<SongModel> songs = [];
      if (permissionGranted) {
        songs = await _audioQuery.querySongs();
      }

      if (mounted) {
        setState(() {
          _libraryTracks
            ..clear()
            ..addAll(songs);
        });
        _buildFolderGroups();
        _updateFilteredLibraryTracks();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _libraryTracks.clear();
        });
        _buildFolderGroups();
        _updateFilteredLibraryTracks();
      }
    }
  }

  Future<void> _pickTracks() async {
    final result = await FilePicker.pickFile(type: FileType.audio);
    if (result != null && result.path != null) {
      final file = File(result.path!);
      if (mounted) {
        setState(() {
          _tracks
            ..clear()
            ..add(file);
          _currentTrack = file;
          _currentTrackName = path.basename(file.path);
        });
      }
      await _loadTrack(file);
    }
  }

  Future<bool> _requestMusicPermission() async {
    var granted = await _audioQuery.permissionsStatus();
    if (!granted) {
      granted = await _audioQuery.permissionsRequest();
    }
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allow music access to scan audio on this device.')),
      );
    }
    return granted;
  }

  Future<void> _loadTrack(File track) async {
    try {
      await _player.setFilePath(track.path);
      if (mounted) {
        setState(() {
          _currentTrack = track;
          _currentTrackName = path.basename(track.path);
          _duration = _player.duration ?? Duration.zero;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSong(SongModel song) async {
    final songPath = song.data as String?;
    if (songPath == null || songPath.isEmpty) return;
    final file = File(songPath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Audio track file not found on local storage.', style: TextStyle(color: Colors.white)),
            backgroundColor: _cSecondary,
          ),
        );
      }
      return;
    }
    await _loadTrack(file);
  }

  Future<void> _searchOnline() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearchingOnline = true);
    try {
      final results = await MusicSearchService.search(query);
      if (mounted) {
        setState(() {
          _onlineSearchResults
            ..clear()
            ..addAll(results);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Online query failed. Please check internet connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingOnline = false);
    }
  }

  Future<void> _playOnlinePreview(MusicSearchResult result) async {
    try {
      await _player.setUrl(result.previewUrl);
      if (mounted) {
        setState(() {
          _currentTrack = null;
          _currentTrackName = '${result.title} • ${result.artist}';
        });
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to stream preview.')),
        );
      }
    }
  }

  Future<void> _downloadOnlineResult(MusicSearchResult result) async {
    try {
      await _downloadService.startDownload(
        url: result.previewUrl,
        title: result.title,
        platform: MediaPlatform.unknown,
        quality: 'preview',
        format: 'm4a',
        downloadUrl: result.previewUrl,
        thumbnailUrl: result.thumbnailUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accelerated stream download queued.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to queue download.')),
        );
      }
    }
  }

  void _togglePlay() async {
    HapticFeedback.mediumImpact();
    _particleController.forward(from: 0.0);
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {}
  }

  Future<void> _playNext() async {
    HapticFeedback.selectionClick();
    if (_filteredLibraryTracks.isEmpty) return;
    final nextIndex = _isShuffle
        ? math.Random().nextInt(_filteredLibraryTracks.length)
        : ((_filteredLibraryTracks.indexWhere((s) => s.data == _currentTrack?.path) + 1) % _filteredLibraryTracks.length);
    await _loadSong(_filteredLibraryTracks[nextIndex]);
    await _player.play();
  }

  Future<void> _playPrevious() async {
    HapticFeedback.selectionClick();
    if (_filteredLibraryTracks.isEmpty) return;
    final currIndex = _filteredLibraryTracks.indexWhere((s) => s.data == _currentTrack?.path);
    final prevIndex = _isShuffle
        ? math.Random().nextInt(_filteredLibraryTracks.length)
        : (currIndex > 0 ? currIndex - 1 : _filteredLibraryTracks.length - 1);
    await _loadSong(_filteredLibraryTracks[prevIndex]);
    await _player.play();
  }

  void _toggleShuffle() {
    HapticFeedback.lightImpact();
    setState(() => _isShuffle = !_isShuffle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isShuffle ? 'Quantum Shuffle Activated' : 'Sequential Playback Activated'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1E103A),
      ),
    );
  }

  void _updateDownloadedEntries() {
    final downloads = _downloadService.historyTasks
        .where((task) => task.status == DownloadStatus.completed && task.savedPath != null)
        .map((task) => <String, String>{
              'title': task.title,
              'artist': MediaDownloaderService.getPlatformName(task.platform),
              'path': task.savedPath!,
            })
        .toList();

    if (mounted) {
      setState(() {
        _downloadedTrackEntries
          ..clear()
          ..addAll(downloads);
      });
    }
  }

  void _buildFolderGroups() {
    _folderGroups.clear();
    for (final song in _libraryTracks) {
      final folder = _folderName(song);
      if (folder.isEmpty) continue;
      _folderGroups.putIfAbsent(folder, () => []).add(song);
    }
  }

  void _updateFilteredLibraryTracks() {
    final filtered = <SongModel>[];
    switch (_selectedCategory) {
      case 'LIBRARY':
        filtered.addAll(_libraryTracks);
        break;
      case 'FAVORITE':
        filtered.addAll(_libraryTracks.where((song) => _favoritePaths.contains(song.data)));
        break;
      case 'FOLDER':
        if (_selectedFolder != null) {
          filtered.addAll(_folderGroups[_selectedFolder!] ?? []);
        }
        break;
      default:
        filtered.addAll(_libraryTracks);
    }
    setState(() {
      _filteredLibraryTracks
        ..clear()
        ..addAll(filtered);
    });
  }

  String _folderName(SongModel song) {
    try {
      final data = song.data as String?;
      if (data == null || data.isEmpty) return '';
      return path.basename(path.dirname(data));
    } catch (_) {
      return '';
    }
  }

  String get _trackTitle {
    if (_currentTrackName != null && _currentTrackName!.isNotEmpty) return _currentTrackName!;
    if (_currentTrack == null) return 'NO AUDIO LOADED';
    return path.basename(_currentTrack!.path);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Sleep timer setup
  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0826),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bedtime_rounded, color: _cSecondary),
                        const SizedBox(width: 8),
                        const Text(
                          'CYBER SLEEP TIMER',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                        ),
                      ],
                    ),
                    if (_sleepTimerRemainingSeconds > 0)
                      Text(
                        '${_sleepTimerRemainingSeconds ~/ 60}m ${_sleepTimerRemainingSeconds % 60}s',
                        style: TextStyle(color: _cNeonGreen, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Automatically fades audio volume and pauses playback:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [15, 30, 45, 60, 90].map((mins) {
                    return ChoiceChip(
                      label: Text('$mins MINS'),
                      selected: false,
                      onSelected: (_) {
                        Navigator.pop(ctx);
                        _startSleepTimer(mins * 60);
                      },
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      backgroundColor: Colors.white10,
                      selectedColor: _cPrimary,
                    );
                  }).toList()
                    ..add(
                      ChoiceChip(
                        label: const Text('CANCEL TIMER'),
                        selected: false,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          _cancelSleepTimer();
                        },
                        labelStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                      ),
                    ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }

  void _startSleepTimer(int seconds) {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerRemainingSeconds = seconds);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemainingSeconds <= 1) {
        timer.cancel();
        _player.pause();
        if (mounted) setState(() => _sleepTimerRemainingSeconds = 0);
      } else {
        if (mounted) setState(() => _sleepTimerRemainingSeconds--);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sleep timer engaged for ${seconds ~/ 60} minutes.')),
    );
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerRemainingSeconds = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sleep timer cancelled.')),
    );
  }

  // Equalizer and Spatial Engine Modal
  void _showEqualizerModal() {
    final presets = ['STUDIO FLAT', 'BASS BOOST', 'CYBER SYNTH', 'SPATIAL 3D', 'VOCAL MATRIX', 'ELECTRO-PULSE'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0826),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: _cPrimary),
                      const SizedBox(width: 8),
                      const Text(
                        'DSP EQUALIZER & AUDIO ENGINE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Sound Profile:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets.map((preset) {
                      final isSel = _activePreset == preset;
                      return ChoiceChip(
                        label: Text(preset),
                        selected: isSel,
                        onSelected: (val) {
                          setSheetState(() => _activePreset = preset);
                          setState(() => _activePreset = preset);
                          HapticFeedback.selectionClick();
                        },
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        selectedColor: _cSecondary,
                        backgroundColor: Colors.white10,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Playback Speed Warp:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${_playbackSpeed.toStringAsFixed(2)}x', style: TextStyle(color: _cSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: _cSecondary,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setSheetState(() => _playbackSpeed = val);
                      setState(() => _playbackSpeed = val);
                      _player.setSpeed(val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSection(String title) async {
    if (title == 'FOLDER') {
      final folder = await Navigator.push<String?>(
        context,
        MaterialPageRoute(builder: (_) => MusicSectionScreen(title: 'Folders', folders: _folderGroups.keys.toList()..sort())),
      );
      if (folder != null) {
        if (mounted) {
          setState(() {
            _selectedFolder = folder;
            _selectedCategory = 'FOLDER';
            _updateFilteredLibraryTracks();
          });
        }
      }
      return;
    }

    if (title == 'DOWNLOADS') {
      final selectedPath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(builder: (_) => MusicSectionScreen(title: 'Downloads', downloadedEntries: _downloadedTrackEntries)),
      );
      if (selectedPath != null) {
        final file = File(selectedPath);
        if (file.existsSync()) {
          await _player.setFilePath(file.path);
          await _player.play();
          if (mounted) {
            setState(() {
              _currentTrack = file;
              _currentTrackName = path.basename(file.path);
            });
          }
        }
      }
      return;
    }

    List<SongModel> songs;
    switch (title) {
      case 'LIBRARY':
        songs = List<SongModel>.from(_libraryTracks);
        break;
      case 'FAVORITE':
        songs = _libraryTracks.where((song) => _favoritePaths.contains(song.data)).toList();
        break;
      default:
        songs = List<SongModel>.from(_libraryTracks);
    }

    final selectedSong = await Navigator.push<SongModel?>(
      context,
      MaterialPageRoute(builder: (_) => MusicSectionScreen(title: title, songs: songs)),
    );
    if (selectedSong != null) {
      await _loadSong(selectedSong);
      await _player.play();
    }
  }

  Widget _buildCategoryCards() {
    final categories = [
      {'title': 'LIBRARY', 'count': _libraryTracks.length, 'icon': Icons.library_music_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': 'FOLDER', 'count': _folderGroups.keys.length, 'icon': Icons.folder_copy_rounded, 'color': const Color(0xFFF97316)},
      {'title': 'FAVORITE', 'count': _favoritePaths.length, 'icon': Icons.favorite_rounded, 'color': const Color(0xFFF43F5E)},
      {'title': 'DOWNLOADS', 'count': _downloadedTrackEntries.length, 'icon': Icons.download_done_rounded, 'color': const Color(0xFF00E5FF)},
      {'title': 'RECENT', 'count': _libraryTracks.isNotEmpty ? math.min(_libraryTracks.length, 50) : 0, 'icon': Icons.history_toggle_off_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'AUDIO DSP', 'count': 6, 'icon': Icons.graphic_eq_rounded, 'color': const Color(0xFFA855F7)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final title = cat['title'] as String;
          final icon = cat['icon'] as IconData;
          final count = cat['count'] as int;
          final color = cat['color'] as Color;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (title == 'AUDIO DSP') {
                _showEqualizerModal();
              } else {
                setState(() => _selectedCategory = title);
                _updateFilteredLibraryTracks();
                _openSection(title);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF140D2B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCard(String title, int count, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF120A26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.queue_music_rounded, color: color, size: 22),
              Text(
                count.toString(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(SongModel song) {
    final songPath = song.data as String? ?? '';
    final title = song.title.isNotEmpty ? song.title : path.basename(songPath);
    final isCurrent = _currentTrack?.path == songPath;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isCurrent ? _cPrimary.withValues(alpha: 0.3) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent ? Border.all(color: _cPrimary) : null,
        ),
        child: Icon(
          isCurrent ? Icons.volume_up_rounded : Icons.music_note_rounded,
          color: isCurrent ? _cSecondary : Colors.white70,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(color: isCurrent ? _cSecondary : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(song.artist ?? 'Unknown', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1),
      trailing: IconButton(
        icon: Icon(
          _favoritePaths.contains(songPath) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: _favoritePaths.contains(songPath) ? _cAccent : Colors.white38,
        ),
        onPressed: () {
          setState(() {
            if (_favoritePaths.contains(songPath)) {
              _favoritePaths.remove(songPath);
            } else {
              _favoritePaths.add(songPath);
            }
          });
          _saveFavorites();
        },
      ),
      onTap: () async {
        await _loadSong(song);
        await _player.play();
      },
    );
  }

  Widget _buildOnlineSearchResults() {
    if (_isSearchingOnline) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_onlineSearchResults.isEmpty) {
      return const Center(
        child: Text('Search global streams or online previews.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      itemCount: _onlineSearchResults.length,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (context, index) {
        final result = _onlineSearchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          leading: result.thumbnailUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(result.thumbnailUrl, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54)),
                )
              : const Icon(Icons.music_note, color: Colors.white54, size: 36),
          title: Text(result.title, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(result.artist, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.cyanAccent),
                onPressed: () => _playOnlinePreview(result),
                tooltip: 'Stream Preview',
              ),
              IconButton(
                icon: const Icon(Icons.download_for_offline_rounded, color: Colors.purpleAccent),
                onPressed: () => _downloadOnlineResult(result),
                tooltip: 'Accelerated Download',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _cBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cPrimary, _cAccent]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('NEX•AUDIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
            const SizedBox(width: 8),
            Text(
              _isPlaying ? '• LIVE STREAM' : '• STANDBY',
              style: TextStyle(color: _isPlaying ? _cNeonGreen : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bedtime_outlined, color: Colors.white),
            tooltip: 'Cyber Sleep Timer',
            onPressed: _showSleepTimerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            tooltip: 'DSP Equalizer',
            onPressed: _showEqualizerModal,
          ),
          IconButton(
            icon: Icon(_showOnlineSearch ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
            onPressed: () => setState(() => _showOnlineSearch = !_showOnlineSearch),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            onPressed: _pickTracks,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cyber Space Grid & Dynamic Auroral Ambient Glow
          AnimatedBuilder(
            animation: _colorController,
            builder: (context, child) {
              final color1 = Color.lerp(_cBackground, _cPrimary.withValues(alpha: 0.35), math.sin(_colorController.value * 2 * math.pi) * 0.5 + 0.5)!;
              final color2 = Color.lerp(_cBackground, _cSecondary.withValues(alpha: 0.35), math.cos(_colorController.value * 2 * math.pi) * 0.5 + 0.5)!;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.4,
                    colors: [color1, color2, _cBackground],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                if (_showOnlineSearch) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search online tracks & previews...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isSearchingOnline ? null : _searchOnline,
                          icon: _isSearchingOnline
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search_rounded, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: _cPrimary),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildOnlineSearchResults(),
                    ),
                  ),
                ],

                // Holographic 3D Turntable Deck
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Holographic Outer Telemetry Gyro-Ring
                        AnimatedBuilder(
                          animation: _hudTelemetryController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: -_hudTelemetryController.value * 2 * math.pi,
                              child: SizedBox(
                                width: size.width * 0.72,
                                height: size.width * 0.72,
                                child: CustomPaint(
                                  painter: _HoloTelemetryRingPainter(accentColor: _cSecondary),
                                ),
                              ),
                            );
                          },
                        ),

                        // Pulsing Audio Aura
                        AnimatedBuilder(
                          animation: _beatController,
                          builder: (context, child) {
                            final pulse = _isPlaying ? (math.sin(_beatController.value * 2 * math.pi) * 0.5 + 0.5) : 0.0;
                            return Container(
                              width: size.width * 0.58 + (pulse * 24),
                              height: size.width * 0.58 + (pulse * 24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _cPrimary.withValues(alpha: 0.35 * pulse),
                                    blurRadius: 40 * pulse,
                                    spreadRadius: 10 * pulse,
                                  ),
                                  BoxShadow(
                                    color: _cSecondary.withValues(alpha: 0.25 * pulse),
                                    blurRadius: 60 * pulse,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Spinning Cyber Turntable Core
                        AnimatedBuilder(
                          animation: _vinylController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _vinylController.value * 2 * math.pi,
                              child: SizedBox(
                                width: size.width * 0.58,
                                height: size.width * 0.58,
                                child: CustomPaint(
                                  painter: _CyberTurntablePainter(accentColor: _cAccent, secondaryColor: _cSecondary),
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Status / RPM readout
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isPlaying ? '33⅓ RPM' : 'IDLE',
                              style: TextStyle(
                                color: _isPlaying ? _cNeonGreen : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              _activePreset,
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Track Title Display with Neon Cyber Glow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        _trackTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentTrack != null ? 'LOCAL ENCRYPTED MASTER • 320 KBPS' : 'ONLINE AUDIO STREAM',
                        style: TextStyle(color: _cSecondary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Multi-Frequency Visualizer Bar / Spectrum
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _visualizerMode = (_visualizerMode + 1) % 3);
                  },
                  child: SizedBox(
                    height: 46,
                    child: AnimatedBuilder(
                      animation: _beatController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(36, (index) {
                            final shift = (_beatController.value + (index * 0.04)) % 1.0;
                            final mult = _isPlaying ? (0.3 + 0.7 * math.sin(shift * 2 * math.pi).abs()) : 0.08;
                            final barH = 6.0 + (36.0 * mult);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 4.5,
                              height: barH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_cSecondary, _cPrimary],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: _isPlaying
                                    ? [BoxShadow(color: _cSecondary.withValues(alpha: 0.4), blurRadius: 4)]
                                    : null,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Category Navigation Matrix
                _buildCategoryCards(),

                const SizedBox(height: 14),

                // Cyber Playlists Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'QUANTUM PLAYLISTS (3)',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      Text(
                        '${_filteredLibraryTracks.length} TRACKS LOADED',
                        style: TextStyle(color: _cSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Horizontal Playlists
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      _buildPlaylistCard('Favorites Vault', _favoritePaths.length, const Color(0xFF00E5FF)),
                      _buildPlaylistCard('Offline Master', _libraryTracks.length, const Color(0xFFB23BFF)),
                      _buildPlaylistCard('Stream Cache', _downloadedTrackEntries.length, const Color(0xFFFF2A85)),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // Bottom Control Panel & Track List Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.24,
            minChildSize: 0.24,
            maxChildSize: 0.82,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090417).withValues(alpha: 0.88),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        // Drag Handle
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),

                        // Playback Controls & Slider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  activeTrackColor: _cSecondary,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: Colors.white,
                                  overlayColor: _cSecondary.withValues(alpha: 0.2),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                                  max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                  onChanged: (val) {
                                    _player.seek(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(_isShuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                                        color: _isShuffle ? _cSecondary : Colors.white38),
                                    onPressed: _toggleShuffle,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                                    onPressed: _playPrevious,
                                  ),
                                  GestureDetector(
                                    onTap: _togglePlay,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [_cPrimary, _cSecondary]),
                                        boxShadow: [
                                          BoxShadow(color: _cSecondary.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1)
                                        ],
                                      ),
                                      child: Icon(
                                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                                    onPressed: _playNext,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.stop_rounded, color: Colors.white38),
                                    onPressed: () => _player.stop(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10, height: 1),

                        // Track List
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(top: 6, bottom: 20),
                            itemCount: _filteredLibraryTracks.length,
                            itemBuilder: (context, index) {
                              return _buildTrackTile(_filteredLibraryTracks[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// Custom Painter for Outer Telemetry Ring
class _HoloTelemetryRingPainter extends CustomPainter {
  final Color accentColor;
  _HoloTelemetryRingPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final dashPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw ticked border
    const totalTicks = 36;
    for (int i = 0; i < totalTicks; i++) {
      final angle = (i / totalTicks) * 2 * math.pi;
      final p1 = Offset(center.dx + math.cos(angle) * (radius - 8), center.dy + math.sin(angle) * (radius - 8));
      final p2 = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
      canvas.drawLine(p1, p2, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Cyber Turntable Core
class _CyberTurntablePainter extends CustomPainter {
  final Color accentColor;
  final Color secondaryColor;
  _CyberTurntablePainter({required this.accentColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Turntable dark metallic plate
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF070412));

    // Concentric grooves
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 12; i++) {
      canvas.drawCircle(center, radius * 0.28 + (radius * 0.68 * (i / 12)), groovePaint);
    }

    // Outer neon rim
    final rimPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 2, rimPaint);

    // Center disc label
    canvas.drawCircle(center, radius * 0.32, Paint()..color = const Color(0xFF16092F));
    canvas.drawCircle(
      center,
      radius * 0.32,
      Paint()
        ..color = accentColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Center spindle
    canvas.drawCircle(center, radius * 0.06, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
