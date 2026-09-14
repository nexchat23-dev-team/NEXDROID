import 'dart:math' as math;
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../widgets/token_purchase_sheet.dart';
import '../services/game_sound_service.dart';

const _kGreen = Color(0xFF00FF88);
const _kBlue = Color(0xFF00D4FF);
const _kPurple = Color(0xFFB44FFF);
const _kOrange = Color(0xFFFF8C00);
const _kRed = Color(0xFFFF3366);
const _kGold = Color(0xFFFFD700);

// ─────────────────────────────────────────────────────────────────────────────
// MAIN LOBBY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NewGamesScreen extends StatelessWidget {
  static const routeName = '/new-games';
  const NewGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenProvider = Provider.of<TokenProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050915),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "NEXDROID VAULT",
          style: TextStyle(
            color: _kBlue,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 18,
            shadows: [Shadow(color: _kBlue, blurRadius: 12)],
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => TokenPurchaseSheet.show(context),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF229ED9).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.6)),
              ),
              child: Row(children: [
                const Icon(Icons.monetization_on, color: _kGold, size: 14),
                const SizedBox(width: 4),
                Text('${tokenProvider.balance}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGameCard(context, "🗡️ Dungeon Crawler",
            "Slash monsters. Survive 5 boss rooms. Earn 150T.",
            [const Color(0xFF7B2FBE), const Color(0xFF3D1066)],
            _kPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DungeonCrawlerGame()))),
          _buildGameCard(context, "🎯 Stealth Sniper",
            "Hold breath. Account for wind. Land the shot. Earn 100T.",
            [const Color(0xFF1A3A1A), const Color(0xFF0A1A0A)],
            _kGreen, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StealthSniperGame()))),
          _buildGameCard(context, "🏰 Tower Defense",
            "Build laser turrets. Survive 5 waves. +25T per wave.",
            [const Color(0xFF1A2A3A), const Color(0xFF0A1520)],
            _kBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TowerDefenseGame()))),
          _buildGameCard(context, "🏎️ Street Racer",
            "Dodge traffic at 200+ km/h. +10T every 100 score.",
            [const Color(0xFF3A1A00), const Color(0xFF1A0800)],
            _kOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StreetRacerGame()))),
          _buildGameCard(context, "💎 Cyber Heist",
            "Infiltrate the vault. Crack 3 safes. Earn 200T.",
            [const Color(0xFF003A3A), const Color(0xFF001A1A)],
            _kBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CyberHeistGame()))),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, String title, String desc, List<Color> gradient, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 18, spreadRadius: -2)],
        ),
        child: Stack(
          children: [
            // Subtle shimmer overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CustomPaint(painter: _ShimmerPainter(accent)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
                child: const Text("PLAY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final Color color;
  _ShimmerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.07), color.withValues(alpha: 0.0)],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME 1: DUNGEON CRAWLER — Detailed RPG Environment
// ─────────────────────────────────────────────────────────────────────────────
class DungeonCrawlerGame extends StatefulWidget {
  const DungeonCrawlerGame({super.key});
  @override State<DungeonCrawlerGame> createState() => _DungeonCrawlerGameState();
}

class _DungeonCrawlerGameState extends State<DungeonCrawlerGame> with TickerProviderStateMixin {
  late AnimationController _gameLoop;
  late AnimationController _pulseCtrl;
  double _playerX = 150, _playerY = 350;
  double _dx = 0, _dy = 0;
  int _hp = 100, _maxHp = 100;
  int _mana = 100, _maxMana = 100;
  int _room = 1, _gold = 0;
  final List<DungeonEnemy> _enemies = [];
  final List<DungeonProjectile> _projectiles = [];
  final List<_Particle> _particles = [];
  bool _gameOver = false, _victory = false, _rewardGiven = false;
  int _tick = 0;
  double _shake = 0;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)
      ..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _spawnEnemies();
  }

  void _spawnEnemies() {
    _enemies.clear();
    int count = _room == 5 ? 1 : _room * 2;
    final rng = Random();
    for (int i = 0; i < count; i++) {
      _enemies.add(DungeonEnemy(
        x: 80.0 + rng.nextDouble() * 200,
        y: 80.0 + rng.nextDouble() * 200,
        hp: _room == 5 ? 600 : 60 + _room * 10,
        maxHp: _room == 5 ? 600 : 60 + _room * 10,
        isBoss: _room == 5,
        type: rng.nextInt(3),
      ));
    }
  }

  void _update() {
    if (_gameOver || _victory) return;
    setState(() {
      _tick++;
      if (_shake > 0) _shake -= 0.3;
      _playerX = (_playerX + _dx * 3.5).clamp(20.0, 340.0);
      _playerY = (_playerY + _dy * 3.5).clamp(20.0, 520.0);

      if (_tick % 8 == 0 && _mana < _maxMana) _mana++;

      for (var e in _enemies) {
        if (e.hp <= 0) continue;
        double dist = sqrt(pow(e.x - _playerX, 2) + pow(e.y - _playerY, 2));
        if (dist < 200) {
          e.x += (_playerX - e.x) * 0.015;
          e.y += (_playerY - e.y) * 0.015;
          if (dist < 28) {
            _hp -= e.isBoss ? 2 : 1;
            _shake = 6.0;
            HapticFeedback.selectionClick();
            _spawnParticles(_playerX, _playerY, _kRed, 3);
            if (_hp <= 0) {
              _gameOver = true;
              HapticFeedback.vibrate();
              GameSoundService().playLose();
            }
          }
        }
        // Enemy attack pattern variance
        if (e.type == 1 && _tick % 120 == 0 && dist < 250) {
          _projectiles.add(DungeonProjectile(e.x, e.y,
            (_playerX - e.x) / dist, (_playerY - e.y) / dist, false, fromEnemy: true));
        }
      }

      for (var p in _projectiles) {
        p.x += p.vx * (p.fromEnemy ? 3.5 : 7);
        p.y += p.vy * (p.fromEnemy ? 3.5 : 7);
        if (p.fromEnemy) {
          double dist = sqrt(pow(p.x - _playerX, 2) + pow(p.y - _playerY, 2));
          if (dist < 20) {
            p.active = false;
            _hp -= 8;
            _shake = 8;
            _spawnParticles(_playerX, _playerY, _kRed, 5);
          }
        } else {
          for (var e in _enemies) {
            if (e.hp > 0 && sqrt(pow(e.x - p.x, 2) + pow(e.y - p.y, 2)) < 26) {
              e.hp -= 45;
              p.active = p.pierce;
              _spawnParticles(e.x, e.y, _kPurple, 6);
              HapticFeedback.lightImpact();
            }
          }
        }
      }
      _projectiles.removeWhere((p) => !p.active || p.x < 0 || p.x > 400 || p.y < 0 || p.y > 650);

      _enemies.removeWhere((e) {
        if (e.hp <= 0) {
          _gold += e.isBoss ? 200 : 20 + _room * 5;
          _spawnParticles(e.x, e.y, _kGold, 12);
          if (e.isBoss) { _victory = true; _grantVictoryReward(150); }
          return true;
        }
        return false;
      });

      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);

      if (_enemies.isEmpty && _room < 5 && _playerY < 60) {
        _room++;
        _playerY = 480;
        _spawnEnemies();
        HapticFeedback.mediumImpact();
        GameSoundService().playCoin();
      }
    });
  }

  void _spawnParticles(double x, double y, Color color, int count) {
    final rng = Random();
    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(x, y,
        (rng.nextDouble() - 0.5) * 6, (rng.nextDouble() - 0.5) * 6,
        color, 18 + rng.nextInt(10)));
    }
  }

  void _grantVictoryReward(int amount) {
    if (_rewardGiven) return;
    _rewardGiven = true;
    Provider.of<TokenProvider>(context, listen: false).addTokens(amount);
    HapticFeedback.heavyImpact();
    GameSoundService().playWin();
  }

  void _attack() {
    if (_gameOver || _victory) return;
    HapticFeedback.lightImpact();
    GameSoundService().playSlash();
    _spawnParticles(_playerX, _playerY, _kGreen, 4);
    for (var e in _enemies) {
      double dist = sqrt(pow(e.x - _playerX, 2) + pow(e.y - _playerY, 2));
      if (dist < 100) { e.hp -= 40; _spawnParticles(e.x, e.y, Colors.orange, 5); }
    }
  }

  void _magic() {
    if (_mana < 20 || _gameOver || _victory) return;
    _mana -= 20;
    HapticFeedback.mediumImpact();
    GameSoundService().playMagic();
    final dir = _dy == 0 && _dx == 0 ? Offset(0, -1) : Offset(_dx, _dy);
    final len = sqrt(dir.dx*dir.dx + dir.dy*dir.dy);
    _projectiles.add(DungeonProjectile(_playerX, _playerY, dir.dx/len, dir.dy/len, true));
    _spawnParticles(_playerX, _playerY, _kBlue, 8);
  }

  @override
  void dispose() { _gameLoop.dispose(); _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0410),
      body: SafeArea(
        child: Column(children: [
          // HUD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F0820), Color(0xFF060310)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.favorite, color: _kRed, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _hp / _maxHp, backgroundColor: Colors.red.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(_kRed), minHeight: 8))),
                  const SizedBox(width: 6),
                  Text('$_hp', style: const TextStyle(color: _kRed, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.auto_awesome, color: _kBlue, size: 14),
                  const SizedBox(width: 4),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _mana / _maxMana, backgroundColor: Colors.blue.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(_kBlue), minHeight: 8))),
                  const SizedBox(width: 6),
                  Text('$_mana', style: const TextStyle(color: _kBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ])),
              const SizedBox(width: 12),
              Column(children: [
                Text('ROOM $_room/5', style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('⚔️ $_gold G', style: const TextStyle(color: _kGold, fontSize: 13, fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          // Game Canvas
          Expanded(
            child: GestureDetector(
              onTapDown: (d) {
                // Tap to move
                setState(() { _playerX = d.localPosition.dx; _playerY = d.localPosition.dy; });
              },
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => CustomPaint(
                  painter: DungeonPainter(_playerX, _playerY, _enemies, _projectiles, _particles, _room, _pulseCtrl.value, _shake),
                  size: const Size(double.infinity, double.infinity),
                ),
              ),
            ),
          ),
          // Status banners
          if (_gameOver)
            Container(
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF300010),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.sentiment_very_dissatisfied, color: _kRed),
                const SizedBox(width: 8),
                const Text("DEFEATED — DARKNESS CLAIMS YOU", style: TextStyle(color: _kRed, fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
            ),
          if (_victory)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF001A08), Color(0xFF003010)])),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.military_tech_rounded, color: _kGold, size: 22),
                const SizedBox(width: 8),
                const Text("BOSS SLAIN! +150 TOKENS!", style: TextStyle(color: _kGold, fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
            ),
          // Controls
          Container(
            height: 150,
            color: const Color(0xFF080310),
            child: Row(children: [
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _dBtn(Icons.north_rounded, 0, -1),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _dBtn(Icons.west_rounded, -1, 0),
                      const SizedBox(width: 40),
                      _dBtn(Icons.east_rounded, 1, 0),
                    ]),
                    _dBtn(Icons.south_rounded, 0, 1),
                  ]),
                ),
              ),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _actionBtn("SLASH", _kRed, Icons.flash_on_rounded, _attack),
                    const SizedBox(width: 12),
                    _actionBtn("SPELL", _kPurple, Icons.auto_awesome_rounded, _magic),
                  ]),
                  if (_room < 5) ...[
                    const SizedBox(height: 6),
                    Text("Walk to top edge → advance room", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
                  ],
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dBtn(IconData icon, double dx, double dy) {
    return GestureDetector(
      onPanDown: (_) => setState(() { _dx = dx; _dy = dy; }),
      onPanEnd: (_) => setState(() { _dx = 0; _dy = 0; }),
      onTapDown: (_) => setState(() { _dx = dx; _dy = dy; }),
      onTapUp: (_) => setState(() { _dx = 0; _dy = 0; }),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10)],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
        ]),
      ),
    );
  }
}

