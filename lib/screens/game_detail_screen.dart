import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_category.dart';
import '../providers/token_provider.dart';
import '../utils/constants.dart';
import '../services/game_sound_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kNeonGreen = Color(0xFF22C55E);
const _kNeonPurple = Color(0xFF8B5CF6);
const _kNeonCyan = Color(0xFF06B6D4);
const _kNeonPink = Color(0xFFFF69B4);
const _kNeonOrange = Color(0xFFF97316);
const _kDarkBg = Color(0xFF060A18);

// ─── Game Detail Screen ───────────────────────────────────────────────────────
class GameDetailScreen extends StatefulWidget {
  static const routeName = '/game-detail';

  const GameDetailScreen({
    super.key,
    required this.category,
  });

  final GameCategory category;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen>
    with TickerProviderStateMixin {
  // Game states
  bool _isPlaying = false;
  bool _gameOver = false;
  bool _gameWon = false;
  int _score = 0;
  int _highScore = 2500;
  int _health = 100;
  int _shield = 100;
  int _combo = 0;
  int _maxCombo = 0;
  int _earnedTokens = 0;

  // Difficulty & Weapon Selection
  int _difficultyTier = 1; // 1: Recruit (1x), 2: Veteran (2.5x), 3: Cyber Psycho (5x)
  int _selectedWeapon = 0; // 0: Dual Plasma, 1: Homing EMP, 2: Hyper Beam
  double _empBombCharge = 100.0; // 0..100
  bool _matrixSlowMoActive = false;

  // Ticker controller for smooth game loop (60 FPS)
  late final AnimationController _gameLoop;
  final Random _rng = Random();

  // Space Shooter State (Action / Adventure)
  double _playerX = 0.5; // 0..1
  double _playerY = 0.8; // 0..1
  final List<Offset> _lasers = [];
  final List<_Enemy> _enemies = [];
  final List<_Particle> _particles = [];
  final List<_TokenDrop> _tokenDrops = [];
  _Boss? _activeBoss;

  // Reflex / Target Shooter State (Thriller / Horror)
  final List<_Target> _targets = [];
  double _spawnTimer = 0;

  // Hack / Puzzle State
  final List<int> _sequencePattern = [];
  final List<int> _playerInput = [];
  bool _showingSequence = false;
  int _currentStep = 0;
  int _firewallLevel = 1;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateGame);
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    super.dispose();
  }

  // ── GAME LOOP ─────────────────────────────────────────────────────────────
  void _startGame() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPlaying = true;
      _gameOver = false;
      _gameWon = false;
      _score = 0;
      _health = 100;
      _shield = 100;
      _combo = 0;
      _maxCombo = 0;
      _earnedTokens = 0;
      _playerX = 0.5;
      _playerY = 0.8;
      _empBombCharge = 100.0;
      _matrixSlowMoActive = false;
      _lasers.clear();
      _enemies.clear();
      _particles.clear();
      _tokenDrops.clear();
      _targets.clear();
      _activeBoss = null;
      _sequencePattern.clear();
      _playerInput.clear();
      _firewallLevel = 1;
    });

    if (widget.category.name.toLowerCase() == 'puzzle') {
      _startPuzzleLevel();
    } else {
      _gameLoop.repeat();
    }
  }

  void _updateGame() {
    if (!_isPlaying || _gameOver) return;

    final gameType = widget.category.name.toLowerCase();
    final double timeScale = _matrixSlowMoActive ? 0.35 : 1.0;

    setState(() {
      // 1. Update particles
      for (final p in _particles) {
        p.x += p.vx * timeScale;
        p.y += p.vy * timeScale;
        p.life -= 0.03 * timeScale;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // 2. Action / Adventure / Space Shooter Logic
      if (gameType == 'action' || gameType == 'adventure') {
        // Move lasers
        for (var i = 0; i < _lasers.length; i++) {
          _lasers[i] = Offset(_lasers[i].dx, _lasers[i].dy - (0.04 * timeScale));
        }
        _lasers.removeWhere((l) => l.dy < -0.1);

        // Move token coin drops
        for (final drop in _tokenDrops) {
          drop.y += 0.012 * timeScale;
          if ((drop.x - _playerX).abs() < 0.1 && (drop.y - _playerY).abs() < 0.1) {
            _earnedTokens += drop.value;
            _score += 150;
            _spawnExplosion(drop.x, drop.y, const Color(0xFFFFD700));
            HapticFeedback.selectionClick();
            GameSoundService().playCoin();
            drop.collected = true;
          }
        }
        _tokenDrops.removeWhere((d) => d.collected || d.y > 1.1);

        // Spawn Boss at 3000 points
        if (_score >= 3000 && _activeBoss == null && !_gameWon) {
          _activeBoss = _Boss(
            x: 0.5,
            y: 0.15,
            hp: 200 * _difficultyTier,
            maxHp: 200 * _difficultyTier,
            name: 'CYBER DREADNOUGHT',
          );
          _spawnExplosion(0.5, 0.15, _kNeonPurple);
          HapticFeedback.vibrate();
        }

        // Boss Update
        if (_activeBoss != null) {
          final boss = _activeBoss!;
          boss.x += (cos(DateTime.now().millisecondsSinceEpoch * 0.002) * 0.006) * timeScale;
          boss.x = boss.x.clamp(0.15, 0.85);

          // Boss Laser attack
          if (_rng.nextDouble() < 0.06 * timeScale) {
            _enemies.add(_Enemy(
              x: boss.x + (_rng.nextDouble() * 0.2 - 0.1),
              y: boss.y + 0.05,
              speed: 0.015 * _difficultyTier,
              type: 3,
              health: 1,
            ));
          }
        } else {
          // Normal Enemy Spawns
          final spawnRate = (0.04 + (_score / 25000)) * _difficultyTier;
          if (_rng.nextDouble() < spawnRate * timeScale) {
            _enemies.add(_Enemy(
              x: _rng.nextDouble() * 0.9 + 0.05,
              y: -0.1,
              speed: (0.008 + _rng.nextDouble() * 0.008) * _difficultyTier,
              type: _rng.nextInt(3),
              health: 1 + _rng.nextInt(2 * _difficultyTier),
            ));
          }
        }

        // Move enemies & collision check
        for (final enemy in _enemies) {
          enemy.y += enemy.speed * timeScale;

          // Player collision
          if ((enemy.x - _playerX).abs() < 0.08 && (enemy.y - _playerY).abs() < 0.08) {
            enemy.health = 0;
            if (_shield > 0) {
              _shield = (_shield - 25).clamp(0, 100);
            } else {
              _health -= 20;
            }
            _combo = 0;
            _spawnExplosion(enemy.x, enemy.y, _kNeonOrange);
            HapticFeedback.mediumImpact();
            if (_health <= 0) _endGame(false);
          }

          // Laser hits enemy
          for (final laser in _lasers) {
            if ((laser.dx - enemy.x).abs() < 0.08 && (laser.dy - enemy.y).abs() < 0.08) {
              enemy.health--;
              _spawnExplosion(enemy.x, enemy.y, _kNeonCyan);
              if (enemy.health <= 0) {
                _score += 100 * _difficultyTier + (_combo * 15);
                _combo++;
                if (_combo > _maxCombo) _maxCombo = _combo;
                _empBombCharge = (_empBombCharge + 8).clamp(0.0, 100.0);

                // Chance to drop tokens
                if (_rng.nextDouble() < 0.4) {
                  _tokenDrops.add(_TokenDrop(x: enemy.x, y: enemy.y, value: 5 * _difficultyTier));
                }
              }
            }
          }
        }

        // Check Lasers hit Boss
        if (_activeBoss != null) {
          for (final laser in _lasers) {
            if ((laser.dx - _activeBoss!.x).abs() < 0.18 && (laser.dy - _activeBoss!.y).abs() < 0.12) {
              _activeBoss!.hp -= (_selectedWeapon == 2 ? 4 : 2);
              _spawnExplosion(laser.dx, laser.dy, _kNeonPink);
              if (_activeBoss!.hp <= 0) {
                _spawnExplosion(_activeBoss!.x, _activeBoss!.y, _kNeonGreen);
                _activeBoss = null;
                _score += 2000 * _difficultyTier;
                _earnedTokens += 50 * _difficultyTier;
                _endGame(true);
                break;
              }
            }
          }
        }

        _enemies.removeWhere((e) => e.health <= 0 || e.y > 1.1);
      }

      // 3. Thriller / Horror Target Shooting Logic
      if (gameType == 'thriller' || gameType == 'horror') {
        _spawnTimer += 0.03 * timeScale;
        if (_spawnTimer > (1.2 / _difficultyTier)) {
          _spawnTimer = 0;
          final isDecoy = _rng.nextDouble() < 0.25; // 25% decoy VIP
          _targets.add(_Target(
            x: _rng.nextDouble() * 0.8 + 0.1,
            y: _rng.nextDouble() * 0.6 + 0.15,
            isHostile: !isDecoy,
            duration: (2.5 - (_score / 5000)).clamp(0.9, 2.5) / _difficultyTier,
          ));
        }

        for (final target in _targets) {
          target.life -= 0.02 * timeScale;
        }

        for (final target in _targets.where((t) => t.life <= 0)) {
          if (target.isHostile) {
            if (_shield > 0) {
              _shield = (_shield - 20).clamp(0, 100);
            } else {
              _health -= 15;
            }
            _combo = 0;
            _spawnExplosion(target.x, target.y, Colors.redAccent);
            if (_health <= 0) _endGame(false);
          }
        }
        _targets.removeWhere((t) => t.life <= 0);
      }
    });
  }

  void _triggerEmpBomb() {
    if (_empBombCharge < 100 || !_isPlaying || _gameOver) return;
    HapticFeedback.heavyImpact();
    GameSoundService().playExplosion();
    setState(() {
      _empBombCharge = 0.0;
      for (final enemy in _enemies) {
        _spawnExplosion(enemy.x, enemy.y, _kNeonCyan);
        _score += 150 * _difficultyTier;
        _earnedTokens += 5 * _difficultyTier;
      }
      _enemies.clear();
      if (_activeBoss != null) {
        _activeBoss!.hp -= 50;
        _spawnExplosion(_activeBoss!.x, _activeBoss!.y, _kNeonPurple);
      }
    });
  }

  void _triggerSlowMotion() {
    if (!_isPlaying || _gameOver || _matrixSlowMoActive) return;
    HapticFeedback.mediumImpact();
    GameSoundService().playMagic();
    setState(() => _matrixSlowMoActive = true);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _matrixSlowMoActive = false);
    });
  }

  void _spawnExplosion(double x, double y, Color color) {
    for (var i = 0; i < 16; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.006 + _rng.nextDouble() * 0.018;
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: color,
        life: 1.0,
      ));
    }
  }

  void _shootLaser() {
    if (!_isPlaying || _gameOver) return;
    HapticFeedback.lightImpact();
    GameSoundService().playLaser();
    setState(() {
      if (_selectedWeapon == 0) {
        // Dual Plasma
        _lasers.add(Offset(_playerX - 0.03, _playerY - 0.05));
        _lasers.add(Offset(_playerX + 0.03, _playerY - 0.05));
      } else if (_selectedWeapon == 1) {
        // Spread Shot
        _lasers.add(Offset(_playerX, _playerY - 0.05));
        _lasers.add(Offset(_playerX - 0.06, _playerY - 0.04));
        _lasers.add(Offset(_playerX + 0.06, _playerY - 0.04));
      } else {
        // Hyper Beam
        _lasers.add(Offset(_playerX, _playerY - 0.06));
      }
    });
  }

  void _hitTarget(_Target target) {
    if (!_isPlaying || _gameOver) return;
    HapticFeedback.selectionClick();
    GameSoundService().playSniper();
    setState(() {
      if (target.isHostile) {
        _score += (250 * _difficultyTier) + (_combo * 30);
        _combo++;
        _earnedTokens += 3 * _difficultyTier;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _spawnExplosion(target.x, target.y, _kNeonCyan);
        if (_score >= 3500) {
          _endGame(true);
        }
      } else {
        // Hit civilian decoy!
        _health -= 25;
        _combo = 0;
        _spawnExplosion(target.x, target.y, Colors.redAccent);
        HapticFeedback.vibrate();
        GameSoundService().playLose();
        if (_health <= 0) _endGame(false);
      }
      _targets.remove(target);
    });
  }

  // ── PUZZLE CYBER MATRIX HACK GAME ──────────────────────────────────────────
  void _startPuzzleLevel() async {
    _sequencePattern.add(_rng.nextInt(4));
    _playerInput.clear();
    _showingSequence = true;

    for (final node in _sequencePattern) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _currentStep = node);
      HapticFeedback.lightImpact();
      GameSoundService().playTick();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _currentStep = -1);
    }
    setState(() => _showingSequence = false);
  }

  void _tapPuzzleNode(int index) {
    if (_showingSequence || !_isPlaying || _gameOver) return;
    HapticFeedback.selectionClick();
    GameSoundService().playTick();
    _playerInput.add(index);

    final currentIdx = _playerInput.length - 1;
    if (_playerInput[currentIdx] != _sequencePattern[currentIdx]) {
      _endGame(false);
      return;
    }

    if (_playerInput.length == _sequencePattern.length) {
      _score += (400 * _difficultyTier) + (_sequencePattern.length * 60);
      _combo++;
      _earnedTokens += 10 * _difficultyTier;
      _firewallLevel++;
      GameSoundService().playCoin();

      if (_sequencePattern.length >= (6 + _difficultyTier * 2)) {
        _endGame(true);
      } else {
        _startPuzzleLevel();
      }
    }
  }

  void _endGame(bool won) {
    _gameLoop.stop();
    HapticFeedback.heavyImpact();
    if (won) {
      GameSoundService().playWin();
    } else {
      GameSoundService().playLose();
    }

    // Reward tokens to user
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final totalReward = _earnedTokens + (won ? (100 * _difficultyTier) : 0);
    if (totalReward > 0) {
      tokenProvider.addTokens(totalReward);
    }

    setState(() {
      _isPlaying = false;
      _gameOver = true;
      _gameWon = won;
      _earnedTokens = totalReward;
      if (_score > _highScore) _highScore = _score;
    });
  }

  // ── BUILD UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final tokenProvider = Provider.of<TokenProvider>(context);

    return Scaffold(
      backgroundColor: _kDarkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        cat.name.toUpperCase(),
                        style: TextStyle(
                          color: cat.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                          shadows: [BoxShadow(color: cat.color, blurRadius: 10)],
                        ),
                      ),
                      Text(
                        'Difficulty: ${_difficultyTier == 1 ? 'Recruit (1x)' : (_difficultyTier == 2 ? 'Veteran (2.5x)' : 'Cyber Psycho (5x)')}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on, color: kNeonGreen, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${tokenProvider.balance}',
                              style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // HUD Stats Bar
            if (_isPlaying) _buildHUD(cat),

            // Interactive Game Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090E21),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cat.color.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: cat.color.withValues(alpha: 0.2), blurRadius: 20),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (_isPlaying) _buildActiveGameArea(cat),
                        if (!_isPlaying) _buildMenuOverlay(cat),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Controls
            if (_isPlaying && (cat.name.toLowerCase() == 'action' || cat.name.toLowerCase() == 'adventure'))
              _buildSpaceControls(),
            if (_isPlaying && (cat.name.toLowerCase() == 'thriller' || cat.name.toLowerCase() == 'horror'))
              _buildReflexControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD(GameCategory cat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Health & Shield
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text('HP: $_health%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.shield, color: Color(0xFF00E5FF), size: 14),
                  const SizedBox(width: 4),
                  Text('SHIELD: $_shield%', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          // Score & Combo
          Column(
            children: [
              Text('SCORE: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              if (_combo > 1)
                Text('${_combo}X COMBO 🔥', style: TextStyle(color: cat.color, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ),
          // Earned Tokens
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.generating_tokens, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text('+$_earnedTokens T', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGameArea(GameCategory cat) {
    final gameType = cat.name.toLowerCase();

    if (gameType == 'puzzle') {
      return _buildPuzzleArena();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (gameType == 'thriller' || gameType == 'horror') {
              final normX = details.localPosition.dx / constraints.maxWidth;
              final normY = details.localPosition.dy / constraints.maxHeight;
              for (var target in _targets.toList()) {
                final dx = target.x - normX;
                final dy = target.y - normY;
                if (dx * dx + dy * dy < 0.02) {
                  _hitTarget(target);
                  _targets.remove(target);
                  break;
                }
              }
            }
          },
          onPanUpdate: (details) {
            if (gameType == 'action' || gameType == 'adventure') {
              setState(() {
                _playerX = (_playerX + details.delta.dx / 300).clamp(0.05, 0.95);
                _playerY = (_playerY + details.delta.dy / 500).clamp(0.2, 0.95);
              });
            }
          },
          child: CustomPaint(
            painter: StarfighterCanvasPainter(
              playerX: _playerX,
              playerY: _playerY,
              lasers: _lasers,
              enemies: _enemies,
              particles: _particles,
              tokenDrops: _tokenDrops,
              targets: _targets,
              boss: _activeBoss,
              gameType: gameType,
              catColor: cat.color,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildPuzzleArena() {
    final nodeColors = [_kNeonGreen, _kNeonCyan, _kNeonPurple, _kNeonPink];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _showingSequence ? 'SYSTEM SCANNING SEQUENCE...' : 'BYPASS FIREWALL LEVEL $_firewallLevel',
            style: TextStyle(
              color: _showingSequence ? const Color(0xFFFF9800) : kNeonGreen,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(4, (index) {
              final isLit = _currentStep == index;
              return GestureDetector(
                onTap: () => _tapPuzzleNode(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isLit
                        ? nodeColors[index]
                        : nodeColors[index].withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLit ? Colors.white : nodeColors[index].withValues(alpha: 0.6),
                      width: isLit ? 3 : 1.5,
                    ),
                    boxShadow: isLit
                        ? [BoxShadow(color: nodeColors[index], blurRadius: 25, spreadRadius: 4)]
                        : [],
                  ),
                  child: Center(
                    child: Icon(
                      [Icons.security, Icons.lock, Icons.vpn_key, Icons.terminal][index],
                      color: isLit ? Colors.black : nodeColors[index],
                      size: 36,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOverlay(GameCategory cat) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _gameWon ? Icons.emoji_events_rounded : (_gameOver ? Icons.cancel_rounded : cat.icon),
              color: _gameWon ? const Color(0xFFFFD700) : (_gameOver ? Colors.redAccent : cat.color),
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              _gameWon ? 'MISSION VICTORY! 🏆' : (_gameOver ? 'CRITICAL FAILURE' : cat.name.toUpperCase()),
              style: TextStyle(
                color: _gameWon ? const Color(0xFFFFD700) : (_gameOver ? Colors.redAccent : Colors.white),
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            if (_gameOver || _gameWon) ...[
              Text('Final Score: $_score', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700)),
                ),
                child: Text(
                  'Tokens Earned: +$_earnedTokens T',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Difficulty Selector
            if (!_isPlaying) ...[
              const Text('SELECT DIFFICULTY', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDifficultyChip(1, 'Recruit (1x)'),
                  const SizedBox(width: 8),
                  _buildDifficultyChip(2, 'Veteran (2.5x)'),
                  const SizedBox(width: 8),
                  _buildDifficultyChip(3, 'Cyber Psycho (5x)'),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Start / Retry Button
            FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                _gameOver ? 'RETRY MISSION' : 'START GAME',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cat.color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(int tier, String label) {
    final isSelected = _difficultyTier == tier;
    return GestureDetector(
      onTap: () => setState(() => _difficultyTier = tier),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00B8F4).withValues(alpha: 0.3) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF00B8F4) : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Weapon Switch
          IconButton(
            onPressed: () {
              setState(() => _selectedWeapon = (_selectedWeapon + 1) % 3);
              HapticFeedback.selectionClick();
            },
            icon: Icon(
              [_selectedWeapon == 0 ? Icons.flash_on : (_selectedWeapon == 1 ? Icons.call_split : Icons.line_weight)][0],
              color: const Color(0xFF00E5FF),
            ),
            tooltip: 'Switch Weapon',
          ),
          // EMP Bomb
          ElevatedButton.icon(
            onPressed: _empBombCharge >= 100 ? _triggerEmpBomb : null,
            icon: const Icon(Icons.bolt, size: 16),
            label: Text(_empBombCharge >= 100 ? 'EMP BLAST' : '${_empBombCharge.round()}%'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
            ),
          ),
          // Shoot Laser
          GestureDetector(
            onTap: _shootLaser,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00B8F4), Color(0xFF22C55E)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0xFF00B8F4), blurRadius: 10)],
              ),
              child: const Text('FIRE LASERS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflexControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton.icon(
            onPressed: _matrixSlowMoActive ? null : _triggerSlowMotion,
            icon: const Icon(Icons.timelapse, size: 16),
            label: Text(_matrixSlowMoActive ? 'BULLET TIME' : 'SLOW-MO'),
            style: ElevatedButton.styleFrom(backgroundColor: _kNeonPurple),
          ),
          const Text('Tap Hostile Drones! Avoid Civilians', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Models & Custom Canvas Painter ──────────────────────────────────────────
class _Enemy {
  double x;
  double y;
  double speed;
  int type;
  int health;

  _Enemy({required this.x, required this.y, required this.speed, required this.type, required this.health});
}

class _Boss {
  double x;
  double y;
  int hp;
  int maxHp;
  String name;

  _Boss({required this.x, required this.y, required this.hp, required this.maxHp, required this.name});
}

class _TokenDrop {
  double x;
  double y;
  int value;
  bool collected;

  _TokenDrop({required this.x, required this.y, required this.value}) : collected = false;
}

class _Target {
  double x;
  double y;
  bool isHostile;
  double duration;
  double life;

  _Target({required this.x, required this.y, required this.isHostile, required this.duration}) : life = duration;
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;

  _Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.life});
}

class StarfighterCanvasPainter extends CustomPainter {
  final double playerX;
  final double playerY;
  final List<Offset> lasers;
  final List<_Enemy> enemies;
  final List<_Particle> particles;
  final List<_TokenDrop> tokenDrops;
  final List<_Target> targets;
  final _Boss? boss;
  final String gameType;
  final Color catColor;

  StarfighterCanvasPainter({
    required this.playerX,
    required this.playerY,
    required this.lasers,
    required this.enemies,
    required this.particles,
    required this.tokenDrops,
    required this.targets,
    required this.boss,
    required this.gameType,
    required this.catColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Space Starfighter & Enemies
    if (gameType == 'action' || gameType == 'adventure') {
      // Draw Lasers
      final laserPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 3;
      for (final l in lasers) {
        canvas.drawLine(Offset(l.dx * size.width, l.dy * size.height), Offset(l.dx * size.width, (l.dy - 0.04) * size.height), laserPaint);
      }

      // Draw Token Drops
      final tokenPaint = Paint()..color = const Color(0xFFFFD700);
      for (final drop in tokenDrops) {
        canvas.drawCircle(Offset(drop.x * size.width, drop.y * size.height), 8, tokenPaint);
      }

      // Draw Enemies
      for (final enemy in enemies) {
        final ep = Offset(enemy.x * size.width, enemy.y * size.height);
        final paint = Paint()..color = enemy.type == 0 ? Colors.redAccent : (enemy.type == 1 ? Colors.orangeAccent : Colors.purpleAccent);
        canvas.drawCircle(ep, 14, paint);
      }

      // Draw Boss
      if (boss != null) {
        final bp = Offset(boss!.x * size.width, boss!.y * size.height);
        final bossPaint = Paint()..color = const Color(0xFFFF0055);
        canvas.drawRect(Rect.fromCenter(center: bp, width: 90, height: 40), bossPaint);

        // Boss Health Bar
        final hpWidth = 80.0 * (boss!.hp / boss!.maxHp);
        canvas.drawRect(Rect.fromLTWH(bp.dx - 40, bp.dy - 30, 80, 6), Paint()..color = Colors.white24);
        canvas.drawRect(Rect.fromLTWH(bp.dx - 40, bp.dy - 30, hpWidth, 6), Paint()..color = Colors.redAccent);
      }

      // Draw Player Ship
      final pp = Offset(playerX * size.width, playerY * size.height);
      final shipPaint = Paint()..color = catColor;
      final path = Path()
        ..moveTo(pp.dx, pp.dy - 18)
        ..lineTo(pp.dx - 16, pp.dy + 16)
        ..lineTo(pp.dx + 16, pp.dy + 16)
        ..close();
      canvas.drawPath(path, shipPaint);
    }

    // 2. Thriller / Horror Targets
    if (gameType == 'thriller' || gameType == 'horror') {
      for (final t in targets) {
        final tp = Offset(t.x * size.width, t.y * size.height);
        final paint = Paint()..color = t.isHostile ? Colors.redAccent : const Color(0xFF00E5FF);
        canvas.drawCircle(tp, 22, paint);
        canvas.drawCircle(tp, 8, Paint()..color = Colors.white);
      }
    }

    // 3. Particles
    for (final p in particles) {
      final pp = Offset(p.x * size.width, p.y * size.height);
      final paint = Paint()..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0));
      canvas.drawCircle(pp, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfighterCanvasPainter oldDelegate) => true;
}
