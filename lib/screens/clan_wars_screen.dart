import 'package:flutter/material.dart';
import '../services/gaming_profile_service.dart';

const kNeonGreen = Color(0xFF00FF88);
const kNeonBlue = Color(0xFF00D4FF);
const kNeonPurple = Color(0xFFB44FFF);

class ClanWarsScreen extends StatefulWidget {
  static const routeName = '/clan-wars';

  const ClanWarsScreen({super.key});

  @override
  State<ClanWarsScreen> createState() => _ClanWarsScreenState();
}

class _ClanWarsScreenState extends State<ClanWarsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        title: const Text('CLAN WARS', style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kNeonPurple),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActiveWarCard(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonPurple.withOpacity(0.2),
                side: const BorderSide(color: kNeonPurple),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('JOIN A CLAN WAR', style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 24),
            const Text('CLAN LEADERBOARD', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            _buildClanLeaderboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kNeonPurple.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: kNeonPurple.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
        ]
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('ACTIVE WAR ENDS IN 12h 45m', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildClanSide('NEXUS ELITE', 12450, Colors.blueAccent),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + 0.2 * _pulseController.value,
                    child: const Text('VS', style: TextStyle(color: Colors.redAccent, fontSize: 32, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              _buildClanSide('CYBER PUNKS', 10200, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: 12450 / (12450 + 10200),
            backgroundColor: Colors.redAccent.withOpacity(0.3),
            color: Colors.blueAccent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }

  Widget _buildClanSide(String name, int score, Color color) {
    return Column(
      children: [
        CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.2), child: Icon(Icons.shield, color: color, size: 30)),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(score.toString(), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildClanLeaderboard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: GamingProfileService.instance.getClanLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kNeonPurple));
        }
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No clans found', style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final clan = docs[index];
            return ExpansionTile(
              collapsedIconColor: Colors.white54,
              iconColor: kNeonPurple,
              leading: Text('#${index + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
              title: Text(clan['clanName'] ?? 'Unknown Clan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${clan['totalClanXP'] ?? 0} XP', style: const TextStyle(color: kNeonPurple)),
              children: [
                Container(
                  color: Colors.white.withOpacity(0.02),
                  padding: const EdgeInsets.all(16),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('TOP MEMBERS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      SizedBox(height: 8),
                      Text('1. UserA - 5000 XP', style: TextStyle(color: Colors.white)),
                      Text('2. UserB - 4200 XP', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                )
              ],
            );
          },
        );
      }
    );
  }
}