class DungeonEnemy {
  double x, y;
  int hp, maxHp;
  bool isBoss;
  int type;
  DungeonEnemy({required this.x, required this.y, required this.hp, required this.maxHp, this.isBoss = false, this.type = 0});
}

class DungeonProjectile {
  double x, y, vx, vy;
  bool pierce, active = true;
  bool fromEnemy;
  DungeonProjectile(this.x, this.y, this.vx, this.vy, this.pierce, {this.fromEnemy = false});
}

class _Particle {
  double x, y, vx, vy;
  Color color;
  int life, maxLife;
  _Particle(this.x, this.y, this.vx, this.vy, this.color, this.life) : maxLife = life;
  void update() { x += vx; y += vy; vx *= 0.92; vy *= 0.92; life--; }
}

class DungeonPainter extends CustomPainter {
  final double px, py;
  final List<DungeonEnemy> enemies;
  final List<DungeonProjectile> projectiles;
  final List<_Particle> particles;
  final int room;
  final double pulse, shake;

  DungeonPainter(this.px, this.py, this.enemies, this.projectiles, this.particles, this.room, this.pulse, this.shake);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final w = size.width;
    final h = size.height;

    canvas.save();
    if (shake > 0) canvas.translate((rng.nextDouble() - 0.5) * shake, (rng.nextDouble() - 0.5) * shake);

    // ── Floor ──
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A0A2E), Color(0xFF0F0620), Color(0xFF1A0A2E)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), floorPaint);

    // Floor tiles
    final tilePaint = Paint()..color = const Color(0xFF22103A)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (double x = 0; x < w; x += 36) {
      for (double y = 0; y < h; y += 36) {
        canvas.drawRect(Rect.fromLTWH(x, y, 36, 36), tilePaint);
      }
    }

    // Stone wall texture top
    final wallPaint = Paint()..color = const Color(0xFF2A1840);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 18), wallPaint);
    // Wall bricks
    final brickPaint = Paint()..color = const Color(0xFF3D2A55)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    for (int i = 0; i < 15; i++) {
      canvas.drawRect(Rect.fromLTWH(i * 26.0 - (i.isEven ? 0 : 13), 2, 25, 14), brickPaint);
    }

    // Door at top if room < 5
    if (room < 5) {
      final doorGlow = Paint()..shader = RadialGradient(
        colors: [_kGreen.withValues(alpha: 0.5 + 0.3 * pulse), _kGreen.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, 9), radius: 40));
      canvas.drawCircle(Offset(w / 2, 9), 40, doorGlow);
      final doorPaint = Paint()..color = const Color(0xFF1A4A1A);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w/2 - 22, 0, 44, 20), const Radius.circular(4)), doorPaint);
      final doorBorderPaint = Paint()..color = _kGreen.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w/2 - 22, 0, 44, 20), const Radius.circular(4)), doorBorderPaint);
    }

    // Torch effects
    for (int i = 0; i < 3; i++) {
      double tx = 40.0 + i * (w - 80) / 2;
      final torchGlow = Paint()..shader = RadialGradient(
        colors: [Colors.orange.withValues(alpha: 0.25 + 0.1 * pulse), Colors.orange.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(tx, 30), radius: 50));
      canvas.drawCircle(Offset(tx, 30), 50, torchGlow);
      final flameP = Paint()..color = Colors.orange;
      canvas.drawCircle(Offset(tx, 22), 5, flameP);
      flameP.color = Colors.amber;
      canvas.drawCircle(Offset(tx, 25), 3, flameP);
    }

    // ── Player ──
    _drawPlayer(canvas, px, py, pulse);

    // ── Enemies ──
    for (var e in enemies) {
      if (e.hp <= 0) continue;
      _drawEnemy(canvas, e, pulse);
    }

    // ── Projectiles ──
    for (var p in projectiles) {
      final projPaint = Paint()
        ..color = p.fromEnemy ? _kRed : _kBlue
        ..shader = RadialGradient(
          colors: [p.fromEnemy ? Colors.red : _kBlue, (p.fromEnemy ? _kRed : _kPurple).withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(p.x, p.y), radius: 14));
      canvas.drawCircle(Offset(p.x, p.y), p.pierce ? 8 : 5, projPaint);
    }

    // ── Particles ──
    for (var p in particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final pp = Paint()..color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.x, p.y), 3 * alpha, pp);
    }

    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, double x, double y, double pulse) {
    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 18), width: 28, height: 8),
      Paint()..color = Colors.black38);
    // Body glow
    canvas.drawCircle(Offset(x, y), 20, Paint()..shader = RadialGradient(
      colors: [_kGreen.withValues(alpha: 0.25 + 0.1 * pulse), _kGreen.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 20)));
    // Armor body
    final bodyPaint = Paint()..color = const Color(0xFF2A5A3A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 4), width: 22, height: 28), const Radius.circular(4)), bodyPaint);
    // Head
    canvas.drawCircle(Offset(x, y - 12), 10, Paint()..color = const Color(0xFFE8C4A0));
    // Helmet
    final helmetPaint = Paint()..color = const Color(0xFF1A6A3A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 11, y - 24, 22, 14), const Radius.circular(5)), helmetPaint);
    // Eyes
    canvas.drawCircle(Offset(x - 3, y - 13), 2, Paint()..color = _kGreen);
    canvas.drawCircle(Offset(x + 3, y - 13), 2, Paint()..color = _kGreen);
    // Sword
    final swordPaint = Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x + 14, y - 6), Offset(x + 14, y + 14), swordPaint);
    canvas.drawLine(Offset(x + 10, y + 4), Offset(x + 18, y + 4), swordPaint); // Guard
  }

  void _drawEnemy(Canvas canvas, DungeonEnemy e, double pulse) {
    final isBoss = e.isBoss;
    final Color mainColor = isBoss ? _kPurple : (e.type == 0 ? _kRed : (e.type == 1 ? Colors.orange : Colors.deepPurple));
    final r = isBoss ? 26.0 : 16.0;

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(e.x, e.y + r + 4), width: r * 2.4, height: 7),
      Paint()..color = Colors.black45);

    // Glow
    canvas.drawCircle(Offset(e.x, e.y), r + 10, Paint()..shader = RadialGradient(
      colors: [mainColor.withValues(alpha: 0.3 + 0.15 * pulse), mainColor.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: Offset(e.x, e.y), radius: r + 10)));

    // Body
    if (isBoss) {
      // Boss: Demonic horned creature
      canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = const Color(0xFF3A0055));
      canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = mainColor..style = PaintingStyle.stroke..strokeWidth = 2.5);
      // Horns
      final hornPaint = Paint()..color = Colors.orange..style = PaintingStyle.fill;
      final horn1 = Path()..moveTo(e.x - 8, e.y - r)..lineTo(e.x - 18, e.y - r - 16)..lineTo(e.x - 4, e.y - r + 4)..close();
      final horn2 = Path()..moveTo(e.x + 8, e.y - r)..lineTo(e.x + 18, e.y - r - 16)..lineTo(e.x + 4, e.y - r + 4)..close();
      canvas.drawPath(horn1, hornPaint);
      canvas.drawPath(horn2, hornPaint);
      // Eyes glowing
      canvas.drawCircle(Offset(e.x - 8, e.y - 4), 5, Paint()..color = _kRed);
      canvas.drawCircle(Offset(e.x + 8, e.y - 4), 5, Paint()..color = _kRed);
      canvas.drawCircle(Offset(e.x - 8, e.y - 4), 2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(e.x + 8, e.y - 4), 2, Paint()..color = Colors.white);
    } else {
      // Regular enemy body
      canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = mainColor.withValues(alpha: 0.4));
      canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = mainColor..style = PaintingStyle.stroke..strokeWidth = 2);
      // Skull face
      canvas.drawCircle(Offset(e.x, e.y - 2), r * 0.65, Paint()..color = const Color(0xFFD0D0D0));
      canvas.drawOval(Rect.fromCenter(center: Offset(e.x - 4, e.y - 2), width: 5, height: 7), Paint()..color = const Color(0xFF333333));
      canvas.drawOval(Rect.fromCenter(center: Offset(e.x + 4, e.y - 2), width: 5, height: 7), Paint()..color = const Color(0xFF333333));
    }

    // HP Bar
    double hpRatio = (e.hp / e.maxHp).clamp(0.0, 1.0);
    double barW = isBoss ? 52.0 : 34.0;
    final bgBar = Paint()..color = Colors.black54;
    final fgBar = Paint()..color = hpRatio > 0.5 ? _kGreen : (hpRatio > 0.25 ? Colors.orange : _kRed);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - barW/2, e.y - r - 10, barW, 5), const Radius.circular(2)), bgBar);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - barW/2, e.y - r - 10, barW * hpRatio, 5), const Radius.circular(2)), fgBar);
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME 2: STEALTH SNIPER — Photorealistic outdoor scene
// ─────────────────────────────────────────────────────────────────────────────
class StealthSniperGame extends StatefulWidget {
  const StealthSniperGame({super.key});
  @override State<StealthSniperGame> createState() => _StealthSniperGameState();
}

