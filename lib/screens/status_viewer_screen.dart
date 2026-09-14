import 'package:flutter/material.dart';

import '../services/status_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';

class StatusViewerScreen extends StatefulWidget {
  static const routeName = '/status-viewer';

  final Map<String, dynamic>? status;
  final String? statusId;

  const StatusViewerScreen({super.key, this.status, this.statusId});

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  final StatusService _statusService = StatusService();
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _markViewedIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StatusViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      setState(() {
        _status = widget.status;
      });
      _markViewedIfNeeded();
    }
  }

  Future<void> _markViewedIfNeeded() async {
    final statusId = _status?['id']?.toString() ?? widget.statusId;
    if (statusId == null || statusId.isEmpty) return;

    try {
      await _statusService.viewStatus(statusId);
    } catch (e) {
      debugPrint('Unable to mark status as viewed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusId = _status?['id']?.toString() ?? widget.statusId;

    if (statusId == null || statusId.isEmpty) {
      return _buildFallbackScreen('No status selected');
    }

    if (_status != null) {
      return _buildViewerScreen(_status!);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _statusService.getStatuses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          return _buildFallbackScreen('Unable to load this status');
        }

        final statuses = snapshot.data ?? [];
        final matchedStatus = statuses.where((item) {
          return item['id']?.toString() == statusId;
        }).firstOrNull;

        if (matchedStatus == null) {
          return _buildFallbackScreen('Status not found');
        }

        return _buildViewerScreen(matchedStatus);
      },
    );
  }

  Widget _buildViewerScreen(Map<String, dynamic> status) {
    final text = status['text']?.toString() ?? '';
    final username = status['username']?.toString() ?? 'User';
    final mediaType = status['mediaType']?.toString() ?? 'text';
    final mediaUrl = status['mediaUrl']?.toString();
    final views = status['views'] is int ? status['views'] as int : 0;
    final createdAt = status['createdAt']?.toString();
    final statusId = status['id']?.toString();
    final isTextOnly = mediaType == 'text' || (mediaUrl == null || mediaUrl.isEmpty);

    String timeText = 'recently';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt).toLocal();
        final diff = DateTime.now().difference(dateTime);
        if (diff.inMinutes < 1) {
          timeText = 'just now';
        } else if (diff.inHours < 1) {
          timeText = '${diff.inMinutes}m ago';
        } else if (diff.inDays < 1) {
          timeText = '${diff.inHours}h ago';
        } else {
          timeText = '${diff.inDays}d ago';
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A111F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kNeonGreen, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'STATUS VIEWER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            fontSize: 15,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              backgroundColors: [
                Color(0xFF02030A),
                Color(0xFF06040E),
                Color(0xFF0C0F1A),
                Color(0xFF03040B),
              ],
              leftAuroraColors: [
                Color(0xFFB23BFF),
                Color(0xFF4A2E9A),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFF00D4FF),
                Color(0xFF1A2D5A),
                Color(0x00000000),
              ],
              fogColor: Color(0x24FFFFFF),
              leftAuroraCenter: Alignment(-0.23, -0.25),
              rightAuroraCenter: Alignment(0.8, -0.15),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildStatusHeader(username, timeText, views),
                const SizedBox(height: 16),
                _buildStatusContent(text, mediaType, mediaUrl, isTextOnly),
                const SizedBox(height: 16),
                _buildStatsCard(statusId, views),
                const SizedBox(height: 16),
                _buildViewersSection(statusId),
                const SizedBox(height: 16),
                _buildReactionsSection(statusId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(String username, String timeText, int views) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: kNeonGreen.withValues(alpha: 0.16),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeText • $views views',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kNeonGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: kNeonGreen,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(String text, String mediaType, String? mediaUrl, bool isTextOnly) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTextOnly ? Icons.chat_bubble_outline : Icons.image_outlined,
                color: kNeonPurple,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isTextOnly ? 'Text update' : '${mediaType.toUpperCase()} update',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isTextOnly)
            Text(
              text.isEmpty ? 'No message shared' : text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            )
          else if (mediaUrl != null && mediaUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                height: 220,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    color: Colors.white.withValues(alpha: 0.06),
                    alignment: Alignment.center,
                    child: const Text(
                      'Media preview unavailable',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                },
              ),
            )
          else
            Text(
              'Media content is unavailable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String? statusId, int views) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(Icons.remove_red_eye_outlined, '$views', 'Views'),
          ),
          Expanded(
            child: _buildStatItem(Icons.favorite_border, '0', 'Reactions'),
          ),
          Expanded(
            child: _buildStatItem(Icons.lock_open_rounded, statusId?.substring(0, 4) ?? '---', 'ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: kNeonBlue, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildViewersSection(String? statusId) {
    if (statusId == null || statusId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VIEWERS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _statusService.getStatusViewers(statusId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kNeonGreen, strokeWidth: 2),
                );
              }

              final viewers = snapshot.data ?? [];
              if (viewers.isEmpty) {
                return Text(
                  'No viewers yet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                );
              }

              return Column(
                children: viewers.map((viewer) {
                  final viewedAt = viewer['viewedAt']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: kNeonBlue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Viewer ${viewer['userId']?.toString() ?? 'unknown'}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Text(
                          viewedAt ?? '',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsSection(String? statusId) {
    if (statusId == null || statusId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REACTIONS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _statusService.getStatusReactions(statusId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kNeonGreen, strokeWidth: 2),
                );
              }

              final reactions = snapshot.data ?? [];
              if (reactions.isEmpty) {
                return Text(
                  'No reactions yet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                );
              }

              return Column(
                children: reactions.map((reaction) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          reaction['reaction']?.toString() ?? '💬',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'User ${reaction['userId']?.toString() ?? 'unknown'}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A111F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kNeonGreen, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: kNeonGreen, strokeWidth: 2),
      ),
    );
  }

  Widget _buildFallbackScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A111F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kNeonGreen, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
