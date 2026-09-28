import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'music_section_screen.dart';
import '../services/global_music_service.dart';
import '../services/media_downloader_service.dart';
import '../services/music_search_service.dart';

class MusicPlayerScreen extends StatefulWidget {
  static const routeName = '/music-player';
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final GlobalMusicService _musicService = GlobalMusicService();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MediaDownloaderService _downloadService = MediaDownloaderService();

  final List<SongModel> _libraryTracks = [];
  final Set<String> _favoritePaths = {};
  final Map<String, List<SongModel>> _folderGroups = {};
  final List<Map<String, String>> _downloadedTrackEntries = [];

  bool _isSearchingOnline = false;
  final TextEditingController _searchController = TextEditingController();
  final List<MusicSearchResult> _onlineSearchResults = [];

  // Sound Engine Telemetry
  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;

  // Visualizer Animation
  late AnimationController _turntableController;
  late AnimationController _visualizerController;
  late AnimationController _pulseController;

  final Color _cBackground = const Color(0xFF04060E);
  final Color _cCyan = const Color(0xFF00E5FF);
  final Color _cPurple = const Color(0xFFB026FF);
  final Color _cGreen = const Color(0xFF00FF88);
  final Color _cPink = const Color(0xFFFF2A85);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (_musicService.isPlaying) {
      _turntableController.repeat();
    }

    _musicService.addListener(_onServiceUpdate);

