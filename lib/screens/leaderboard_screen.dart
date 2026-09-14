import 'package:flutter/material.dart';
import '../services/gaming_profile_service.dart';

const kNeonGreen = Color(0xFF00FF88);
const kNeonBlue = Color(0xFF00D4FF);
const kNeonPurple = Color(0xFFB44FFF);

class LeaderboardScreen extends StatefulWidget {
  static const routeName = '/leaderboard';

  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  late AnimationController _podiumController;

  @override
  void initState() {
    super.initState();
    _podiumController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..forward();
  }

  @override
  void dispose() {
    _podiumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A12),
        appBar: AppBar(
          title: const Text('LEADERBOARD', style: TextStyle(color: kNeonBlue, fontWeight: FontWeight.bold, letterSpacing: 2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: kNeonBlue,
            labelColor: kNeonBlue,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'GLOBAL'),
              Tab(text: 'WEEKLY'),
              Tab(text: 'FRIENDS'),
            ],
          ),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('ALL GAMES', true),
                  _buildFilterChip('FPS', false),
                  _buildFilterChip('ACTION', false),
                  _buildFilterChip('BATTLE ROYALE', false),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: GamingProfileService.instance.getLeaderboard(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kNeonBlue));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No entries found', style: TextStyle(color: Colors.white)));
                  }
                  final data = snapshot.data!;
                  final top3 = data.take(3).toList();
                  final rest = data.skip(3).toList();

                  return RefreshIndicator(
                    onRefresh: () async {},
                    color: kNeonBlue,
                    child: ListView(
                      children: [
                        _buildPodium(top3),
                        const SizedBox(height: 16),
                        ...rest.asMap().entries.map((e) => _buildListItem(e.value, e.key + 4)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
        backgroundColor: isSelected ? kNeonBlue : Colors.white10,
        side: BorderSide(color: isSelected ? kNeonBlue : Colors.white24),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _podiumController, curve: Curves.easeOutBack),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (top3.length > 1) _buildPodiumItem(top3[1], 2, 100, Colors.grey.shade400),
            if (top3.isNotEmpty) _buildPodiumItem(top3[0], 1, 140, Colors.amber),
            if (top3.length > 2) _buildPodiumItem(top3[2], 3, 80, const Color(0xFFCD7F32)),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, int rank, double height, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CircleAvatar(radius: rank == 1 ? 30 : 24, backgroundColor: color, child: const Icon(Icons.person, color: Colors.black)),
          const SizedBox(height: 8),
          Text(user['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${user['totalXP'] ?? 0} XP', style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            width: rank == 1 ? 80 : 60,
            height: height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              border: Border(top: BorderSide(color: color, width: 4)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.5), Colors.transparent],
              )
            ),
            child: Center(child: Text('$rank', style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> user, int rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#$rank', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            const CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 16, color: Colors.white)),
          ],
        ),
        title: Text(user['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(user['rank'] ?? 'Rookie', style: TextStyle(color: GamingProfileService.getRankColor(user['rank'] ?? 'Rookie'), fontSize: 12)),
        trailing: Text('${user['totalXP'] ?? 0} XP', style: const TextStyle(color: kNeonBlue, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
