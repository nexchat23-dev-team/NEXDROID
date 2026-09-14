import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  // Animations
  late AnimationController _vinylController;
  late AnimationController _beatController;
  late AnimationController _colorController;
  late AnimationController _particleController;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  final Color _cBackground = const Color(0xFF0A0015);
  final Color _cPrimary = const Color(0xFFB23BFF);
  final Color _cSecondary = const Color(0xFF00B8F4);
  final Color _cAccent = const Color(0xFFFF3399);

  @override
  void initState() {
    super.initState();
    _vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _beatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    _colorController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

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
    _vinylController.dispose();
    _beatController.dispose();
    _colorController.dispose();
    _particleController.dispose();
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
            content: const Text('File not found.', style: TextStyle(color: Colors.white)),
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
          const SnackBar(content: Text('Online search failed. Please try again.')),
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
          const SnackBar(content: Text('Unable to play preview.')),
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
          const SnackBar(content: Text('Downloading preview to your device.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start download.')),
        );
      }
    }
  }

  Widget _buildOnlineSearchResults() {
    if (_isSearchingOnline) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_onlineSearchResults.isEmpty) {
      return const Center(
        child: Text('Search online for previews and downloads.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      itemCount: _onlineSearchResults.length,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (context, index) {
        final result = _onlineSearchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          leading: result.thumbnailUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(result.thumbnailUrl, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54)),
                )
              : const Icon(Icons.music_note, color: Colors.white54, size: 42),
          title: Text(result.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(result.artist, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () => _playOnlinePreview(result),
                  tooltip: 'Play preview',
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () => _downloadOnlineResult(result),
                  tooltip: 'Download preview',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _togglePlay() async {
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
    if (_filteredLibraryTracks.isEmpty) return;
    final nextIndex = math.Random().nextInt(_filteredLibraryTracks.length);
    await _loadSong(_filteredLibraryTracks[nextIndex]);
    await _player.play();
  }

  Future<void> _playPrevious() async {
    if (_filteredLibraryTracks.isEmpty) return;
    final prevIndex = math.Random().nextInt(_filteredLibraryTracks.length);
    await _loadSong(_filteredLibraryTracks[prevIndex]);
    await _player.play();
  }

  void _toggleShuffle() {
    setState(() => _isShuffle = !_isShuffle);
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
    if (_currentTrack == null) return 'No track loaded';
    return path.basename(_currentTrack!.path);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
      {
        'title': 'LIBRARY',
        'count': _libraryTracks.length,
        'icon': Icons.music_note_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'FOLDER',
        'count': _folderGroups.keys.length,
        'icon': Icons.folder_rounded,
        'color': const Color(0xFFF97316),
      },
      {
        'title': 'FAVORITE',
        'count': _favoritePaths.length,
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFF43F5E),
      },
      {
        'title': 'RECENT PLAY',
        'count': _libraryTracks.isNotEmpty ? math.min(_libraryTracks.length, 50) : 0,
        'icon': Icons.access_time_rounded,
        'color': const Color(0xFF06B6D4),
      },
      {
        'title': 'RECENT ADD',
        'count': _libraryTracks.length,
        'icon': Icons.more_time_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'MOST PLAY',
        'count': _libraryTracks.isNotEmpty ? math.min(_libraryTracks.length, 30) : 0,
        'icon': Icons.graphic_eq_rounded,
        'color': const Color(0xFFA855F7),
      },
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
          childAspectRatio: 1.05,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final title = cat['title'] as String;
          final icon = cat['icon'] as IconData;
          final count = cat['count'] as int;
          final color = cat['color'] as Color;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = title);
              _updateFilteredLibraryTracks();
              _openSection(title);
            },
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  // Count badge top right
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Center Icon and Bottom Title
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Icon(icon, color: Colors.white, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
      width: 125,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 24),
              Text(
                count.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
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
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.music_note_rounded, color: Colors.white54),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist ?? 'Unknown', style: const TextStyle(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: Icon(_favoritePaths.contains(songPath) ? Icons.favorite : Icons.favorite_border, color: _favoritePaths.contains(songPath) ? _cAccent : Colors.white54),
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
        title: const Text('Music Player', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => setState(() => _showOnlineSearch = !_showOnlineSearch),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.white),
            onPressed: _pickTracks,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background
          AnimatedBuilder(
            animation: _colorController,
            builder: (context, child) {
              final color1 = Color.lerp(_cBackground, _cPrimary.withValues(alpha: 0.5), math.sin(_colorController.value * 2 * math.pi) * 0.5 + 0.5)!;
              final color2 = Color.lerp(_cBackground, _cSecondary.withValues(alpha: 0.5), math.cos(_colorController.value * 2 * math.pi) * 0.5 + 0.5)!;
              
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color1, color2, _cBackground],
                  ),
                ),
              );
            }
          ),
          
          // Full-screen Blur overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),

          SafeArea(
            child: Column(
              children: [
                if (_showOnlineSearch) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search online...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.1),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isSearchingOnline ? null : _searchOnline,
                          icon: _isSearchingOnline 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: _cPrimary),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 260,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildOnlineSearchResults(),
                    ),
                  ),
                ],

                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow Ring
                      AnimatedBuilder(
                        animation: _beatController,
                        builder: (context, child) {
                          final pulse = _isPlaying ? (math.sin(_beatController.value * 2 * math.pi) * 0.5 + 0.5) : 0.0;
                          return Container(
                            width: size.width * 0.6 + (pulse * 30),
                            height: size.width * 0.6 + (pulse * 30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _cPrimary.withValues(alpha: 0.4 * pulse),
                                  blurRadius: 50 * pulse,
                                  spreadRadius: 20 * pulse,
                                ),
                                BoxShadow(
                                  color: _cSecondary.withValues(alpha: 0.2 * pulse),
                                  blurRadius: 80 * pulse,
                                  spreadRadius: 40 * pulse,
                                ),
                              ]
                            ),
                          );
                        }
                      ),

                      // Particles
                      AnimatedBuilder(
                        animation: _particleController,
                        builder: (context, child) {
                          if (!_particleController.isAnimating) return const SizedBox.shrink();
                          final v = _particleController.value;
                          return Stack(
                            children: List.generate(12, (index) {
                              final angle = (index / 12) * 2 * math.pi;
                              final distance = v * 150;
                              return Positioned(
                                left: size.width / 2 + math.cos(angle) * distance - 5,
                                top: (size.height - 300) / 2 + math.sin(angle) * distance - 5,
                                child: Opacity(
                                  opacity: 1.0 - v,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(color: _cAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _cAccent, blurRadius: 10)]),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // Spinning Vinyl
                      AnimatedBuilder(
                        animation: _vinylController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _vinylController.value * 2 * math.pi,
                            child: SizedBox(
                              width: size.width * 0.6,
                              height: size.width * 0.6,
                              child: CustomPaint(
                                painter: _VinylPainter(accentColor: _cAccent),
                              ),
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
                
                // Track Info Shimmer
                AnimatedBuilder(
                  animation: _colorController,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [Colors.white, _cPrimary, _cSecondary, Colors.white],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                          transform: GradientRotation(_colorController.value * 2 * math.pi),
                        ).createShader(bounds);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          _trackTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                ),
                
                const SizedBox(height: 24),
                
                // Beat Visualizer
                SizedBox(
                  height: 60,
                  child: AnimatedBuilder(
                    animation: _beatController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(32, (index) {
                          final value = (_beatController.value + (index * 0.05)) % 1.0;
                          final hMult = _isPlaying ? (0.5 + 0.5 * math.sin(value * 2 * math.pi)) : 0.1;
                          final barH = 10 + (50 * hMult);
                          return Container(
                            width: 6,
                            height: barH,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_cSecondary, _cPrimary],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: _isPlaying ? [BoxShadow(color: _cPrimary.withValues(alpha: 0.5), blurRadius: 8)] : null,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Categories (6 Grid Cards)
                _buildCategoryCards(),

                const SizedBox(height: 18),

                // Playlists Header & Horizontal Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PLAYLIST(3)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                            onPressed: () {},
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
                            onPressed: () {},
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Horizontal Playlist Cards
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    children: [
                      _buildPlaylistCard('Favorites Mix', _favoritePaths.length, const Color(0xFF0284C7)),
                      _buildPlaylistCard('Cyber Beats', _libraryTracks.length, const Color(0xFF0D9488)),
                      _buildPlaylistCard('Default list', 0, const Color(0xFF475569)),
                    ],
                  ),
                ),

                const SizedBox(height: 120), // Space for sliding panel
              ],
            ),
          ),

          // Floating Yellow Shuffle Action Button
          Positioned(
            right: 20,
            bottom: size.height * 0.26,
            child: GestureDetector(
              onTap: _toggleShuffle,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          
          // Bottom Control Panel & Track List
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.25,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        // Drag Handle
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        
                        // Controls
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              // Seek Bar
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 6,
                                  activeTrackColor: _cPrimary,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: Colors.white,
                                  overlayColor: _cPrimary.withValues(alpha: 0.2),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(_isShuffle ? Icons.shuffle_on : Icons.shuffle, color: _isShuffle ? _cSecondary : Colors.white54),
                                    onPressed: _toggleShuffle,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                                    onPressed: _playPrevious,
                                  ),
                                  GestureDetector(
                                    onTap: _togglePlay,
                                    child: Container(
                                      width: 72, height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [_cPrimary, _cAccent]),
                                        boxShadow: [
                                          BoxShadow(color: _cAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)
                                        ],
                                      ),
                                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                                    onPressed: _playNext,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.stop_rounded, color: Colors.white54),
                                    onPressed: () => _player.stop(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        
                        // Track List
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
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

class _VinylPainter extends CustomPainter {
  final Color accentColor;
  _VinylPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Black base
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF050505));
    
    // Grooves
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < 15; i++) {
      canvas.drawCircle(center, radius * 0.3 + (radius * 0.65 * (i / 15)), groovePaint);
    }
    
    // Label outer ring
    canvas.drawCircle(center, radius * 0.32, Paint()..color = accentColor.withValues(alpha: 0.5));
    
    // Label
    canvas.drawCircle(center, radius * 0.3, Paint()..color = const Color(0xFF1A0E2E));
    
    // Pattern on label
    final labelPattern = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.2, labelPattern);
    
    // Center hole
    canvas.drawCircle(center, radius * 0.05, Paint()..color = const Color(0xFF0A0015));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
