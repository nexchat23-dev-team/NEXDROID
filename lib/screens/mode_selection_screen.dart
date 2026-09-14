import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';
import 'register_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  static const routeName = '/mode-selection';
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  String _selectedMode = 'Developer';
  String _selectedTrack = 'Junior';
  String _selectedLevel = 'Elementary';
  String _selectedTopic = 'Python';

  final Map<String, List<String>> _developerLanguages = {
    'Developer': ['Python', 'Java', 'Dart', 'JavaScript', 'C#', 'Go', 'Ruby', 'Kotlin'],
  };

  final Map<String, List<String>> _ethicalTopics = {
    'Ethical Hacking': [
      'Linux Basics',
      'Networking',
      'Shell Scripting',
      'Privilege Escalation',
      'Web Recon',
      'Forensics',
      'Info Gathering',
      'Cryptography',
    ],
  };

  final Map<String, List<String>> _gamingTopics = {
    'Gaming': [
      'Game Design',
      'FPS Mechanics',
      'Multiplayer Systems',
      'Game Logic',
      'UI/UX',
      'Performance',
      'Storytelling',
      'Esports Strategy',
    ],
  };

  final List<String> _tracks = ['Junior', 'Senior'];
  final List<String> _levels = ['Elementary', 'Basic', 'Advance', 'Expert'];

  @override
  Widget build(BuildContext context) {
    final isDeveloper = _selectedMode == 'Developer';
    final isEthical = _selectedMode == 'Ethical Hacking';
    final isGaming = _selectedMode == 'Gaming';

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: Stack(
        children: [
          const Positioned.fill(child: CyberBackground(
            backgroundColors: [
              Color(0xFF02040A),
              Color(0xFF07111E),
              Color(0xFF0D1730),
              Color(0xFF04050C),
            ],
            leftAuroraColors: [
              Color(0xFF00F0B6),
              Color(0xFF5A50FF),
              Color(0x00000000),
            ],
            rightAuroraColors: [
              Color(0xFFB14BFF),
              Color(0xFF3B82F6),
              Color(0x00000000),
            ],
            fogColor: Color(0x1EFFFFFF),
            leftAuroraCenter: Alignment(-0.23, -0.24),
            rightAuroraCenter: Alignment(0.82, -0.15),
          )),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CHOOSE YOUR PATH', style: TextStyle(color: kNeonBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                  const SizedBox(height: 12),
                  const Text('Pick your mode and challenge yourself.', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Each mode unlocks a unique skill test and a tailored experience for your future profile.', style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 24),
                  _buildModeGrid(),
                  const SizedBox(height: 24),
                  if (isDeveloper) ...[
                    _buildSectionTitle('Developer Track'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _tracks.map((track) => ChoiceChip(
                        label: Text(track),
                        selected: _selectedTrack == track,
                        onSelected: (_) => setState(() => _selectedTrack = track),
                        selectedColor: kNeonGreen,
                        backgroundColor: const Color(0xFF0D1E36),
                        labelStyle: TextStyle(color: _selectedTrack == track ? Colors.black : Colors.white),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Programming Language'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _developerLanguages['Developer']!.map((topic) => ChoiceChip(
                        label: Text(topic),
                        selected: _selectedTopic == topic,
                        onSelected: (_) => setState(() => _selectedTopic = topic),
                        selectedColor: kNeonBlue,
                        backgroundColor: const Color(0xFF0D1E36),
                        labelStyle: TextStyle(color: _selectedTopic == topic ? Colors.black : Colors.white),
                      )).toList(),
                    ),
                  ] else if (isEthical) ...[
                    _buildSectionTitle('Ethical Hacking Topics'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _ethicalTopics['Ethical Hacking']!.map((topic) => ChoiceChip(
                        label: Text(topic),
                        selected: _selectedTopic == topic,
                        onSelected: (_) => setState(() => _selectedTopic = topic),
                        selectedColor: kNeonPurple,
                        backgroundColor: const Color(0xFF0D1E36),
                        labelStyle: TextStyle(color: _selectedTopic == topic ? Colors.black : Colors.white),
                      )).toList(),
                    ),
                  ] else if (isGaming) ...[
                    _buildSectionTitle('Gaming Skill Level'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _levels.map((level) => ChoiceChip(
                        label: Text(level),
                        selected: _selectedLevel == level,
                        onSelected: (_) => setState(() => _selectedLevel = level),
                        selectedColor: kNeonGreen,
                        backgroundColor: const Color(0xFF0D1E36),
                        labelStyle: TextStyle(color: _selectedLevel == level ? Colors.black : Colors.white),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Gaming Topic'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _gamingTopics['Gaming']!.map((topic) => ChoiceChip(
                        label: Text(topic),
                        selected: _selectedTopic == topic,
                        onSelected: (_) => setState(() => _selectedTopic = topic),
                        selectedColor: kNeonBlue,
                        backgroundColor: const Color(0xFF0D1E36),
                        labelStyle: TextStyle(color: _selectedTopic == topic ? Colors.black : Colors.white),
                      )).toList(),
                    ),
                  ] else ...[
                    _buildSectionTitle('Normal Mode Focus'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1E36).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text('You will get a balanced profile with a general skill challenge and access to all core features.', style: TextStyle(color: Colors.white70, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _continueToRegister,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('CONTINUE TO REGISTER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeGrid() {
    final modes = ['Developer', 'Ethical Hacking', 'Gaming', 'Normal'];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: modes.map((mode) {
        final isSelected = _selectedMode == mode;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedMode = mode;
            if (mode != 'Developer') {
              _selectedTrack = 'Junior';
            }
            if (mode != 'Gaming') {
              _selectedLevel = 'Elementary';
            }
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? kNeonBlue.withValues(alpha: 0.2) : const Color(0xFF0D1E36).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isSelected ? kNeonBlue : Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode, style: TextStyle(color: isSelected ? kNeonBlue : Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  mode == 'Developer'
                      ? 'Programming challenge + developer pathway'
                      : mode == 'Ethical Hacking'
                          ? 'Linux and security-based problem solving'
                          : mode == 'Gaming'
                              ? 'Game-focused skill assessment'
                              : 'Balanced general experience',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800));
  }

  void _continueToRegister() {
    Navigator.pushNamed(
      context,
      RegisterScreen.routeName,
      arguments: {
        'selectedMode': _selectedMode,
        'selectedTrack': _selectedTrack,
        'selectedLevel': _selectedLevel,
        'selectedTopic': _selectedTopic,
      },
    );
  }
}