    _loadLibrary();
    _loadFavorites();
    _downloadService.addListener(_updateDownloadedEntries);
    _updateDownloadedEntries();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_musicService.isPlaying) {
      if (!_turntableController.isAnimating) _turntableController.repeat();
    } else {
      _turntableController.stop();
    }
  }

  @override
  void dispose() {
    _musicService.removeListener(_onServiceUpdate);
    _sleepTimer?.cancel();
    _turntableController.dispose();
    _visualizerController.dispose();
    _pulseController.dispose();
    _downloadService.removeListener(_updateDownloadedEntries);
    _searchController.dispose();
    // CRITICAL: DO NOT dispose _musicService or _player! Music continues playing in background!
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final hasPermission = await _audioQuery.permissionsStatus();
      if (!hasPermission) {
        await _audioQuery.permissionsRequest();
      }

      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      if (!mounted) return;

      final groups = <String, List<SongModel>>{};
      for (final song in songs) {
        final folder = song.data.isNotEmpty ? path.dirname(song.data) : 'Unknown';
        groups.putIfAbsent(folder, () => []).add(song);
      }

      setState(() {
        _libraryTracks.clear();
        _libraryTracks.addAll(songs);
        _folderGroups.clear();
        _folderGroups.addAll(groups);
      });
    } catch (e) {
      debugPrint('[MusicPlayerScreen] Error loading library: $e');
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('nex_music_favorites') ?? [];
    if (mounted) {
      setState(() => _favoritePaths.addAll(favs));
    }
  }

  Future<void> _toggleFavorite() async {
    final curPath = _musicService.currentTrackPath;
    if (curPath == null || curPath.isEmpty) return;

    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoritePaths.contains(curPath)) {
        _favoritePaths.remove(curPath);
      } else {
        _favoritePaths.add(curPath);
      }
    });
    await prefs.setStringList('nex_music_favorites', _favoritePaths.toList());
  }

  void _updateDownloadedEntries() {
    final downloads = _downloadService.historyTasks
        .where((t) => t.savedPath != null && t.savedPath!.isNotEmpty)
        .map((t) {
      return {
        'id': t.id,
        'title': t.title,
        'artist': 'Downloaded Media',
        'filePath': t.savedPath!,
        'url': t.url,
      };
    }).toList();

    if (mounted) {
      setState(() {
        _downloadedTrackEntries.clear();
        _downloadedTrackEntries.addAll(downloads);
      });
    }
  }

  void _playSongModel(SongModel song) {
    HapticFeedback.selectionClick();
    _musicService.playTrack(
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      filePath: song.data,
    );
  }

  void _pickLocalAudioFile() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
    );

    if (result != null && result.path != null) {
      final file = File(result.path!);
      final filename = path.basenameWithoutExtension(file.path);
      _musicService.playTrack(
        title: filename,
        artist: 'Local File',
        filePath: file.path,
      );
    }
  }

  void _searchOnlineMusic(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearchingOnline = true;
      _onlineSearchResults.clear();
    });

    try {
      final results = await MusicSearchService.search(query.trim());
      if (mounted) {
        setState(() {
          _onlineSearchResults.addAll(results);
          _isSearchingOnline = false;
        });
      }
    } catch (e) {
      debugPrint('[MusicPlayerScreen] Online search error: $e');
      if (mounted) {
        setState(() => _isSearchingOnline = false);
      }
    }
  }

  void _showOnlineSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF080D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.cloud_download_rounded, color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'ONLINE AUDIO VAULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cCyan.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search songs, remixes, artists...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                          onPressed: () {
                            _searchOnlineMusic(_searchController.text);
                            setModalState(() {});
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        _searchOnlineMusic(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isSearchingOnline)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                      ),
                    )
                  else if (_onlineSearchResults.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Type a track name and search online audio',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _onlineSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (_, idx) {
                          final item = _onlineSearchResults[idx];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _cPurple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _cPurple.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.music_note_rounded, color: Color(0xFFB026FF)),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              item.artist,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF00E5FF), size: 32),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _musicService.playTrack(
                                  title: item.title,
                                  artist: item.artist,
                                  url: item.previewUrl,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.bedtime_rounded, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 8),
            Text('Sleep Timer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 45, 60].map((mins) {
            return ListTile(
              title: Text('$mins Minutes', style: const TextStyle(color: Colors.white)),
              trailing: _sleepTimerMinutes == mins
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88))
                  : null,
              onTap: () {
                _sleepTimer?.cancel();
                setState(() => _sleepTimerMinutes = mins);
                _sleepTimer = Timer(Duration(minutes: mins), () {
                  _musicService.pause();
                  if (mounted) setState(() => _sleepTimerMinutes = 0);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Audio will turn off in $mins minutes.')),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          if (_sleepTimerMinutes > 0)
            TextButton(
              onPressed: () {
                _sleepTimer?.cancel();
                setState(() => _sleepTimerMinutes = 0);
                Navigator.pop(ctx);
              },
              child: const Text('CANCEL TIMER', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final curTitle = _musicService.currentTrackTitle ?? 'No Audio Loaded';
    final curArtist = _musicService.currentTrackArtist ?? 'Select a track to start';
    final isFav = _favoritePaths.contains(_musicService.currentTrackPath);

    final pos = _musicService.position;
    final dur = _musicService.duration;
    final maxVal = dur.inMilliseconds.toDouble();
    final curVal = pos.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

    return Scaffold(
      backgroundColor: _cBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00E5FF), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _cPurple.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cPurple.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq_rounded, color: Color(0xFFB026FF), size: 16),
              SizedBox(width: 6),
              Text(
                'NEX AUDIO HUB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bedtime_rounded,
              color: _sleepTimerMinutes > 0 ? _cGreen : Colors.white70,
              size: 20,
            ),
            tooltip: 'Sleep Timer',
            onPressed: _showSleepTimerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded, color: Color(0xFF00E5FF), size: 20),
            tooltip: 'Online Stream',
            onPressed: _showOnlineSearchModal,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white70, size: 20),
            tooltip: 'Open Audio File',
            onPressed: _pickLocalAudioFile,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // ── 1. Cyber Vinyl Holographic Turntable ────────────────────
              _buildTurntableVisualizer(),

              const SizedBox(height: 16),

              // ── 2. Frequency Visualizer Bars ─────────────────────────────
              _buildFrequencyBars(),

              const SizedBox(height: 16),

              // ── 3. Track Details & Favorite Button ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          curTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _cCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _musicService.currentTrackUrl != null ? 'STREAM' : 'HI-RES',
                                style: TextStyle(
                                  color: _cCyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                curArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? _cPink : Colors.white38,
                      size: 24,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── 4. Scrubber & Duration ──────────────────────────────────
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: _cCyan,
                  activeTrackColor: _cCyan,
                  inactiveTrackColor: Colors.white12,
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: curVal,
                  min: 0.0,
                  max: maxVal > 0 ? maxVal : 1.0,
                  onChanged: (val) {
                    _musicService.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(pos), style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                    Text(_formatDuration(dur), style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 5. Master Playback Controls ──────────────────────────────
              _buildPlaybackControls(),

              const SizedBox(height: 24),

              // ── 6. Category Hub Navigation Cards (6 tiles) ──────────────
              _buildCategoryHubGrid(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Turntable Visualizer Widget ────────────────────────────────────────────
  Widget _buildTurntableVisualizer() {
    return AnimatedBuilder(
      animation: Listenable.merge([_turntableController, _pulseController]),
      builder: (context, _) {
        final rot = _turntableController.value * 2 * math.pi;
        final pulse = 1.0 + (_musicService.isPlaying ? (_pulseController.value * 0.04) : 0.0);

        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _musicService.isPlaying
                      ? _cCyan.withValues(alpha: 0.25)
                      : Colors.transparent,
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Grooved Vinyl Disc
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF0F1424),
                        Color(0xFF090D18),
                        Color(0xFF03050A),
                      ],
                      stops: [0.3, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: _musicService.isPlaying
                          ? _cCyan.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),

                // Concentric Grooves
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
                  ),
                ),

                // Rotating Center Label
                Transform.rotate(
                  angle: rot,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_cPurple, _cCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF04060E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Frequency Visualizer Bars ──────────────────────────────────────────────
  Widget _buildFrequencyBars() {
    return AnimatedBuilder(
      animation: _visualizerController,
      builder: (context, _) {
        const barCount = 28;
        return SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final val = _musicService.isPlaying
                  ? math.sin((i * 0.4) + (_visualizerController.value * math.pi * 2)).abs()
                  : 0.15;
              final barH = (val * 20.0).clamp(4.0, 24.0);

              return Container(
                width: 3.5,
                height: barH,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [_cCyan, _cPurple],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Master Playback Controls ───────────────────────────────────────────────
  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: _musicService.isShuffle ? _cCyan : Colors.white38,
            size: 22,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _musicService.toggleShuffle();
          },
        ),

        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
          onPressed: () {
            HapticFeedback.lightImpact();
            _musicService.playPrevious();
          },
        ),

        // Glowing Center Play/Pause Button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _musicService.togglePlayPause();
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_cCyan, _cPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _cCyan.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _musicService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),

        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
          onPressed: () {
            HapticFeedback.lightImpact();
            _musicService.playNext();
          },
        ),

        IconButton(
          icon: Icon(
            Icons.repeat_rounded,
            color: _musicService.isLoop ? _cGreen : Colors.white38,
            size: 22,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _musicService.toggleLoop();
          },
        ),
      ],
    );
  }

  // ── Category Hub Grid (6 tiles) ───────────────────────────────────────────
  Widget _buildCategoryHubGrid() {
    final categories = [
      {
        'title': 'LIBRARY',
        'count': '${_libraryTracks.length}',
        'icon': Icons.music_note_rounded,
        'color': _cCyan,
        'onTap': () async {
          final chosen = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => MusicSectionScreen(title: 'Audio Library', songs: _libraryTracks),
            ),
          );
          if (chosen is SongModel) _playSongModel(chosen);
        },
      },
      {
        'title': 'FOLDER',
        'count': '${_folderGroups.length}',
        'icon': Icons.folder_rounded,
        'color': const Color(0xFFFF9800),
        'onTap': () async {
          final chosenFolder = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => MusicSectionScreen(title: 'Audio Folders', folders: _folderGroups.keys.toList()),
            ),
          );
          if (!mounted) return;
          if (chosenFolder is String && _folderGroups.containsKey(chosenFolder)) {
            final folderSongs = _folderGroups[chosenFolder]!;
            final chosenSong = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(
                builder: (_) => MusicSectionScreen(title: path.basename(chosenFolder), songs: folderSongs),
              ),
            );
            if (chosenSong is SongModel) _playSongModel(chosenSong);
          }
        },
      },
      {
        'title': 'FAVORITE',
        'count': '${_favoritePaths.length}',
        'icon': Icons.favorite_rounded,
        'color': _cPink,
        'onTap': () async {
          final favSongs = _libraryTracks.where((s) => _favoritePaths.contains(s.data)).toList();
          final chosen = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => MusicSectionScreen(title: 'Favorites', songs: favSongs),
            ),
          );
          if (chosen is SongModel) _playSongModel(chosen);
        },
      },
      {
        'title': 'DOWNLOADS',
        'count': '${_downloadedTrackEntries.length}',
        'icon': Icons.download_done_rounded,
        'color': _cGreen,
        'onTap': () async {
          final chosen = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => MusicSectionScreen(title: 'Downloaded Media', downloadedEntries: _downloadedTrackEntries),
            ),
          );
          if (chosen is Map<String, String>) {
            _musicService.playTrack(
              title: chosen['title'] ?? 'Downloaded Track',
              artist: chosen['artist'] ?? 'NEX User',
              filePath: chosen['filePath'],
            );
          }
        },
      },
      {
        'title': 'RECENT',
        'count': '${_libraryTracks.take(15).length}',
        'icon': Icons.history_rounded,
        'color': const Color(0xFF00FFCC),
        'onTap': () async {
          final recent = _libraryTracks.take(20).toList();
          final chosen = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => MusicSectionScreen(title: 'Recently Played', songs: recent),
            ),
          );
          if (chosen is SongModel) _playSongModel(chosen);
        },
      },
      {
        'title': 'AUDIO DSP',
        'count': _musicService.activePreset,
        'icon': Icons.equalizer_rounded,
        'color': _cPurple,
        'onTap': _showDspPresetsSheet,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: categories.length,
      itemBuilder: (_, idx) {
        final cat = categories[idx];
        final col = cat['color'] as Color;

        return InkWell(
          onTap: cat['onTap'] as VoidCallback,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: col.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(cat['icon'] as IconData, color: col, size: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat['count'] as String,
                        style: TextStyle(
                          color: col,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  cat['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDspPresetsSheet() {
    final presets = ['STUDIO FLAT', 'BASS BOOST', 'VOCAL MAX', 'CYBERSPACE', 'NEON CLUB'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.equalizer_rounded, color: Color(0xFFB026FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'EQUALIZER AUDIO PRESETS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...presets.map((preset) {
                final active = _musicService.activePreset == preset;
                return ListTile(
                  title: Text(preset, style: TextStyle(color: active ? _cCyan : Colors.white, fontWeight: FontWeight.bold)),
                  trailing: active ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88)) : null,
                  onTap: () {
                    _musicService.setPreset(preset);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
