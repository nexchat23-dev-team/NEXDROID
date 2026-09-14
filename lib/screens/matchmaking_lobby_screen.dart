import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/matchmaking_service.dart';

const kNeonGreen = Color(0xFF00FF88);
const kNeonBlue = Color(0xFF00D4FF);
const kNeonPurple = Color(0xFFB44FFF);

class MatchmakingLobbyScreen extends StatefulWidget {
  const MatchmakingLobbyScreen({Key? key}) : super(key: key);

  @override
  State<MatchmakingLobbyScreen> createState() => _MatchmakingLobbyScreenState();
}

class _MatchmakingLobbyScreenState extends State<MatchmakingLobbyScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _bgAnimationController;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  String get _userId => currentUser?.uid ?? 'guest_${Random().nextInt(10000)}';
  String get _username => currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'Player${Random().nextInt(9999)}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _initializePresence();
  }

  Future<void> _initializePresence() async {
    await MatchmakingService.instance.setPresence(_userId, _username, 'ONLINE');
  }

  @override
  void dispose() {
    MatchmakingService.instance.clearPresence(_userId);
    _tabController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  void _showCreateLobbyDialog() {
    String gameName = 'Cyber Arena';
    double maxPlayers = 4;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kNeonBlue, width: 1.5),
          ),
          title: const Text('CREATE LOBBY', style: TextStyle(color: kNeonBlue, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (val) => gameName = val,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Game Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: kNeonBlue.withOpacity(0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: kNeonBlue),
                  ),
                ),
                controller: TextEditingController(text: gameName),
              ),
              const SizedBox(height: 20),
              Text('Max Players: ${maxPlayers.toInt()}', style: const TextStyle(color: Colors.white)),
              Slider(
                value: maxPlayers,
                min: 2,
                max: 10,
                divisions: 8,
                activeColor: kNeonPurple,
                inactiveColor: kNeonPurple.withOpacity(0.3),
                onChanged: (val) => setState(() => maxPlayers = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await MatchmakingService.instance.createLobby(
                  gameName, 
                  _username, 
                  maxPlayers.toInt(),
                  hostId: _userId,
                );
                _showSnackbar('Lobby Created Successfully!', kNeonGreen);
              },
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLobbyDetailsSheet(Map<String, dynamic> lobby) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final players = (lobby['players'] as Map<dynamic, dynamic>?)?.values.toList() ?? [];
        final isFull = players.length >= lobby['maxPlayers'];
        
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050915).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: kNeonBlue.withOpacity(0.5), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lobby['gameName'] ?? 'Unknown Game', style: const TextStyle(color: kNeonBlue, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
              const SizedBox(height: 8),
              Text('Host: ${lobby['hostName']}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('PLAYERS IN LOBBY', style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final p = players[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kNeonBlue.withOpacity(0.2),
                      child: Text(p['username'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: kNeonBlue)),
                    ),
                    title: Text(p['username'], style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFull ? Colors.grey : kNeonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isFull ? null : () async {
                    Navigator.pop(context);
                    await MatchmakingService.instance.joinLobby(lobby['id'], _userId, _username);
                    _showSnackbar('Joined ${lobby['gameName']}', kNeonGreen);
                  },
                  child: Text(isFull ? 'LOBBY FULL' : 'JOIN LOBBY', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void _showPlayerActionDialog(Map<String, dynamic> player) {
    if (player['id'] == _userId) return; // Can't challenge self
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kNeonGreen, width: 1.5),
        ),
        title: Text(player['username'], style: const TextStyle(color: Colors.white)),
        content: const Text('Do you want to send a challenge to this player?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await MatchmakingService.instance.sendChallenge(
                _userId,
                _username,
                player['id'],
                '1v1 Duel',
              );
              _showSnackbar('Challenge sent to ${player['username']}', kNeonBlue);
            },
            child: const Text('CHALLENGE'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color borderColor = kNeonBlue}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050915),
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) => CustomPaint(
                painter: ParticlePainter(progress: _bgAnimationController.value),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: kNeonBlue),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'NEXUS LOBBY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [Shadow(color: kNeonBlue, blurRadius: 10)],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // TabBar
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: MatchmakingService.instance.getIncomingChallenges(_userId),
                  builder: (context, snapshot) {
                    final challenges = snapshot.data ?? [];
                    final hasChallenges = challenges.isNotEmpty;
                    
                    return TabBar(
                      controller: _tabController,
                      indicatorColor: kNeonPurple,
                      labelColor: kNeonPurple,
                      unselectedLabelColor: Colors.white54,
                      dividerColor: Colors.transparent,
                      tabs: [
                        const Tab(text: 'LOBBIES'),
                        const Tab(text: 'ONLINE PLAYERS'),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('CHALLENGES'),
                              if (hasChallenges) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 6)],
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                ),
                
                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLobbiesTab(),
                      _buildOnlinePlayersTab(),
                      _buildChallengesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: kNeonBlue.withOpacity(0.9),
              child: const Icon(Icons.add, color: Colors.black, size: 30),
              onPressed: _showCreateLobbyDialog,
            )
          : null,
    );
  }

  Widget _buildLobbiesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MatchmakingService.instance.getLobbies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonBlue));
        }
        
        final lobbies = snapshot.data ?? [];
        if (lobbies.isEmpty) {
          return const Center(
            child: Text('NO ACTIVE LOBBIES', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lobbies.length,
          itemBuilder: (context, index) {
            final lobby = lobbies[index];
            final playersMap = lobby['players'] as Map<dynamic, dynamic>?;
            final currentPlayers = playersMap?.length ?? 0;
            final maxPlayers = lobby['maxPlayers'] ?? 0;
            final status = lobby['status'] ?? 'UNKNOWN';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => _showLobbyDetailsSheet(lobby),
                child: _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: kNeonPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kNeonPurple, width: 1),
                          ),
                          child: const Icon(Icons.gamepad, color: kNeonPurple),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lobby['gameName'] ?? 'Game', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Host: ${lobby['hostName']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (status == 'WAITING' ? kNeonGreen : Colors.orange).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: status == 'WAITING' ? kNeonGreen : Colors.orange),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: status == 'WAITING' ? kNeonGreen : Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('$currentPlayers/$maxPlayers PLAYERS', style: const TextStyle(color: kNeonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
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
      },
    );
  }

  Widget _buildOnlinePlayersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MatchmakingService.instance.getOnlinePlayers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonGreen));
        }
        
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return const Center(
            child: Text('NO PLAYERS ONLINE', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final isMe = player['id'] == _userId;

            return GestureDetector(
              onTap: () => _showPlayerActionDialog(player),
              child: _buildGlassCard(
                borderColor: kNeonGreen,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: kNeonGreen.withOpacity(0.2),
                          child: Text(
                            player['username'].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: kNeonGreen, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: kNeonGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF050915), width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      player['username'] + (isMe ? ' (You)' : ''),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      player['game']?.toString().isNotEmpty == true ? player['game'] : 'In Menu',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MatchmakingService.instance.getIncomingChallenges(_userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        
        final challenges = snapshot.data ?? [];
        if (challenges.isEmpty) {
          return const Center(
            child: Text('NO PENDING CHALLENGES', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildGlassCard(
                borderColor: kNeonPurple,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flash_on, color: kNeonPurple),
                          const SizedBox(width: 8),
                          Text('CHALLENGE FROM ${challenge['fromUsername']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Game: ${challenge['gameName']}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              onPressed: () async {
                                await MatchmakingService.instance.deleteChallenge(_userId, challenge['id']);
                                _showSnackbar('Challenge declined', Colors.redAccent);
                              },
                              child: const Text('DECLINE'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kNeonPurple,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await MatchmakingService.instance.deleteChallenge(_userId, challenge['id']);
                                _showSnackbar('Challenge Accepted! Preparing game...', kNeonPurple);
                                // Here you would navigate to the game screen
                              },
                              child: const Text('ACCEPT'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double progress;
  ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // fixed seed for consistent particle generation per frame
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < 50; i++) {
      // Create varied starting positions and speeds
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final speedX = (random.nextDouble() - 0.5) * 50;
      final speedY = (random.nextDouble() - 0.5) * 50;
      
      // Calculate current position based on progress (0.0 to 1.0)
      double currentX = (startX + speedX * progress * 10) % size.width;
      double currentY = (startY + speedY * progress * 10) % size.height;
      
      // Handle wrapping
      if (currentX < 0) currentX += size.width;
      if (currentY < 0) currentY += size.height;
      
      // Varied colors and sizes
      final type = random.nextInt(3);
      if (type == 0) paint.color = kNeonBlue.withOpacity(0.3 + random.nextDouble() * 0.4);
      else if (type == 1) paint.color = kNeonGreen.withOpacity(0.3 + random.nextDouble() * 0.4);
      else paint.color = kNeonPurple.withOpacity(0.3 + random.nextDouble() * 0.4);
      
      final radius = 1.0 + random.nextDouble() * 2.5;
      
      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