class _StealthSniperGameState extends State<StealthSniperGame> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _scoped = false;
  double _aimX = 180, _aimY = 220;
  double _wind = 1.4, _windDir = 1;
  int _score = 0, _shots = 0, _kills = 0;
  int _breath = 100;
  bool _holdingBreath = false;
  final List<SniperTarget> _targets = [];
  bool _gameOver = false, _rewardGiven = false;
  final List<_BulletTrace> _traces = [];
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)..repeat();
    final rng = Random();
    for (int i = 0; i < 5; i++) {
      _targets.add(SniperTarget(50.0 + rng.nextDouble() * 260, 140.0 + i * 55.0));
    }
  }

  void _update() {
    if (_gameOver) return;
    setState(() {
      // Sway
      if (_holdingBreath) {
        _breath = (_breath - 1).clamp(0, 100);
        if (_breath <= 0) _holdingBreath = false;
      } else {
        if (_breath < 100) _breath++;
        final t = DateTime.now().millisecondsSinceEpoch / 220.0;
        final sway = _holdingBreath ? 0.0 : (1.0 - _breath / 100.0) * 1.8 + 0.4;
        if (!_scoped) {
          _aimX += sin(t) * sway;
          _aimY += cos(t * 1.3) * sway;
        }
      }
      // Wind changes
      _wind += (Random().nextDouble() - 0.5) * 0.02;
      _wind = _wind.clamp(0.5, 3.0);

      // Targets walk
      for (var t in _targets) {
        if (!t.alive) continue;
        t.x += t.dir * (1.5 + t.speed);
        if (t.x < 30 || t.x > 330) t.dir *= -1;
      }

      // Traces decay
      for (var tr in _traces) { tr.life--; }
      _traces.removeWhere((tr) => tr.life <= 0);

      // Particles
      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);

      if (_targets.where((t) => t.alive).isEmpty && !_gameOver) {
        _gameOver = true;
        _grantReward();
      }
    });
  }

  void _grantReward() {
    if (_rewardGiven) return;
    _rewardGiven = true;
    Provider.of<TokenProvider>(context, listen: false).addTokens(100);
    HapticFeedback.heavyImpact();
    GameSoundService().playWin();
  }

  void _shoot() {
    if (!_scoped) return;
    _shots++;
    HapticFeedback.heavyImpact();
    GameSoundService().playSniper();

    // Wind drift
    double hitX = _aimX + (_wind * _windDir * 12);
    double hitY = _aimY;
    _traces.add(_BulletTrace(_aimX, _aimY, hitX, hitY, 30));

    for (var t in _targets) {
      if (!t.alive) continue;
      if ((hitX - t.x).abs() < 24 && (hitY - t.y).abs() < 36) {
        final isHead = (hitY - t.y + 28).abs() < 14;
        t.alive = false;
        _kills++;
        _score += isHead ? 300 : 100;
        _spawnParticles(t.x, t.y, _kRed, isHead ? 14 : 7);
        HapticFeedback.mediumImpact();
        GameSoundService().playCoin();
        if (isHead) GameSoundService().playExplosion();
      }
    }
  }

  void _spawnParticles(double x, double y, Color c, int n) {
    final rng = Random();
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(x, y, (rng.nextDouble()-0.5)*5, (rng.nextDouble()-0.5)*5, c, 20+rng.nextInt(12)));
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Scene
        Positioned.fill(
          child: GestureDetector(
            onPanUpdate: (d) {
              if (_scoped) setState(() { _aimX = (_aimX + d.delta.dx).clamp(0, 360); _aimY = (_aimY + d.delta.dy).clamp(0, 650); });
            },
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: SniperPainter(_targets, _scoped, _aimX, _aimY, _wind, _traces, _particles, _breath),
              ),
            ),
          ),
        ),
        // HUD overlay
        SafeArea(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55)),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
                const Text("STEALTH SNIPER", style: TextStyle(color: _kGreen, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text("SCORE: $_score", style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("KILLS: $_kills  SHOTS: $_shots", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ]),
            ),
            // Wind indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                const Icon(Icons.air, color: _kBlue, size: 14),
                const SizedBox(width: 4),
                Text("WIND ${_wind.toStringAsFixed(1)} m/s →", style: const TextStyle(color: _kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.thermostat_auto_rounded, color: Colors.orange, size: 14),
                Text(" ${_kills} eliminated, ${_targets.where((t) => t.alive).length} remaining", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ]),
        ),
        // Breath bar
        Positioned(
          bottom: 100,
          left: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("BREATH", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 3),
            Container(
              width: 100, height: 8,
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _breath / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: _breath > 50 ? _kBlue : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ]),
        ),
        // Buttons
        Positioned(
          bottom: 20,
          left: 16,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _holdingBreath = true),
            onTapUp: (_) => setState(() => _holdingBreath = false),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _holdingBreath ? _kPurple.withValues(alpha: 0.8) : Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _holdingBreath ? _kPurple : Colors.white24),
              ),
              child: Column(children: [
                const Icon(Icons.air, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                const Text("HOLD\nBREATH", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 80,
          child: GestureDetector(
            onTap: () => setState(() => _scoped = !_scoped),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _scoped ? _kBlue.withValues(alpha: 0.7) : Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _scoped ? _kBlue : Colors.white24),
              ),
              child: Column(children: [
                Icon(Icons.gps_fixed, color: _scoped ? Colors.black : Colors.white, size: 22),
                const SizedBox(height: 2),
                Text(_scoped ? "ZOOM\nACTIVE" : "SCOPE\nIN", textAlign: TextAlign.center, style: TextStyle(color: _scoped ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: GestureDetector(
            onTap: _shoot,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _scoped ? _kRed : Colors.black38,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _scoped ? _kRed : Colors.white12, width: 2),
                boxShadow: _scoped ? [BoxShadow(color: _kRed.withValues(alpha: 0.5), blurRadius: 16)] : [],
              ),
              child: const Icon(Icons.adjust, color: Colors.white, size: 28),
            ),
          ),
        ),
        if (_gameOver)
          Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGold, width: 2),
                boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("🎯 MISSION COMPLETE", style: TextStyle(color: _kGold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text("Score: $_score  |  Kills: $_kills/${ _targets.length}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                const Text("+100 TOKENS EARNED", style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class SniperTarget {
  double x, y;
  double speed;
  int dir;
  bool alive;
  SniperTarget(this.x, this.y) : dir = Random().nextBool() ? 1 : -1, speed = Random().nextDouble() * 0.8, alive = true;
}

class _BulletTrace {
  double x1, y1, x2, y2;
  int life;
  _BulletTrace(this.x1, this.y1, this.x2, this.y2, this.life);
}

class SniperPainter extends CustomPainter {
  final List<SniperTarget> targets;
  final bool scoped;
  final double aimX, aimY, wind;
  final List<_BulletTrace> traces;
  final List<_Particle> particles;
  final int breath;

  SniperPainter(this.targets, this.scoped, this.aimX, this.aimY, this.wind, this.traces, this.particles, this.breath);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Sky gradient ──
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = const LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF1A2A4A), Color(0xFF2A3A6A)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // ── Stars in sky ──
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final rng = Random(12345);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * (h * 0.45)), rng.nextDouble() * 1.2 + 0.3, starPaint);
    }

    // ── Moon ──
    canvas.drawCircle(Offset(w * 0.82, h * 0.12), 22, Paint()..color = const Color(0xFFF5E6C8));
    canvas.drawCircle(Offset(w * 0.82 + 6, h * 0.12 - 4), 17, Paint()..color = const Color(0xFF1A2A4A));

    // ── Distant mountains ──
    final mtnPaint = Paint()..color = const Color(0xFF0A1A2A);
    final mtnPath = Path();
    mtnPath.moveTo(0, h * 0.55);
    mtnPath.lineTo(w * 0.15, h * 0.3);
    mtnPath.lineTo(w * 0.28, h * 0.45);
    mtnPath.lineTo(w * 0.45, h * 0.22);
    mtnPath.lineTo(w * 0.6, h * 0.38);
    mtnPath.lineTo(w * 0.75, h * 0.28);
    mtnPath.lineTo(w, h * 0.42);
    mtnPath.lineTo(w, h * 0.55);
    mtnPath.close();
    canvas.drawPath(mtnPath, mtnPaint);

    // ── Buildings (sniper scene backdrop) ──
    final bldPaint = Paint()..color = const Color(0xFF0D1825);
    _drawBuilding(canvas, bldPaint, 30, h * 0.5, 70, h * 0.5);
    _drawBuilding(canvas, bldPaint, 160, h * 0.45, 80, h * 0.55);
    _drawBuilding(canvas, bldPaint, 260, h * 0.48, 90, h * 0.52);
    // Windows
    final winPaint = Paint()..color = Colors.amber.withValues(alpha: 0.5);
    final rng2 = Random(99);
    for (int i = 0; i < 30; i++) {
      if (rng2.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(
          30 + rng2.nextDouble() * (w - 60),
          h * 0.5 + rng2.nextDouble() * (h * 0.3),
          6, 9), winPaint);
      }
    }

    // ── Ground / street ──
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
      Paint()..color = const Color(0xFF0A1008));
    // Road markings
    final roadPaint = Paint()..color = const Color(0xFF1A3A10);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), roadPaint);
    final linePaint = Paint()..color = Colors.white.withValues(alpha: 0.15)..strokeWidth = 2;
    for (double x = 0; x < w; x += 40) {
      canvas.drawLine(Offset(x, h * 0.84), Offset(x + 20, h * 0.84), linePaint);
    }

    // ── Targets ──
    for (var t in targets) {
      if (!t.alive) continue;
      _drawHumanTarget(canvas, t.x, t.y, size);
    }

    // ── Bullet traces ──
    for (var tr in traces) {
      final alpha = (tr.life / 30.0).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(tr.x1, tr.y1), Offset(tr.x2, tr.y2),
        Paint()..color = Colors.yellow.withValues(alpha: alpha * 0.8)..strokeWidth = 1.5);
    }

    // ── Particles ──
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 3 * (p.life / p.maxLife), Paint()..color = p.color.withValues(alpha: p.life / p.maxLife));
    }

    // ── Scope overlay ──
    if (scoped) {
      final scopeRadius = 140.0;
      // Dark vignette
      final vigPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, w, h))
        ..addOval(Rect.fromCircle(center: Offset(aimX, aimY), radius: scopeRadius));
      vigPath.fillType = PathFillType.evenOdd;
      canvas.drawPath(vigPath, Paint()..color = Colors.black.withValues(alpha: 0.92));

      // Scope lens tint
      canvas.drawCircle(Offset(aimX, aimY), scopeRadius, Paint()..color = const Color(0xFF001A00).withValues(alpha: 0.3));

      // Scope border with glass effect
      canvas.drawCircle(Offset(aimX, aimY), scopeRadius,
        Paint()..color = const Color(0xFF3A5A3A).withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 8);
      canvas.drawCircle(Offset(aimX, aimY), scopeRadius,
        Paint()..color = _kGreen.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 2);

      // Crosshair
      final chPaint = Paint()..color = _kGreen..strokeWidth = 1.2;
      // Main crosshair lines
      canvas.drawLine(Offset(aimX - scopeRadius + 20, aimY), Offset(aimX - 20, aimY), chPaint);
      canvas.drawLine(Offset(aimX + 20, aimY), Offset(aimX + scopeRadius - 20, aimY), chPaint);
      canvas.drawLine(Offset(aimX, aimY - scopeRadius + 20), Offset(aimX, aimY - 20), chPaint);
      canvas.drawLine(Offset(aimX, aimY + 20), Offset(aimX, aimY + scopeRadius - 20), chPaint);
      // Center dot
      canvas.drawCircle(Offset(aimX, aimY), 3, Paint()..color = _kGreen);
      // Rangefinder ticks
      final tickPaint = Paint()..color = _kGreen.withValues(alpha: 0.5)..strokeWidth = 0.8;
      for (int i = -4; i <= 4; i++) {
        if (i == 0) continue;
        double ty = aimY + i * 20;
        canvas.drawLine(Offset(aimX - 8, ty), Offset(aimX + 8, ty), tickPaint);
      }
      // Wind drift indicator
      double driftX = aimX + wind * 12;
      canvas.drawCircle(Offset(driftX, aimY), 4, Paint()..color = _kRed.withValues(alpha: 0.85));
      canvas.drawLine(Offset(aimX, aimY), Offset(driftX, aimY), Paint()..color = _kRed.withValues(alpha: 0.5)..strokeWidth = 1..style = PaintingStyle.stroke);

      // Breath stability indicator (edges blur when not holding)
      if (breath < 80) {
        canvas.drawCircle(Offset(aimX, aimY), scopeRadius - 5, Paint()
          ..color = Colors.orange.withValues(alpha: (1 - breath / 80) * 0.2)
          ..style = PaintingStyle.stroke..strokeWidth = 4);
      }
    }
  }

  void _drawBuilding(Canvas canvas, Paint paint, double x, double yStart, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x, yStart, w, h), paint);
    // Rooftop detail
    canvas.drawRect(Rect.fromLTWH(x + w/2 - 3, yStart - 15, 6, 15), Paint()..color = const Color(0xFF0F2035));
  }

  void _drawHumanTarget(Canvas canvas, double x, double y, Size size) {
    // Scale target to appear in scene
    const scale = 1.0;
    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 28 * scale), width: 24 * scale, height: 6 * scale), Paint()..color = Colors.black54);
    // Legs
    final legPaint = Paint()..color = const Color(0xFF2A3A1A);
    canvas.drawRect(Rect.fromLTWH(x - 8 * scale, y + 8 * scale, 7 * scale, 22 * scale), legPaint);
    canvas.drawRect(Rect.fromLTWH(x + 1 * scale, y + 8 * scale, 7 * scale, 22 * scale), legPaint);
    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 10 * scale, y - 12 * scale, 20 * scale, 22 * scale),
      const Radius.circular(3)), Paint()..color = const Color(0xFF2A4A1A));
    // Arms
    canvas.drawRect(Rect.fromLTWH(x - 18 * scale, y - 10 * scale, 8 * scale, 14 * scale), legPaint);
    canvas.drawRect(Rect.fromLTWH(x + 10 * scale, y - 10 * scale, 8 * scale, 14 * scale), legPaint);
    // Head (target area)
    canvas.drawCircle(Offset(x, y - 22 * scale), 10 * scale, Paint()..color = const Color(0xFFD4A880));
    // Helmet
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 11 * scale, y - 34 * scale, 22 * scale, 14 * scale),
      const Radius.circular(11)), Paint()..color = const Color(0xFF1A3A0A));
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME 3: TOWER DEFENSE — Cyber Grid battlefield
// ─────────────────────────────────────────────────────────────────────────────
class TowerDefenseGame extends StatefulWidget {
  const TowerDefenseGame({super.key});
  @override State<TowerDefenseGame> createState() => _TowerDefenseGameState();
}

