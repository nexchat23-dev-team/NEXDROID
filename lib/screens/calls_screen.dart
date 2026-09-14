import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/user_search_screen.dart';
import '../services/call_service.dart';
import '../services/backend_service.dart';
import '../utils/constants.dart';

class CallsScreen extends StatefulWidget {
  static const routeName = '/calls';

  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final CallService _callService = CallService();
  int _selectedCallMode = 0; // 0 = all, 1 = voice, 2 = video

  void _openCallScreen(String recipientId, String recipientName, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          receiverId: recipientId,
          receiverName: recipientName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CallsBackgroundPainter())),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, color: kNeonBlue, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CALL CENTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.4)),
                          Text('SECURE VOICE & VIDEO', style: TextStyle(color: kNeonBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: kNeonBlue, size: 18),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
                          icon: const Icon(Icons.person_add_alt_1_rounded, color: kNeonBlue),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _callService.getCallHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kNeonGreen, strokeWidth: 2));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load your call history.', style: TextStyle(color: Colors.redAccent)));
                }

                final calls = snapshot.data ?? [];
                if (calls.isEmpty) {
                  return _buildEmptyCalls();
                }

                final visibleCalls = _selectedCallMode == 0
                    ? calls
                    : calls.where((call) {
                        final isVideo = call['isVideo'] == true || call['isVideo']?.toString() == 'true';
                        return _selectedCallMode == 1 ? !isVideo : isVideo;
                      }).toList();

                final totalCalls = calls.length;
                final missedCalls = calls.where((call) {
                  final status = (call['status'] as String?)?.toLowerCase() ?? '';
                  return status == 'missed' || status == 'rejected';
                }).length;
                final activeCalls = calls.where((call) {
                  final status = (call['status'] as String?)?.toLowerCase() ?? '';
                  return status == 'pending' || status == 'active';
                }).length;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: _buildHeaderCard())),
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: _buildSummaryPanel(totalCalls, missedCalls, activeCalls))),
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: _buildCallModeSelector())),
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: Text(_selectedCallMode == 0 ? 'Recent call activity' : (_selectedCallMode == 1 ? 'Voice calls' : 'Video calls'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)))),
                    SliverList(delegate: SliverChildBuilderDelegate((context, index) => Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: _buildCallHistoryItem(visibleCalls[index])), childCount: visibleCalls.length)),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
            floatingActionButton: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: FloatingActionButton.extended(
                  backgroundColor: kNeonGreen.withValues(alpha: 0.9),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())),
                  icon: const Icon(Icons.add_ic_call_rounded, color: Colors.black),
                  label: const Text('New call', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallModeSelector() {
    final options = [
      {'label': 'All', 'value': 0},
      {'label': 'Voice', 'value': 1},
      {'label': 'Video', 'value': 2},
    ];

    return Row(
      children: options.map((option) {
        final value = option['value'] as int;
        final isSelected = _selectedCallMode == value;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedCallMode = value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? (value == 1 ? kNeonGreen.withValues(alpha: 0.18) : (value == 2 ? kNeonBlue.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06))) : const Color(0xFF10172E).withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? (value == 1 ? kNeonGreen : (value == 2 ? kNeonBlue : Colors.white.withValues(alpha: 0.18))) : Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                option['label'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryPanel(int totalCalls, int missedCalls, int activeCalls) {
    return Row(children: [Expanded(child: _buildStatChip('Total', totalCalls.toString(), kNeonBlue)), const SizedBox(width: 10), Expanded(child: _buildStatChip('Missed', missedCalls.toString(), Colors.redAccent)), const SizedBox(width: 10), Expanded(child: _buildStatChip('Live', activeCalls.toString(), kNeonGreen))]);
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF10172E).withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 6), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))]),
        ),
      ),
    );
  }

  Widget _buildCallHistoryItem(Map<String, dynamic> callData) {
    final callerId = callData['callerId'] as String?;
    final receiverId = callData['receiverId'] as String? ?? callData['recipientId'] as String?;
    final currentUserId = _callService.currentUserId;
    final otherUserId = currentUserId == callerId ? receiverId : callerId;
    final status = (callData['status'] as String?)?.toLowerCase() ?? 'pending';
    final isMissed = status == 'rejected' || status == 'missed';
    final duration = (callData['duration'] as int?) ?? 0;
    final isVideo = callData['isVideo'] == true || callData['isVideo']?.toString() == 'true';
    final callType = isVideo ? 'Video call' : 'Voice call';
    final callAccent = isVideo ? kNeonBlue : kNeonGreen;
    final time = _parseTimestamp(callData['createdAt'] ?? callData['timestamp']);
    final subtitleItems = <String>[];
    if (time != null) subtitleItems.add(_formatCallTime(time));
    if (duration > 0) subtitleItems.add('${duration ~/ 60}m ${duration % 60}s');
    subtitleItems.add(callType);

    return FutureBuilder<Map<String, String>>(
      future: _getCallerInfo(otherUserId),
      builder: (context, userSnapshot) {
        final displayName = userSnapshot.data?['name']?.isNotEmpty == true ? userSnapshot.data!['name']! : 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10172E).withValues(alpha: 0.94),
                      const Color(0xFF0C132B).withValues(alpha: 0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: callAccent.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: callAccent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isMissed ? Colors.redAccent.withValues(alpha: 0.18) : callAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: callAccent.withValues(alpha: 0.24)),
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: isMissed ? Colors.redAccent : callAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitleItems.join(' • '),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMissed ? Colors.redAccent.withValues(alpha: 0.12) : callAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMissed ? Colors.redAccent.withValues(alpha: 0.2) : callAccent.withValues(alpha: 0.24)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: isMissed ? Colors.redAccent : callAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: otherUserId == null ? null : () => _openCallScreen(otherUserId, displayName, false),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF142A44),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kNeonGreen.withValues(alpha: 0.24)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.call_rounded, color: kNeonGreen, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Voice',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: otherUserId == null ? null : () => _openCallScreen(otherUserId, displayName, true),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF142A44),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kNeonBlue.withValues(alpha: 0.24)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_rounded, color: kNeonBlue, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Video',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF1D2B6F).withValues(alpha: 0.85), const Color(0xFF0C1534).withValues(alpha: 0.95)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kNeonBlue.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.phone_in_talk_rounded, color: kNeonBlue)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Voice and video calls', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Start a secure call or review recent conversations.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))])),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyCalls() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: kNeonBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.phone_disabled_rounded, size: 40, color: kNeonBlue)),
        const SizedBox(height: 20),
        const Text('No calls yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Start your first secure call and it will appear here instantly.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen())), icon: const Icon(Icons.call, color: Colors.black), label: const Text('Start call'), style: ElevatedButton.styleFrom(backgroundColor: kNeonGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      ]),
    );
  }

  Future<Map<String, String>> _getCallerInfo(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return {'name': 'Unknown'};
    }

    try {
      final response = await SupabaseService.client.from('users').select('name, username').eq('id', userId).maybeSingle();

      if (response is Map<String, dynamic>) {
        final name = response['name'] as String? ?? response['username'] as String?;
        return {'name': name ?? 'Unknown'};
      }
    } catch (_) {}

    return {'name': 'Unknown'};
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatCallTime(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

class _CallsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF050816), Color(0xFF0B1330)]).createShader(rect);
    canvas.drawRect(rect, bg);

    final aurora = Paint()..shader = const RadialGradient(center: Alignment(-0.25, -0.25), radius: 1.1, colors: [Color(0xFF4C6FFF), Color(0xFF1F2A5A), Color(0x00000000)]).createShader(rect);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), size.width * 0.3, aurora);

    final glow = Paint()..shader = const RadialGradient(center: Alignment(0.75, 0.1), radius: 0.8, colors: [Color(0xFFB14EFF), Color(0x00000000)]).createShader(rect);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.12), size.width * 0.24, glow);

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.08 + (i % 6) * 0.16);
      final y = size.height * (0.12 + (i ~/ 6) * 0.22);
      canvas.drawCircle(Offset(x, y), 1.2, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
