import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gaming_profile_service.dart';

const kNeonGreen = Color(0xFF00FF88);
const kNeonBlue = Color(0xFF00D4FF);
const kNeonPurple = Color(0xFFB44FFF);

class GamingProfileScreen extends StatefulWidget {
  static const routeName = '/gaming-profile';

  const GamingProfileScreen({super.key});

  @override
  State<GamingProfileScreen> createState() => _GamingProfileScreenState();
}

class _GamingProfileScreenState extends State<GamingProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'testUser';
  
  final List<Map<String, dynamic>> _allAchievements = [
    {'id': 'first_blood', 'name': 'First Blood', 'icon': Icons.track_changes_rounded},
    {'id': 'kills_100', 'name': '100 Kills', 'icon': Icons.gps_fixed_rounded},
    {'id': 'br_winner', 'name': 'Battle Royale Winner', 'icon': Icons.emoji_events_rounded},
    {'id': 'speed_demon', 'name': 'Speed Demon', 'icon': Icons.bolt_rounded},
    {'id': 'untouchable', 'name': 'Untouchable', 'icon': Icons.shield_rounded},
    {'id': 'kill_streak_10', 'name': 'Kill Streak x10', 'icon': Icons.local_fire_department_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        title: const Text('GAMING PROFILE', style: TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kNeonGreen),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: GamingProfileService.instance.getProfile(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kNeonGreen));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Profile not found', style: TextStyle(color: Colors.white)));
          }
          final data = snapshot.data!;
          final int xp = data['totalXP'] ?? 0;
          final String rank = data['rank'] ?? 'Rookie';
          final Color rankColor = GamingProfileService.getRankColor(rank);
          final int nextXp = GamingProfileService.getXPForNextRank(xp);
          final double progress = xp >= 50000 ? 1.0 : xp / nextXp;
          final List<dynamic> unlockedAchievements = data['achievements'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarSection(data['username'] ?? 'Unknown', rankColor, rank, progress),
                const SizedBox(height: 32),
                _buildStatsGrid(data),
                const SizedBox(height: 32),
                _buildAchievementsSection(unlockedAchievements),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(String username, Color rankColor, String rank, double progress) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: rankColor.withOpacity(0.3 + 0.2 * _animationController.value), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: CircularProgressIndicator(
                    value: progress,
                    color: rankColor,
                    strokeWidth: 6,
                    backgroundColor: Colors.white10,
                  ),
                );
              },
            ),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.black,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(username, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.edit, color: kNeonBlue, size: 20), onPressed: () {}),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rankColor),
          ),
          child: Text(rank.toUpperCase(), style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard('KILLS', data['totalKills']?.toString() ?? '0', kNeonGreen),
        _buildStatCard('DEATHS', data['totalDeaths']?.toString() ?? '0', Colors.redAccent),
        _buildStatCard('K/D', (data['kdRatio'] as double?)?.toStringAsFixed(2) ?? '0.00', kNeonBlue),
        _buildStatCard('WINS', data['totalWins']?.toString() ?? '0', kNeonPurple),
        _buildStatCard('GAMES', data['totalGamesPlayed']?.toString() ?? '0', Colors.orangeAccent),
        _buildStatCard('WIN RATE', '${((data['winRate'] as double?) ?? 0.0 * 100).toStringAsFixed(1)}%', Colors.tealAccent),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(List<dynamic> unlocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ACHIEVEMENTS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _allAchievements.length,
            itemBuilder: (context, index) {
              final ach = _allAchievements[index];
              final isUnlocked = unlocked.contains(ach['id']);
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white.withOpacity(0.1) : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isUnlocked ? kNeonBlue.withOpacity(0.5) : Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ach['icon'] as IconData,
                      size: 24,
                      color: isUnlocked ? kNeonBlue : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ach['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isUnlocked ? Colors.white : Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