class _TowerDefenseGameState extends State<TowerDefenseGame> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  int _gold = 200, _lives = 20, _wave = 1, _score = 0;
  final List<TDTower> _towers = [];
  final List<TDEnemy> _enemies = [];
  final List<TDProj> _projs = [];
  final List<_Particle> _particles = [];
  bool _gameOver = false, _waveClear = false;
  int _tick = 0;
  int _enemiesSpawned = 0;
  

  // Path waypoints
  static const List<Offset> _path = [
    Offset(-30, 110), Offset(80, 110), Offset(80, 260), Offset(220, 260), Offset(220, 120), Offset(400, 120),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)..repeat();
  }

  void _update() {
    if (_gameOver) return;
    setState(() {
      _tick++;
      // Spawn enemies on a schedule
      int maxForWave = _wave * 6;
      if (_tick % 55 == 0 && _enemiesSpawned < maxForWave) {
        _enemies.add(TDEnemy(hp: 80 * _wave, maxHp: 80 * _wave, type: _enemiesSpawned % 3, wave: _wave));
        _enemiesSpawned++;
      }

      // Move enemies along path
      for (var e in _enemies) {
        if (e.hp <= 0) continue;
        _moveAlongPath(e);
        if (e.reachedEnd) {
          e.hp = 0;
          _lives--;
          if (_lives <= 0) { _gameOver = true; GameSoundService().playLose(); }
        }
      }

      // Towers shoot
      for (var t in _towers) {
        t.cd = (t.cd - 1).clamp(0, 9999);
        if (t.cd <= 0) {
          for (var e in _enemies) {
            if (e.hp <= 0) continue;
            double dist = sqrt(pow(e.x - t.x, 2) + pow(e.y - t.y, 2));
            if (dist < t.range) {
              _projs.add(TDProj(t.x, t.y, e, t.dmg, t.type));
              t.cd = t.fireRate;
              GameSoundService().playLaser();
              break;
            }
          }
        }
      }

      // Move projectiles
      for (var p in _projs) {
        if (!p.active || p.target.hp <= 0) { p.active = false; continue; }
        double dx = p.target.x - p.x, dy = p.target.y - p.y;
        double len = sqrt(dx*dx + dy*dy);
        p.x += (dx/len) * 12;
        p.y += (dy/len) * 12;
        if (len < 14) {
          p.target.hp -= p.dmg;
          p.active = false;
          _spawnParticles(p.x, p.y, p.type == 0 ? _kBlue : (p.type == 1 ? _kGreen : _kPurple), 4);
          if (p.target.hp <= 0) {
            _gold += 15 + _wave * 5;
            _score += 10 * _wave;
            _spawnParticles(p.target.x, p.target.y, _kGold, 8);
          }
        }
      }
      _projs.removeWhere((p) => !p.active);
      _enemies.removeWhere((e) => e.hp <= 0);

      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);

      // Wave completion
      if (_enemies.isEmpty && _enemiesSpawned >= _wave * 6 && !_waveClear) {
        _waveClear = true;
        _gold += 50;
        _score += 100 * _wave;
        final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
        tokenProvider.addTokens(25);
        GameSoundService().playWin();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() { _wave++; _enemiesSpawned = 0; _tick = 0; _waveClear = false; });
        });
      }
    });
  }

  void _moveAlongPath(TDEnemy e) {
    if (e.waypointIdx >= _path.length) { e.reachedEnd = true; return; }
    final target = _path[e.waypointIdx];
    double dx = target.dx - e.x, dy = target.dy - e.y;
    double len = sqrt(dx*dx + dy*dy);
    double spd = 1.2 + (_wave - 1) * 0.2;
    if (len < spd) {
      e.x = target.dx; e.y = target.dy;
      e.waypointIdx++;
    } else {
      e.x += (dx/len) * spd;
      e.y += (dy/len) * spd;
    }
  }

  void _spawnParticles(double x, double y, Color c, int n) {
    final rng = Random();
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(x, y, (rng.nextDouble()-0.5)*4, (rng.nextDouble()-0.5)*4, c, 16+rng.nextInt(8)));
    }
  }

  void _place(double x, double y) {
    if (_gold < 50 || _gameOver) return;
    // Don't place on path
    for (final wp in _path) {
      if ((wp.dx - x).abs() < 30 && (wp.dy - y).abs() < 30) return;
    }
    setState(() {
      _gold -= 50;
      final type = _towers.length % 3;
      _towers.add(TDTower(x, y, type: type));
    });
    HapticFeedback.lightImpact();
    GameSoundService().playTick();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020C14),
      body: SafeArea(
        child: Column(children: [
          // HUD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF06141E),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
              const Text("TOWER DEFENSE", style: TextStyle(color: _kBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
              const Spacer(),
              _hudChip(Icons.favorite, '$_lives', _kRed),
              const SizedBox(width: 8),
              _hudChip(Icons.monetization_on, '$_gold', _kGold),
              const SizedBox(width: 8),
              _hudChip(Icons.waves_rounded, 'W$_wave', _kBlue),
            ]),
          ),
          // Game map
          Expanded(
            child: GestureDetector(
              onTapDown: (d) => _place(d.localPosition.dx, d.localPosition.dy),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: TDPainter(_towers, _enemies, _projs, _particles, _path, _tick, _wave),
                  size: const Size(double.infinity, double.infinity),
                ),
              ),
            ),
          ),
          // Build bar
          Container(
            color: const Color(0xFF06141E),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              if (_waveClear)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text("✅ WAVE $_wave CLEARED! +25T +\$50G  Next wave incoming...",
                    style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              if (_gameOver)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Text("⚠️ CORE BREACHED — DEFEAT", style: TextStyle(color: _kRed, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _towerInfo("⚡ Laser", "50G", _kBlue),
                _towerInfo("🔥 Flame", "50G", _kOrange),
                _towerInfo("💜 Arc", "50G", _kPurple),
                Column(children: [
                  Text("SCORE", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  Text('$_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
              ]),
              const SizedBox(height: 4),
              Text("TAP EMPTY AREA TO BUILD  •  COST: 50G",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, letterSpacing: 0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _hudChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _towerInfo(String name, String cost, Color color) {
    return Column(children: [
      Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      Text(cost, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]);
  }
}

class TDTower {
  double x, y, range;
  int dmg, fireRate, cd, type;
  TDTower(this.x, this.y, {this.type = 0})
      : range = 100.0 + type * 10,
        dmg = 25 + type * 5,
        fireRate = 30 - type * 5,
        cd = 0;
}

class TDEnemy {
  double x, y;
  int hp, maxHp, type, waypointIdx, wave;
  bool reachedEnd;
  TDEnemy({required this.hp, required this.maxHp, required this.type, required this.wave})
      : x = -30, y = 110, waypointIdx = 0, reachedEnd = false;
}

class TDProj {
  double x, y;
  TDEnemy target;
  int dmg, type;
  bool active;
  TDProj(this.x, this.y, this.target, this.dmg, this.type) : active = true;
}

class TDPainter extends CustomPainter {
  final List<TDTower> towers;
  final List<TDEnemy> enemies;
  final List<TDProj> projs;
  final List<_Particle> particles;
  final List<Offset> path;
  final int tick, wave;

  TDPainter(this.towers, this.enemies, this.projs, this.particles, this.path, this.tick, this.wave);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background: Dark cyber grid ──
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF030E18));
    // Grid lines
    final gridPaint = Paint()..color = const Color(0xFF0A2030)..strokeWidth = 1;
    for (double x = 0; x < w; x += 32) canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    for (double y = 0; y < h; y += 32) canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);

    // ── Draw path ──
    _drawPath(canvas, size);

    // ── Draw towers ──
    for (var t in towers) {
      _drawTower(canvas, t, tick);
    }

    // ── Draw enemies ──
    for (var e in enemies) {
      if (e.hp <= 0) continue;
      _drawEnemy(canvas, e);
    }

    // ── Draw projectiles ──
    for (var p in projs) {
      if (!p.active) continue;
      final colors = [_kBlue, Colors.orange, _kPurple];
      canvas.drawCircle(Offset(p.x, p.y), 5, Paint()..color = colors[p.type % 3]);
      canvas.drawCircle(Offset(p.x, p.y), 9, Paint()..color = colors[p.type % 3].withValues(alpha: 0.3));
    }

    // ── Particles ──
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 3 * (p.life / p.maxLife), Paint()..color = p.color.withValues(alpha: p.life / p.maxLife));
    }

    // Wave label
    final tp = TextPainter(text: TextSpan(text: 'WAVE $wave', style: TextStyle(color: _kBlue.withValues(alpha: 0.12), fontSize: 80, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(w/2 - tp.width/2, h/2 - 40));
  }

  void _drawPath(Canvas canvas, Size size) {
    // Path ground
    final groundPaint = Paint()..color = const Color(0xFF081C28)..strokeWidth = 44..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final pathObj = Path()..moveTo(path[0].dx, path[0].dy);
    for (int i = 1; i < path.length; i++) pathObj.lineTo(path[i].dx, path[i].dy);
    canvas.drawPath(pathObj, groundPaint);

    // Path edge glow
    final edgePaint = Paint()..color = _kBlue.withValues(alpha: 0.25)..strokeWidth = 46..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawPath(pathObj, edgePaint);

    // Path center lane markings
    final lanePaint = Paint()..color = const Color(0xFF0F3A50)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < path.length - 1; i++) {
      canvas.drawLine(path[i], path[i+1], lanePaint);
    }

    // Waypoint nodes
    for (int i = 1; i < path.length - 1; i++) {
      canvas.drawCircle(path[i], 6, Paint()..color = _kBlue.withValues(alpha: 0.4));
    }

    // Destination marker
    final dest = path.last;
    canvas.drawCircle(dest, 16, Paint()..color = _kRed.withValues(alpha: 0.3));
    canvas.drawCircle(dest, 16, Paint()..color = _kRed..style = PaintingStyle.stroke..strokeWidth = 2);
    // Core icon
    canvas.drawCircle(dest, 8, Paint()..color = _kRed);
  }

  void _drawTower(Canvas canvas, TDTower t, int tick) {
    final colors = [_kBlue, Colors.orange, _kPurple];
    final c = colors[t.type % 3];

    // Range circle (subtle)
    canvas.drawCircle(Offset(t.x, t.y), t.range, Paint()..color = c.withValues(alpha: 0.06));
    canvas.drawCircle(Offset(t.x, t.y), t.range, Paint()..color = c.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Base platform
    canvas.drawCircle(Offset(t.x, t.y), 20, Paint()..color = const Color(0xFF0A1E2E));
    canvas.drawCircle(Offset(t.x, t.y), 20, Paint()..color = c.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2);

    // Tower body
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(t.x, t.y), width: 20, height: 20), const Radius.circular(4)), Paint()..color = c.withValues(alpha: 0.3));

    // Tower top (rotating gun)
    final gunAngle = tick * 0.04 * (t.type + 1);
    canvas.save();
    canvas.translate(t.x, t.y);
    canvas.rotate(gunAngle);
    canvas.drawRect(Rect.fromLTWH(-3, -16, 6, 16), Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(-7, -4, 14, 8), Paint()..color = c.withValues(alpha: 0.7));
    canvas.restore();

    // Glow when firing (cd is low)
    if (t.cd <= 5) {
      canvas.drawCircle(Offset(t.x, t.y), 26, Paint()..color = c.withValues(alpha: 0.35));
    }
  }

  void _drawEnemy(Canvas canvas, TDEnemy e) {
    final colors = [_kRed, Colors.orange, _kPurple];
    final c = colors[e.type % 3];
    final size = 12.0 + e.wave * 1.5;

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(e.x, e.y + size + 2), width: size * 2, height: 5), Paint()..color = Colors.black38);

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(e.x, e.y), width: size * 2, height: size * 2.2), const Radius.circular(4)), Paint()..color = c.withValues(alpha: 0.4));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(e.x, e.y), width: size * 2, height: size * 2.2), const Radius.circular(4)), Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Eye (glowing)
    canvas.drawCircle(Offset(e.x, e.y), size * 0.55, Paint()..color = Colors.black54);
    canvas.drawCircle(Offset(e.x, e.y), size * 0.3, Paint()..color = c);

    // HP bar
    double hpRatio = (e.hp / e.maxHp).clamp(0.0, 1.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - 16, e.y - size - 9, 32, 5), const Radius.circular(2)), Paint()..color = Colors.black54);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(e.x - 16, e.y - size - 9, 32 * hpRatio, 5), const Radius.circular(2)), Paint()..color = hpRatio > 0.5 ? _kGreen : (hpRatio > 0.25 ? Colors.orange : _kRed));
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// GAME 4: CYBER RACER OVERDRIVE 2099 — Outrun Hyper Highway
// ─────────────────────────────────────────────────────────────────────────────
class StreetRacerGame extends StatefulWidget {
  const StreetRacerGame({super.key});
  @override State<StreetRacerGame> createState() => _StreetRacerGameState();
}

