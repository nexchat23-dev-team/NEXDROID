import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/cyber_background.dart';

class AboutDevelopersScreen extends StatefulWidget {
  static const String routeName = '/about-developers';

  const AboutDevelopersScreen({super.key});

  @override
  State<AboutDevelopersScreen> createState() => _AboutDevelopersScreenState();
}

class _AboutDevelopersScreenState extends State<AboutDevelopersScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    HapticFeedback.selectionClick();
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard!'),
        backgroundColor: const Color(0xFF00E5FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626).withValues(alpha: 0.85),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.transparent),
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'About Developers & NEXO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF00E5FF), size: 20),
            tooltip: 'Share Developer Portal',
            onPressed: () => _copyToClipboard('https://nexo-tech-ltd.vercel.app', 'Official Website URL'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: CyberBackground()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Hero Organization Banner ──────────────────────────────────
                _buildHeroOrganizationCard(),

                const SizedBox(height: 20),

                // ── Core Lead Engineers & Architects ──────────────────────────
                _buildSectionTitle('LEAD ARCHITECTS & CORE ENGINEERS'),
                const SizedBox(height: 12),
                _buildDeveloperCard(
                  name: 'anonyemichael',
                  role: 'Lead Fullstack Architect & Systems Designer',
                  avatarColor: const Color(0xFF00E5FF),
                  icon: Icons.terminal_rounded,
                  bio: 'Creator & Lead Architect of NEXDROID / NEX-APP. Specializes in real-time WebRTC communications, Flutter multiplatform systems, distributed state architecture, and high-performance reactive UI frameworks.',
                  githubUrl: 'https://github.com/anonyemichael',
                  specialties: ['Flutter / Dart', 'WebRTC Architecture', 'Realtime Firebase & RTDB', 'Cloud Architecture'],
                  tag: 'LEAD DEVELOPER',
                ),

                const SizedBox(height: 14),

                _buildDeveloperCard(
                  name: 'alexhack235-code',
                  role: 'Security Kernel & System Audit Engineer',
                  avatarColor: const Color(0xFF00FF88),
                  icon: Icons.security_rounded,
                  bio: 'Lead engineer of the REDOX-PY_SCANNER engine and NEXDROID security infrastructure. Focuses on low-level process scanning, memory hook auditing, port vulnerability detection, and anti-tamper shields.',
                  githubUrl: 'https://github.com/alexhack235-code/REDOX-PY_SCANNER.git',
                  specialties: ['Rust & Python Core', 'Kernel Auditing', 'Anti-Keylogger Sandbox', 'Port Vulnerability Defense'],
                  tag: 'SECURITY ARCHITECT',
                ),

                const SizedBox(height: 20),

                // ── Official Repositories & Portals ───────────────────────────
                _buildSectionTitle('OFFICIAL ECOSYSTEM & REPOSITORIES'),
                const SizedBox(height: 12),
                _buildRepoCard(
                  title: 'NEXO-TECHNOLOGIES Official Repo',
                  desc: 'Main public repository for the NEXO digital ecosystem, tools, and shared multi-module libraries.',
                  url: 'https://github.com/nexchat23-dev-team/NEXO-TECHNOLOGIES.git',
                  color: const Color(0xFFB44FFF),
                  icon: Icons.folder_zip_rounded,
                ),

                const SizedBox(height: 10),

                _buildRepoCard(
                  title: 'REDOX-PY Scanner Security Engine',
                  desc: 'High-speed vulnerability scanner, root exploit detection, and automated threat defense engine.',
                  url: 'https://github.com/alexhack235-code/REDOX-PY_SCANNER.git',
                  color: const Color(0xFF00FF88),
                  icon: Icons.shield_moon_rounded,
                ),

                const SizedBox(height: 10),

                _buildRepoCard(
                  title: 'NEXO Technologies Web Portal',
                  desc: 'Official company portal showcasing next-generation secure communication and digital experiences.',
                  url: 'https://nexo-tech-ltd.vercel.app',
                  color: const Color(0xFF00E5FF),
                  icon: Icons.language_rounded,
                  isWeb: true,
                ),

                const SizedBox(height: 20),

                // ── Technology Stack & Foundation ────────────────────────────
                _buildSectionTitle('TECHNOLOGY STACK & RUNTIME'),
                const SizedBox(height: 12),
                _buildTechStackCard(),

                const SizedBox(height: 20),

                // ── Version & Build Specs ────────────────────────────────────
                _buildSystemSpecsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroOrganizationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF141F3C).withValues(alpha: 0.85),
            const Color(0xFF0A1224).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEXO TECHNOLOGIES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00FF88),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'NEXDROID DIGITAL ARCHITECTURE',
                          style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'The engineering collective behind the NEXDROID Operating Experience — pioneering sovereign encryption, lightning-fast WebRTC communications, gaming ecosystems, and intelligent distributed services.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _launchUrl('https://nexo-tech-ltd.vercel.app'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF0088FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.language_rounded, color: Colors.black, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'OFFICIAL WEBSITE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _launchUrl('https://github.com/nexchat23-dev-team/NEXO-TECHNOLOGIES.git'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'GITHUB PORTAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
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
    );
  }

  Widget _buildDeveloperCard({
    required String name,
    required String role,
    required Color avatarColor,
    required IconData icon,
    required String bio,
    required String githubUrl,
    required List<String> specialties,
    required String tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: avatarColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withValues(alpha: 0.15),
                  border: Border.all(color: avatarColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(icon, color: avatarColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: avatarColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: avatarColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: avatarColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: specialties.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  s,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _launchUrl(githubUrl),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: avatarColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.code_rounded, color: avatarColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'VIEW GITHUB REPOSITORY',
                          style: TextStyle(
                            color: avatarColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                tooltip: 'Copy GitHub Link',
                onPressed: () => _copyToClipboard(githubUrl, '$name GitHub Link'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepoCard({
    required String title,
    required String desc,
    required String url,
    required Color color,
    required IconData icon,
    bool isWeb = false,
  }) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTechStackCard() {
    final tech = [
      {'name': 'Flutter 3.x', 'desc': 'High-FPS Reactive UI', 'icon': Icons.flutter_dash},
      {'name': 'WebRTC', 'desc': 'Ultra Low-Latency P2P Video/Voice', 'icon': Icons.video_call_rounded},
      {'name': 'Rust Kernel', 'desc': 'Memory-Safe Security Scanners', 'icon': Icons.memory_rounded},
      {'name': 'Firebase & RTDB', 'desc': 'Instant Global Signaling', 'icon': Icons.bolt_rounded},
      {'name': 'TensorFlow / MLKit', 'desc': 'On-Device Machine Vision', 'icon': Icons.remove_red_eye_rounded},
      {'name': 'Dart FFI', 'desc': 'Native Platform Integration', 'icon': Icons.terminal_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tech.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
        ),
        itemBuilder: (context, index) {
          final item = tech[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(item['icon'] as IconData, color: const Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['name'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item['desc'] as String,
                        style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemSpecsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1F).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEXDROID OS Version', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text('v3.8.4-PRO QUANTUM', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Build Timestamp', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text('2026.08.25-GLOBAL', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Security Protocol', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text('REDOX-SHIELD v2.4 (Active)', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