enum _TrafficType { supercar, truck, police, mine, token, shield, nitroCell }

class _TrafficEntity {
  double lane, y;
  _TrafficType type;
  double speedOffset;
  Color color;
  bool collected = false;
  _TrafficEntity(this.lane, this.y, this.type, this.color, {this.speedOffset = 0});
}

class _StreetRacerGameState extends State<StreetRacerGame> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  double _carX = 0.5; // 0..1 normalized lane
  double _targetCarX = 0.5;
  double _carSteerAngle = 0.0;
  double _speed = 5.0, _scroll = 0.0;
  double _roadCurve = 0.0;
  double _targetRoadCurve = 0.0;
  final List<_TrafficEntity> _traffic = [];
  bool _gameOver = false;
  int _score = 0, _distance = 0;
  int _tokensEarned = 0;
  int _multiplier = 1;
  int _nearMissCombo = 0;
  bool _nitroActive = false;
  double _nitro = 100.0;
  double _shake = 0.0;
  bool _hasShield = false;
  final List<_Particle> _particles = [];
  final List<_Particle> _speedLines = [];
  int _tickCount = 0;
  String? _bannerMessage;
  int _bannerTimer = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)..repeat();
  }

  void _showBanner(String msg) {
    setState(() {
      _bannerMessage = msg;
      _bannerTimer = 45;
    });
  }

  void _update() {
    if (_gameOver) return;
    _tickCount++;

    setState(() {
      if (_shake > 0) _shake = (_shake - 0.5).clamp(0.0, 30.0);
      if (_bannerTimer > 0) {
        _bannerTimer--;
        if (_bannerTimer <= 0) _bannerMessage = null;
      }

      // Smooth steering interpolation
      _carX += (_targetCarX - _carX) * 0.22;
      _carSteerAngle = (_targetCarX - _carX) * 1.5;

      // Dynamic road curving
      if (_tickCount % 160 == 0) {
        _targetRoadCurve = (Random().nextDouble() - 0.5) * 0.8;
      }
      _roadCurve += (_targetRoadCurve - _roadCurve) * 0.02;

      // Speed & nitro calculations
      final effectiveSpeed = _nitroActive ? _speed * 2.2 : _speed;
      _scroll += effectiveSpeed;
      _distance++;
      _score += (_multiplier * (effectiveSpeed / 4).toInt()).clamp(1, 20);

      // Nitro consumption & regeneration
      if (_nitroActive) {
        _nitro = (_nitro - 1.2).clamp(0.0, 100.0);
        if (_nitro <= 0) {
          _nitroActive = false;
        }
        _spawnParticles(_carX, 0.88, Colors.cyanAccent, 3);
        _spawnParticles(_carX, 0.90, Colors.purpleAccent, 2);
        _shake = (_shake + 0.3).clamp(0.0, 4.0);
      } else {
        _nitro = (_nitro + 0.25).clamp(0.0, 100.0);
      }

      // Speed scaling with distance
      if (_distance % 300 == 0 && _speed < 22) {
        _speed += 0.4;
      }

      // Spawn traffic and pickups
      if (Random().nextInt((45 / (_speed / 5)).clamp(15, 60).toInt()) == 0) {
        final lane = (Random().nextInt(4) + 0.5) / 4.0;
        final roll = Random().nextInt(100);
        _TrafficType type;
        Color color;

        if (roll < 45) {
          type = _TrafficType.supercar;
          color = [Colors.cyan, Colors.pinkAccent, Colors.purpleAccent, Colors.amber][Random().nextInt(4)];
        } else if (roll < 70) {
          type = _TrafficType.truck;
          color = Colors.tealAccent;
        } else if (roll < 82) {
          type = _TrafficType.police;
          color = Colors.blueAccent;
        } else if (roll < 90) {
          type = _TrafficType.token;
          color = Colors.yellowAccent;
        } else if (roll < 96) {
          type = _TrafficType.nitroCell;
          color = Colors.orangeAccent;
        } else {
          type = _TrafficType.shield;
          color = Colors.lightBlueAccent;
        }

        _traffic.add(_TrafficEntity(lane, -0.15, type, color, speedOffset: type == _TrafficType.truck ? -0.5 : 0.0));
      }

      // Update traffic
      final playerY = 0.84;
      for (var t in _traffic) {
        t.y += (effectiveSpeed + t.speedOffset) / 340;

        // Collision / Pickup Detection
        if (!t.collected && (t.y - playerY).abs() < 0.07 && (t.lane - _carX).abs() < 0.09) {
          if (t.type == _TrafficType.token) {
            t.collected = true;
            _tokensEarned += 25;
            _score += 150;
            _spawnParticles(_carX, playerY, Colors.yellowAccent, 15);
            GameSoundService().playCoin();
            _showBanner("💎 +25 TOKENS!");
            Provider.of<TokenProvider>(context, listen: false).addTokens(25);
          } else if (t.type == _TrafficType.shield) {
            t.collected = true;
            _hasShield = true;
            _spawnParticles(_carX, playerY, Colors.lightBlueAccent, 20);
            GameSoundService().playWin();
            _showBanner("🛡️ SHIELD EQUIPPED!");
          } else if (t.type == _TrafficType.nitroCell) {
            t.collected = true;
            _nitro = (_nitro + 40).clamp(0.0, 100.0);
            _spawnParticles(_carX, playerY, Colors.orangeAccent, 15);
            GameSoundService().playLaser();
            _showBanner("⚡ NITRO OVERCHARGED!");
          } else {
            // Harmful collision (Car / Truck / Police / Mine)
            if (_hasShield) {
              _hasShield = false;
              t.collected = true;
              _shake = 16;
              HapticFeedback.heavyImpact();
              GameSoundService().playExplosion();
              _spawnParticles(_carX, playerY, Colors.lightBlueAccent, 25);
              _showBanner("🛡️ SHIELD ABSORPTION!");
            } else {
              _gameOver = true;
              _shake = 26;
              HapticFeedback.vibrate();
              GameSoundService().playExplosion();
              GameSoundService().playLose();
              _spawnParticles(_carX, playerY, _kRed, 35);
            }
          }
        } else if (!t.collected && (t.y - playerY).abs() < 0.04 && (t.lane - _carX).abs() < 0.16 && (t.lane - _carX).abs() >= 0.09) {
          // Near miss bonus!
          if (t.type == _TrafficType.supercar || t.type == _TrafficType.truck || t.type == _TrafficType.police) {
            _nearMissCombo++;
            _score += 50 * _nearMissCombo;
            _multiplier = (_nearMissCombo ~/ 3 + 1).clamp(1, 5);
            _showBanner("🔥 NEAR MISS! x$_multiplier");
            _spawnParticles(_carX, playerY, Colors.orange, 4);
          }
        }
      }
      _traffic.removeWhere((t) => t.y > 1.2 || t.collected);

      // Speed lines & sparks
      if (_nitroActive || _speed > 10) {
        final rng = Random();
        _speedLines.add(_Particle(rng.nextDouble() * 420, 0, (rng.nextDouble() - 0.5) * 2, effectiveSpeed * 1.5, Colors.white.withValues(alpha: 0.7), 12));
      }

      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);

      for (var s in _speedLines) { s.update(); }
      _speedLines.removeWhere((s) => s.life <= 0);
    });
  }

  void _spawnParticles(double nx, double ny, Color c, int n) {
    final rng = Random();
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(nx * 400, ny * 720, (rng.nextDouble() - 0.5) * 8, (rng.nextDouble() - 0.5) * 8, c, 18 + rng.nextInt(12)));
    }
  }

  void _steer(double dir) {
    if (_gameOver) return;
    HapticFeedback.selectionClick();
    setState(() => _targetCarX = (_targetCarX + dir * 0.16).clamp(0.08, 0.92));
  }

  void _activateNitro() {
    if (_nitro > 15) {
      HapticFeedback.mediumImpact();
      GameSoundService().playLaser();
      setState(() => _nitroActive = true);
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final kmh = ((_nitroActive ? _speed * 2.2 : _speed) * 18).toInt();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 3D Perspective Cyber Highway Canvas
        Positioned.fill(
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_gameOver) return;
              final delta = details.primaryDelta ?? 0;
              setState(() => _targetCarX = (_targetCarX + delta * 0.003).clamp(0.08, 0.92));
            },
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return CustomPaint(
                  painter: CyberRacerPainter(
                    carX: _carX,
                    carSteerAngle: _carSteerAngle,
                    traffic: _traffic,
                    scroll: _scroll,
                    roadCurve: _roadCurve,
                    particles: _particles,
                    speedLines: _speedLines,
                    shake: _shake,
                    nitro: _nitroActive,
                    hasShield: _hasShield,
                    speed: _speed,
                    tickCount: _tickCount,
                  ),
                );
              },
            ),
          ),
        ),

        // TOP HUD HOLOGRAPHIC CLUSTER
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // High-Tech Speedometer & Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B19).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _nitroActive ? Colors.cyanAccent : _kOrange, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: (_nitroActive ? Colors.cyanAccent : _kOrange).withValues(alpha: 0.35), blurRadius: 16),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.speed_rounded, color: _nitroActive ? Colors.cyanAccent : _kOrange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$kmh KM/H',
                            style: TextStyle(
                              color: _nitroActive ? Colors.cyanAccent : _kOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(width: 1, height: 20, color: Colors.white24),
                          const SizedBox(width: 14),
                          Text(
                            'SCORE: $_score',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          if (_multiplier > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(8)),
                              child: Text('${_multiplier}X', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Token Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.token_rounded, color: Colors.yellowAccent, size: 16),
                          const SizedBox(width: 4),
                          Text('+$_tokensEarned', style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_bannerMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent, width: 1.5),
                    ),
                    child: Text(_bannerMessage!, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  ),
                ],
              ],
            ),
          ),
        ),

        // NITRO & SHIELD STATUS BAR
        Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_fire_department_rounded, color: _nitroActive ? Colors.cyanAccent : _kOrange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _nitroActive ? "⚡ OVERDRIVE PLASMA ACTIVE" : "NITRO THRUST",
                      style: TextStyle(color: _nitroActive ? Colors.cyanAccent : _kOrange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ]),
                  if (_hasShield)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.lightBlueAccent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.lightBlueAccent)),
                      child: const Text("🛡️ SHIELD ONLINE", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(color: const Color(0xFF0E1325), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white12)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _nitro / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _nitroActive ? [Colors.cyanAccent, Colors.purpleAccent] : [Colors.amber, _kRed],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: (_nitroActive ? Colors.cyanAccent : Colors.orange).withValues(alpha: 0.6), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // HIGH-TECH CONTROLS CLUSTER
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Steer Button
              _racerCtrlBtn(Icons.arrow_back_ios_rounded, () => _steer(-1), Colors.cyanAccent),
              // Hyper Nitro Button
              GestureDetector(
                onTapDown: (_) => _activateNitro(),
                onTapUp: (_) => setState(() => _nitroActive = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _nitroActive
                          ? [Colors.cyanAccent, Colors.purpleAccent]
                          : [const Color(0xFF1B2342), const Color(0xFF0D1226)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _nitroActive ? Colors.white : Colors.cyanAccent.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: (_nitroActive ? Colors.cyanAccent : Colors.purpleAccent).withValues(alpha: 0.4),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: _nitroActive ? Colors.black : Colors.cyanAccent, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        _nitroActive ? "HYPER NITRO!" : "BOOST",
                        style: TextStyle(
                          color: _nitroActive ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right Steer Button
              _racerCtrlBtn(Icons.arrow_forward_ios_rounded, () => _steer(1), Colors.cyanAccent),
            ],
          ),
        ),

        // GAME OVER OVERDRIVE DIALOG
        if (_gameOver)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF090D1C).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _kRed, width: 2),
                boxShadow: [
                  BoxShadow(color: _kRed.withValues(alpha: 0.4), blurRadius: 28),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("💥 SYSTEM OVERLOAD", style: TextStyle(color: _kRed, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Text("Final Distance: ${_distance}m  •  Peak Speed: $kmh KM/H", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text("Score: $_score  •  Tokens Earned: +$_tokensEarned", style: const TextStyle(color: Colors.yellowAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _gameOver = false;
                            _score = 0;
                            _distance = 0;
                            _speed = 5.0;
                            _carX = 0.5;
                            _targetCarX = 0.5;
                            _traffic.clear();
                            _hasShield = false;
                            _nitro = 100.0;
                            _tokensEarned = 0;
                            _multiplier = 1;
                            _nearMissCombo = 0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("RETRY RUN", style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("LOBBY"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _racerCtrlBtn(IconData icon, VoidCallback fn, Color color) {
    return GestureDetector(
      onTapDown: (_) => fn(),
      onLongPress: fn,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D PERSPECTIVE CYBER RACER PAINTER ENGINE
// ─────────────────────────────────────────────────────────────────────────────
class CyberRacerPainter extends CustomPainter {
  final double carX, carSteerAngle, scroll, roadCurve, speed, shake;
  final List<_TrafficEntity> traffic;
  final List<_Particle> particles;
  final List<_Particle> speedLines;
  final bool nitro, hasShield;
  final int tickCount;

  CyberRacerPainter({
    required this.carX,
    required this.carSteerAngle,
    required this.traffic,
    required this.scroll,
    required this.roadCurve,
    required this.particles,
    required this.speedLines,
    required this.shake,
    required this.nitro,
    required this.hasShield,
    required this.speed,
    required this.tickCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    if (shake > 0) {
      final rng = Random();
      canvas.translate((rng.nextDouble() - 0.5) * shake, (rng.nextDouble() - 0.5) * shake);
    }

    final horizonY = h * 0.32;

    // 1. Synthwave Cyber Sky
    final skyRect = Rect.fromLTWH(0, 0, w, horizonY);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF030511), Color(0xFF0D0A24), Color(0xFF1D0933)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(skyRect),
    );

    // Giant Glowing Synthwave Sun with retro horizontal stripes
    final sunCenter = Offset(w * 0.5 + roadCurve * 40, horizonY - 30);
    final sunRadius = w * 0.24;
    final sunShader = RadialGradient(
      colors: [Colors.yellowAccent, Colors.pinkAccent, Colors.purple.shade900.withValues(alpha: 0)],
      stops: const [0.2, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, Paint()..shader = sunShader);

    // Sun horizontal scanline cutouts
    final sunClipPaint = Paint()..color = const Color(0xFF0D0A24);
    for (var i = 0; i < 7; i++) {
      final sy = sunCenter.dy + i * 7.0;
      if (sy < horizonY) {
        canvas.drawRect(Rect.fromLTWH(sunCenter.dx - sunRadius, sy, sunRadius * 2, 2.0 + i * 0.6), sunClipPaint);
      }
    }

    // 2. Parallax Cyber Skyline with Holographic Billboards
    final skylinePaint = Paint()..color = const Color(0xFF0B0E23);
    for (int i = 0; i < 18; i++) {
      final bw = 24.0 + (i * 9) % 32;
      final bh = 40.0 + (i * 13) % 70;
      final bx = ((i * 44.0 + scroll * 0.15) % (w + 60)) - 30;
      canvas.drawRect(Rect.fromLTWH(bx, horizonY - bh, bw, bh), skylinePaint);

      // Glowing Cyber Windows
      if ((i + (scroll ~/ 80)) % 3 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(bx + 4, horizonY - bh + 6, 6, 6),
          Paint()..color = (i % 2 == 0 ? Colors.cyanAccent : Colors.pinkAccent).withValues(alpha: 0.6),
        );
      }
    }

    // 3. 3D Perspective Road & Curved Highway Grid
    final roadTopWidth = w * 0.18;
    final roadBottomWidth = w * 1.15;
    final roadPath = Path();
    final roadTopX = w * 0.5 + roadCurve * 60;

    roadPath.moveTo(roadTopX - roadTopWidth / 2, horizonY);
    roadPath.lineTo(roadTopX + roadTopWidth / 2, horizonY);
    roadPath.lineTo(w / 2 + roadBottomWidth / 2, h);
    roadPath.lineTo(w / 2 - roadBottomWidth / 2, h);
    roadPath.close();

    final roadShader = LinearGradient(
      colors: [const Color(0xFF080C1B), const Color(0xFF0F142A), const Color(0xFF050711)],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, horizonY, w, h - horizonY));
    canvas.drawPath(roadPath, Paint()..shader = roadShader);

    // Neon Cyber Curbs (Animated pulsating curbs on road borders)
    final curbSegments = 22;
    for (int i = 0; i < curbSegments; i++) {
      final t1 = i / curbSegments;
      final t2 = (i + 1) / curbSegments;
      final y1 = horizonY + math.pow(t1, 1.8) * (h - horizonY);
      final y2 = horizonY + math.pow(t2, 1.8) * (h - horizonY);

      final rWidth1 = roadTopWidth + (roadBottomWidth - roadTopWidth) * t1;
      final rWidth2 = roadTopWidth + (roadBottomWidth - roadTopWidth) * t2;
      final cx1 = roadTopX + (w / 2 - roadTopX) * t1;
      final cx2 = roadTopX + (w / 2 - roadTopX) * t2;

      final isEven = ((i + (scroll ~/ 25)) % 2 == 0);
      final curbColor = isEven ? (nitro ? Colors.cyanAccent : Colors.pinkAccent) : const Color(0xFF1E2648);

      final leftCurb = Path()
        ..moveTo(cx1 - rWidth1 / 2, y1)
        ..lineTo(cx1 - rWidth1 / 2 - 8 * t1, y1)
        ..lineTo(cx2 - rWidth2 / 2 - 8 * t2, y2)
        ..lineTo(cx2 - rWidth2 / 2, y2)
        ..close();
      canvas.drawPath(leftCurb, Paint()..color = curbColor);

      final rightCurb = Path()
        ..moveTo(cx1 + rWidth1 / 2, y1)
        ..lineTo(cx1 + rWidth1 / 2 + 8 * t1, y1)
        ..lineTo(cx2 + rWidth2 / 2 + 8 * t2, y2)
        ..lineTo(cx2 + rWidth2 / 2, y2)
        ..close();
      canvas.drawPath(rightCurb, Paint()..color = curbColor);
    }

    // 4. Perspective Dashed Lane Dividers (4 Lanes)
    final laneDividerPaint = Paint()
      ..color = (nitro ? Colors.cyanAccent : Colors.white).withValues(alpha: 0.45)
      ..strokeWidth = 2;

    for (int lane = 1; lane <= 3; lane++) {
      final laneFrac = lane / 4.0;
      for (int i = 0; i < 14; i++) {
        final t = ((i * 0.08 + (scroll * 0.003)) % 1.0);
        final markY = horizonY + math.pow(t, 2.0) * (h - horizonY);
        final rWidth = roadTopWidth + (roadBottomWidth - roadTopWidth) * t;
        final cx = roadTopX + (w / 2 - roadTopX) * t;
        final markX = cx - rWidth / 2 + rWidth * laneFrac;

        final dashLength = 12.0 * t + 3.0;
        canvas.drawLine(Offset(markX, markY), Offset(markX, markY + dashLength), laneDividerPaint..strokeWidth = 1.5 * t + 0.8);
      }
    }

    // 5. Speed Lines / Warp Effect
    for (var s in speedLines) {
      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(s.x, s.y + s.vy * 4),
        Paint()..color = (nitro ? Colors.cyanAccent : Colors.white).withValues(alpha: (s.life / s.maxLife) * 0.6)..strokeWidth = 2,
      );
    }

    // 6. Draw Traffic & Pickups (Sorted by Y for depth layering)
    final sortedTraffic = List<_TrafficEntity>.from(traffic)..sort((a, b) => a.y.compareTo(b.y));
    for (var t in sortedTraffic) {
      if (t.y < 0 || t.y > 1.1) continue;
      final ty = horizonY + math.pow(t.y, 1.8) * (h - horizonY);
      final rWidth = roadTopWidth + (roadBottomWidth - roadTopWidth) * t.y;
      final cx = roadTopX + (w / 2 - roadTopX) * t.y;
      final tx = cx - rWidth / 2 + rWidth * t.lane;
      final scale = (0.3 + 0.9 * t.y).clamp(0.2, 1.2);

      _drawTrafficEntity(canvas, tx, ty, t, scale);
    }

    // 7. Draw Player Hypercar (With Dynamic Volumetric Headlights & Shield)
    final playerY = horizonY + math.pow(0.84, 1.8) * (h - horizonY);
    final playerRWidth = roadTopWidth + (roadBottomWidth - roadTopWidth) * 0.84;
    final playerCx = roadTopX + (w / 2 - roadTopX) * 0.84;
    final px = playerCx - playerRWidth / 2 + playerRWidth * carX;

    _drawPlayerHypercar(canvas, px, playerY, nitro, hasShield, carSteerAngle);

    // 8. Particle Sparks & Explosions
    for (var p in particles) {
      final lifeFrac = p.life / p.maxLife;
      canvas.drawCircle(Offset(p.x, p.y), 4 * lifeFrac, Paint()..color = p.color.withValues(alpha: lifeFrac));
    }

    canvas.restore();
  }

  void _drawTrafficEntity(Canvas canvas, double cx, double cy, _TrafficEntity entity, double scale) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    switch (entity.type) {
      case _TrafficType.supercar:
        _drawCyberCar(canvas, entity.color, isTruck: false);
        break;
      case _TrafficType.truck:
        _drawCyberCar(canvas, entity.color, isTruck: true);
        break;
      case _TrafficType.police:
        _drawPoliceCar(canvas);
        break;
      case _TrafficType.mine:
        _drawMine(canvas);
        break;
      case _TrafficType.token:
        _drawDiamond(canvas, Colors.yellowAccent);
        break;
      case _TrafficType.shield:
        _drawShieldPickup(canvas);
        break;
      case _TrafficType.nitroCell:
        _drawNitroCell(canvas);
        break;
    }

    canvas.restore();
  }

  void _drawCyberCar(Canvas canvas, Color color, {required bool isTruck}) {
    final w = isTruck ? 44.0 : 38.0;
    final h = isTruck ? 84.0 : 68.0;

    // Underglow
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 10), width: w + 12, height: h + 10), Paint()..color = color.withValues(alpha: 0.35));

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 26), width: w + 8, height: 14), Paint()..color = Colors.black87);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), const Radius.circular(10)),
      Paint()..color = color,
    );

    // Roof & Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -12), width: w - 10, height: 26), const Radius.circular(6)),
      Paint()..color = const Color(0xFF070B19),
    );

    // Rear Lights
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-w / 2 + 4, h / 2 - 8, 8, 4), const Radius.circular(2)), Paint()..color = _kRed);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 12, h / 2 - 8, 8, 4), const Radius.circular(2)), Paint()..color = _kRed);
  }

  void _drawPoliceCar(Canvas canvas) {
    _drawCyberCar(canvas, const Color(0xFF0F1A3A), isTruck: false);

    // Flashing Siren Bar
    final isRed = (tickCount ~/ 6) % 2 == 0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 10, 6), const Radius.circular(3)),
      Paint()..color = isRed ? Colors.redAccent : Colors.blueAccent..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, -18, 10, 6), const Radius.circular(3)),
      Paint()..color = isRed ? Colors.blueAccent : Colors.redAccent..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  void _drawMine(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 16, Paint()..color = Colors.redAccent.withValues(alpha: 0.8));
    canvas.drawCircle(Offset.zero, 8, Paint()..color = Colors.white);
  }

  void _drawDiamond(Canvas canvas, Color color) {
    final path = Path()
      ..moveTo(0, -18)
      ..lineTo(14, 0)
      ..lineTo(0, 18)
      ..lineTo(-14, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawShieldPickup(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 18, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.5));
    canvas.drawCircle(Offset.zero, 12, Paint()..color = Colors.white);
  }

  void _drawNitroCell(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 22, height: 26), const Radius.circular(6)),
      Paint()..color = Colors.orangeAccent,
    );
    canvas.drawCircle(Offset.zero, 6, Paint()..color = Colors.white);
  }

  void _drawPlayerHypercar(Canvas canvas, double cx, double cy, bool nitro, bool hasShield, double steerAngle) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(steerAngle * 0.2);

    // 1. Volumetric Headlight Cones
    final headlightPath = Path()
      ..moveTo(-16, -30)
      ..lineTo(-70, -180)
      ..lineTo(70, -180)
      ..lineTo(16, -30)
      ..close();
    canvas.drawPath(
      headlightPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            (nitro ? Colors.cyanAccent : Colors.white).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(const Rect.fromLTWH(-70, -180, 140, 150)),
    );

    // 2. Active Holo-Shield Aura
    if (hasShield) {
      canvas.drawCircle(
        Offset.zero,
        52,
        Paint()
          ..color = Colors.lightBlueAccent.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
      );
    }

    // 3. Cyber Underglow Glow
    final underglowColor = nitro ? Colors.cyanAccent : Colors.purpleAccent;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 14), width: 62, height: 95),
      Paint()..color = underglowColor.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 4. Hypercar Chassis (Aerodynamic Carbon Fiber Body)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F2B5C), Color(0xFF1E52A8), Color(0xFF081533)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-24, -45, 48, 90));

    final chassisPath = Path()
      ..moveTo(0, -45)
      ..lineTo(18, -32)
      ..lineTo(24, 0)
      ..lineTo(22, 38)
      ..lineTo(16, 44)
      ..lineTo(-16, 44)
      ..lineTo(-22, 38)
      ..lineTo(-24, 0)
      ..lineTo(-18, -32)
      ..close();
    canvas.drawPath(chassisPath, bodyPaint);

    // Cockpit Canopy
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -6), width: 26, height: 38), const Radius.circular(10)),
      Paint()..color = const Color(0xFF040816),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -10), width: 22, height: 22), const Radius.circular(6)),
      Paint()..color = Colors.cyanAccent.withValues(alpha: 0.6),
    );

    // Rear Tail Laser Bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-18, 40, 36, 4), const Radius.circular(2)),
      Paint()..color = _kRed..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );

    // 5. Twin Plasma Nitro Thrust Eruption
    if (nitro) {
      final flameShader = RadialGradient(
        colors: [Colors.white, Colors.cyanAccent, Colors.purpleAccent, Colors.transparent],
        stops: const [0.1, 0.4, 0.8, 1.0],
      ).createShader(const Rect.fromLTWH(-18, 42, 36, 50));

      final flamePath = Path()
        ..moveTo(-14, 44)
        ..lineTo(-8, 88 + Random().nextDouble() * 14)
        ..lineTo(0, 48)
        ..lineTo(8, 88 + Random().nextDouble() * 14)
        ..lineTo(14, 44)
        ..close();
      canvas.drawPath(flamePath, Paint()..shader = flameShader);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME 5: CYBER HEIST — Neon facility stealth grid
// ─────────────────────────────────────────────────────────────────────────────
class CyberHeistGame extends StatefulWidget {
  const CyberHeistGame({super.key});
  @override State<CyberHeistGame> createState() => _CyberHeistGameState();
}

class _CyberHeistGameState extends State<CyberHeistGame> with TickerProviderStateMixin {
  late AnimationController _ctrl, _pulseCtrl;
  double _px = 0, _py = 7; // Player starts at bottom-left
  final List<Offset> _safes = const [Offset(7, 0), Offset(0, 4), Offset(7, 7)];
  final List<Offset> _hacked = [];
  final List<HeistGuard> _guards = [
    HeistGuard(4.0, 3.0, 1.2, 0.0),
    HeistGuard(2.0, 6.0, 0.0, 1.0),
    HeistGuard(6.0, 5.0, -0.8, 0.6),
  ];
  bool _gameOver = false, _victory = false, _rewardGiven = false;
  int _tick = 0;
  final List<_Particle> _particles = [];
  bool _showHack = false;
  String _hackMsg = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  void _update() {
    if (_gameOver || _victory) return;
    setState(() {
      _tick++;

      for (var g in _guards) {
        g.x = (g.x + g.vx * 0.04).clamp(0.0, 7.0);
        g.y = (g.y + g.vy * 0.04).clamp(0.0, 7.0);
        // Bounce at walls
        if (g.x <= 0 || g.x >= 7) g.vx *= -1;
        if (g.y <= 0 || g.y >= 7) g.vy *= -1;
        // Detection radius
        double dist = sqrt(pow(g.x - _px, 2) + pow(g.y - _py, 2));
        if (dist < 1.2) {
          _gameOver = true;
          HapticFeedback.vibrate();
          GameSoundService().playLose();
          _spawnParticles(_px * 50 + 20, _py * 50 + 20, _kRed, 15);
        }
      }

      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _spawnParticles(double x, double y, Color c, int n) {
    final rng = Random();
    for (int i = 0; i < n; i++) {
      _particles.add(_Particle(x, y, (rng.nextDouble()-0.5)*5, (rng.nextDouble()-0.5)*5, c, 20+rng.nextInt(10)));
    }
  }

  void _move(double dx, double dy) {
    if (_gameOver || _victory) return;
    GameSoundService().playTick();
    setState(() {
      _px = (_px + dx).clamp(0.0, 7.0);
      _py = (_py + dy).clamp(0.0, 7.0);
      
      final safeHit = _safes.firstWhere(
        (s) => (s.dx - _px).abs() < 0.5 && (s.dy - _py).abs() < 0.5,
        orElse: () => const Offset(-1, -1),
      );
      if (safeHit != const Offset(-1, -1) && !_hacked.contains(safeHit)) {
        _hacked.add(safeHit);
        _hackMsg = 'SAFE CRACKED! 🔓';
        _showHack = true;
        HapticFeedback.mediumImpact();
        GameSoundService().playCoin();
        _spawnParticles(safeHit.dx * 50 + 20, safeHit.dy * 50 + 20, _kGold, 12);
        Future.delayed(const Duration(seconds: 1), () { if (mounted) setState(() => _showHack = false); });
        if (_hacked.length == _safes.length) {
          _victory = true;
          if (!_rewardGiven) {
            _rewardGiven = true;
            Provider.of<TokenProvider>(context, listen: false).addTokens(200);
            HapticFeedback.heavyImpact();
            GameSoundService().playWin();
          }
        }
      }
    });
  }

  @override void dispose() { _ctrl.dispose(); _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010A0F),
      body: SafeArea(
        child: Column(children: [
          // HUD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF020F18),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
              const Text("CYBER HEIST", style: TextStyle(color: _kBlue, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
              const Spacer(),
              ...List.generate(3, (i) => Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: i < _hacked.length ? _kGold.withValues(alpha: 0.3) : Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: i < _hacked.length ? _kGold : Colors.white12),
                ),
                child: Icon(Icons.lock_open_rounded, color: i < _hacked.length ? _kGold : Colors.white24, size: 16),
              )),
              const SizedBox(width: 8),
              Text('${_hacked.length}/3', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          // Map
          Expanded(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => CustomPaint(
                painter: HeistPainter(_px, _py, _safes, _hacked, _guards, _particles, _pulseCtrl.value, _tick),
                size: const Size(double.infinity, double.infinity),
              ),
            ),
          ),
          // Status
          if (_showHack)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: _kGold.withValues(alpha: 0.1),
              child: Center(child: Text(_hackMsg, style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 16))),
            ),
          if (_gameOver)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: _kRed.withValues(alpha: 0.15),
              child: const Center(child: Text("🚨 BUSTED! SECURITY COMPROMISED", style: TextStyle(color: _kRed, fontWeight: FontWeight.w900, fontSize: 14))),
            ),
          if (_victory)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF001A10), Color(0xFF003020)])),
              child: const Center(child: Text("💎 VAULT CRACKED! +200 TOKENS EARNED!", style: TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 14))),
            ),
          // D-pad controls
          Container(
            height: 160,
            color: const Color(0xFF020F18),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _hBtn(Icons.north_rounded, 0, -1),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _hBtn(Icons.west_rounded, -1, 0),
                  const SizedBox(width: 50),
                  _hBtn(Icons.east_rounded, 1, 0),
                ]),
                _hBtn(Icons.south_rounded, 0, 1),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _hBtn(IconData icon, double dx, double dy) {
    return GestureDetector(
      onTap: () => _move(dx, dy),
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: _kBlue, size: 24),
      ),
    );
  }
}

class HeistGuard {
  double x, y, vx, vy;
  HeistGuard(this.x, this.y, this.vx, this.vy);
}

class HeistPainter extends CustomPainter {
  final double px, py;
  final List<Offset> safes, hacked;
  final List<HeistGuard> guards;
  final List<_Particle> particles;
  final double pulse;
  final int tick;

  HeistPainter(this.px, this.py, this.safes, this.hacked, this.guards, this.particles, this.pulse, this.tick);

  static const int gridSize = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cw = w / gridSize;
    final ch = h / gridSize;

    // ── Background ──
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF020D14));

    // Floor tiles with cyber pattern
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final tileColor = (i + j) % 2 == 0 ? const Color(0xFF030F1A) : const Color(0xFF050E18);
        canvas.drawRect(Rect.fromLTWH(i*cw, j*ch, cw, ch), Paint()..color = tileColor);
        canvas.drawRect(Rect.fromLTWH(i*cw, j*ch, cw, ch), Paint()..color = _kBlue.withValues(alpha: 0.04)..style = PaintingStyle.stroke..strokeWidth = 0.5);
      }
    }

    // Floor glow strips
    for (int i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(i*cw, 0), Offset(i*cw, h), Paint()..color = _kBlue.withValues(alpha: 0.12)..strokeWidth = 1);
      canvas.drawLine(Offset(0, i*ch), Offset(w, i*ch), Paint()..color = _kBlue.withValues(alpha: 0.12)..strokeWidth = 1);
    }

    // Walls/obstacles (decorative server racks)
    for (int i = 2; i < 6; i += 2) {
      _drawServerRack(canvas, i*cw, 2*ch, cw*0.8, ch*0.8);
      _drawServerRack(canvas, i*cw, 5*ch, cw*0.8, ch*0.8);
    }

    // ── Guards ──
    for (var g in guards) {
      double gx = g.x * cw + cw/2;
      double gy = g.y * ch + ch/2;

      // Detection radius
      double detR = 1.2 * (min(cw, ch));
      canvas.drawCircle(Offset(gx, gy), detR, Paint()..color = _kRed.withValues(alpha: 0.08 + 0.04 * pulse));
      canvas.drawCircle(Offset(gx, gy), detR, Paint()..color = _kRed.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1);

      // Guard flashlight (directional cone)
      final vAngle = atan2(g.vy, g.vx);
      final flashPath = Path();
      flashPath.moveTo(gx, gy);
      flashPath.arcTo(Rect.fromCircle(center: Offset(gx, gy), radius: detR * 1.4), vAngle - 0.5, 1.0, false);
      flashPath.close();
      canvas.drawPath(flashPath, Paint()..color = Colors.yellow.withValues(alpha: 0.07));

      // Guard body
      canvas.drawCircle(Offset(gx, gy), min(cw, ch) * 0.35, Paint()..color = const Color(0xFF3A0000));
      canvas.drawCircle(Offset(gx, gy), min(cw, ch) * 0.35, Paint()..color = _kRed.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 2);
      // Guard icon
      canvas.drawCircle(Offset(gx, gy - min(cw,ch)*0.12), min(cw,ch)*0.18, Paint()..color = Colors.redAccent);
    }

    // ── Safes ──
    for (var s in safes) {
      double sx = s.dx * cw + cw*0.15;
      double sy = s.dy * ch + ch*0.15;
      bool isHacked = hacked.contains(s);

      // Glow
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sx - 5, sy - 5, cw*0.7 + 10, ch*0.7 + 10), const Radius.circular(8)),
        Paint()..color = (isHacked ? _kGold : _kOrange).withValues(alpha: 0.2 + 0.1 * pulse));
      // Safe body
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sx, sy, cw*0.7, ch*0.7), const Radius.circular(6)),
        Paint()..color = isHacked ? const Color(0xFF1A1400) : const Color(0xFF1A0800));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sx, sy, cw*0.7, ch*0.7), const Radius.circular(6)),
        Paint()..color = (isHacked ? _kGold : _kOrange)..style = PaintingStyle.stroke..strokeWidth = 2);
      // Lock/unlock icon
      canvas.drawCircle(Offset(sx + cw*0.35, sy + ch*0.35), min(cw, ch)*0.15,
        Paint()..color = isHacked ? _kGold : Colors.grey);
    }

    // ── Player ──
    double plx = px * cw + cw/2;
    double ply = py * ch + ch/2;
    // Stealth aura
    canvas.drawCircle(Offset(plx, ply), min(cw,ch)*0.5, Paint()..color = _kBlue.withValues(alpha: 0.1 + 0.06 * pulse));
    // Player body
    canvas.drawCircle(Offset(plx, ply), min(cw,ch)*0.32, Paint()..color = const Color(0xFF001830));
    canvas.drawCircle(Offset(plx, ply), min(cw,ch)*0.32, Paint()..color = _kBlue.withValues(alpha: 0.9)..style = PaintingStyle.stroke..strokeWidth = 2);
    // Player icon (person)
    canvas.drawCircle(Offset(plx, ply - min(cw,ch)*0.12), min(cw,ch)*0.15, Paint()..color = _kBlue);

    // ── Particles ──
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 4*(p.life/p.maxLife), Paint()..color = p.color.withValues(alpha: p.life/p.maxLife));
    }
  }

  void _drawServerRack(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0A1A2A));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      Paint()..color = _kBlue.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
    // LED lights
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(x + 8, y + 8 + i * 14), 3, Paint()..color = i % 2 == 0 ? _kGreen : _kBlue);
    }
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
