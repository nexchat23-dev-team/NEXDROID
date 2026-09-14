import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/cyber_3d_engine.dart';
import '../services/game_sound_service.dart';

class CyberStarfighter3DGame extends StatefulWidget {
  static const routeName = '/hyper-void-3d';
  const CyberStarfighter3DGame({super.key});

  @override
  State<CyberStarfighter3DGame> createState() => _CyberStarfighter3DGameState();
}

class _CyberStarfighter3DGameState extends State<CyberStarfighter3DGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gameTicker;
  DateTime _lastFrameTime = DateTime.now();

  // 3D Engine Systems
  late final Camera3D _camera;
  late final Mesh3D _playerShip;
  final List<Mesh3D> _worldMeshes = [];
  final List<Laser3D> _lasers = [];
  final List<Particle3D> _particles = [];

  // Flight Physics & Control State
  double _shipTargetPitch = 0.0;
  double _shipTargetRoll = 0.0;
  double _targetX = 0.0;
  double _targetY = 0.0;
  bool _isBoosting = false;
  double _boostEnergy = 100.0;
  bool _isFiring = false;
  double _fireCooldown = 0.0;
  int _missileCount = 3;
  double _missileRecharge = 0.0;

  // Gyro Controls
  bool _gyroEnabled = false;
  StreamSubscription<AccelerometerEvent>? _gyroSub;

  // Combat & Game State
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isVictory = false;
  int _score = 0;
  int _highScore = 0;
  int _comboMultiplier = 1;
  double _comboTimer = 0.0;
  double _playerShield = 100.0;
  final double _maxShield = 100.0;
  int _currentWave = 1;
  double _waveTimer = 0.0;
  double _gridOffsetZ = 0.0;

  // Boss Battle State
  Mesh3D? _bossMesh;
  double _bossHealth = 0.0;
  final double _bossMaxHealth = 1500.0;
  bool _bossSpawned = false;
  double _bossAttackTimer = 0.0;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _initEngine();
    _loadHighScore();
    _gameTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _gameTicker.addListener(_gameLoop);
  }

  void _initEngine() {
    // Camera situated slightly behind and above player starfighter
    _camera = Camera3D(
      position: Vector3D(0, 14, -48),
      fov: math.pi / 2.8,
      near: 2.0,
      far: 1800.0,
    );

    _playerShip = Mesh3D.createStarfighter(
      id: 'player',
      mainColor: const Color(0xFF0066FF),
      wingColor: const Color(0xFF00E5FF),
      cockpitColor: const Color(0xFFFFD700),
    );
    _playerShip.position = Vector3D(0, 0, 0);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('hyper_void_3d_highscore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (_score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hyper_void_3d_highscore', _score);
      setState(() {
        _highScore = _score;
      });
    }
  }

  void _startGyro() {
    _gyroSub = accelerometerEventStream().listen((event) {
      if (!_gyroEnabled || !_isPlaying) return;
      setState(() {
        _targetX = (-event.x * 6.0).clamp(-28.0, 28.0);
        _targetY = ((-event.y + 4.5) * 4.0).clamp(-18.0, 22.0);
      });
    }, onError: (_) {});
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isVictory = false;
      _score = 0;
      _comboMultiplier = 1;
      _comboTimer = 0.0;
      _playerShield = 100.0;
      _boostEnergy = 100.0;
      _currentWave = 1;
      _waveTimer = 0.0;
      _worldMeshes.clear();
      _lasers.clear();
      _particles.clear();
      _bossMesh = null;
      _bossSpawned = false;
      _playerShip.position = Vector3D(0, 0, 0);
    });

    _spawnWave(1);
    GameSoundService().playHyperspace();
  }

  void _spawnWave(int wave) {
    _currentWave = wave;

    if (wave == 3) {
      // WAVE 3: Boss Dreadnought Encounter
      _spawnBoss();
      return;
    }

    // Normal Waves: Interceptors + Asteroids
    final enemyCount = 4 + wave * 2;
    for (int i = 0; i < enemyCount; i++) {
      final interceptor = Mesh3D.createInterceptor(
        id: 'enemy_${wave}_$i',
        color: wave == 1 ? const Color(0xFFFF2244) : const Color(0xFFFF00CC),
      );
      interceptor.position = Vector3D(
        (_rng.nextDouble() - 0.5) * 90.0,
        (_rng.nextDouble() - 0.5) * 40.0 + 10.0,
        350.0 + i * 80.0,
      );
      interceptor.velocity = Vector3D(
        (_rng.nextDouble() - 0.5) * 15.0,
        (_rng.nextDouble() - 0.5) * 8.0,
        -40.0 - wave * 12.0,
      );
      _worldMeshes.add(interceptor);
    }

    // Add tumbling Asteroids
    for (int i = 0; i < 3 + wave; i++) {
      final asteroid = Mesh3D.createAsteroid(
        id: 'asteroid_${wave}_$i',
        radius: 12.0 + _rng.nextDouble() * 14.0,
        seed: i * 37 + wave,
      );
      asteroid.position = Vector3D(
        (_rng.nextDouble() - 0.5) * 120.0,
        (_rng.nextDouble() - 0.5) * 50.0 + 5.0,
        300.0 + i * 110.0,
      );
      asteroid.velocity = Vector3D(0, 0, -35.0);
      _worldMeshes.add(asteroid);
    }
  }

  void _spawnBoss() {
    _bossSpawned = true;
    _bossHealth = _bossMaxHealth;
    _bossMesh = Mesh3D.createDreadnought(id: 'boss');
    _bossMesh!.position = Vector3D(0, 15, 600);
    _bossMesh!.velocity = Vector3D(0, 0, -18.0);
    _worldMeshes.add(_bossMesh!);

    GameSoundService().playAlienBeam();
    HapticFeedback.heavyImpact();
  }

  void _gameLoop() {
    if (!_isPlaying || _isGameOver || _isVictory) return;

    final now = DateTime.now();
    final dt = (now.difference(_lastFrameTime).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastFrameTime = now;

    setState(() {
      _updatePlayer(dt);
      _updateLasers(dt);
      _updateEnemies(dt);
      _updateParticles(dt);
      _checkCollisions();
      _updateCombatState(dt);
    });
  }

  void _updatePlayer(double dt) {
    // Smooth interpolations to target position
    final speed = _isBoosting ? 90.0 : 45.0;
    _playerShip.position.x += (_targetX - _playerShip.position.x) * 8.0 * dt;
    _playerShip.position.y += (_targetY - _playerShip.position.y) * 8.0 * dt;

    // Banking rolls and pitch based on movement
    final targetRoll = -(_targetX - _playerShip.position.x) * 0.08;
    final targetPitch = (_targetY - _playerShip.position.y) * 0.06;

    _shipTargetRoll += (targetRoll - _shipTargetRoll) * 10.0 * dt;
    _shipTargetPitch += (targetPitch - _shipTargetPitch) * 10.0 * dt;

    _playerShip.rotation = Vector3D(
      _shipTargetPitch.clamp(-0.45, 0.45),
      0,
      _shipTargetRoll.clamp(-0.75, 0.75),
    );

    // Boost consumption and recharge
    if (_isBoosting && _boostEnergy > 0) {
      _boostEnergy = (_boostEnergy - dt * 35.0).clamp(0.0, 100.0);
      _camera.shake = 0.35;
      if (_boostEnergy <= 0) _isBoosting = false;
    } else {
      _boostEnergy = (_boostEnergy + dt * 18.0).clamp(0.0, 100.0);
      _camera.shake = (_camera.shake - dt * 2.0).clamp(0.0, 1.0);
    }

    // Grid scrolling speed
    _gridOffsetZ += speed * dt * 4.0;

    // Auto-fire handling
    if (_isFiring) {
      _fireCooldown -= dt;
      if (_fireCooldown <= 0) {
        _fireLasers();
        _fireCooldown = 0.12;
      }
    } else {
      _fireCooldown = 0.0;
    }

    // Missile recharge
    if (_missileCount < 3) {
      _missileRecharge += dt;
      if (_missileRecharge >= 6.0) {
        _missileCount++;
        _missileRecharge = 0.0;
        GameSoundService().playCoin();
      }
    }

    // Shield auto-regeneration
    if (_playerShield < _maxShield) {
      _playerShield = (_playerShield + dt * 4.0).clamp(0.0, _maxShield);
    }
  }

  void _fireLasers() {
    // Dual Wingtip Lasers
    final p = _playerShip.position;
    final leftLaser = Laser3D(
      position: Vector3D(p.x - 7.0, p.y - 0.5, p.z + 12.0),
      velocity: Vector3D(0, 0, 480.0),
      color: const Color(0xFF00FFFF),
      damage: 35.0,
    );
    final rightLaser = Laser3D(
      position: Vector3D(p.x + 7.0, p.y - 0.5, p.z + 12.0),
      velocity: Vector3D(0, 0, 480.0),
      color: const Color(0xFF00FFFF),
      damage: 35.0,
    );

    _lasers.add(leftLaser);
    _lasers.add(rightLaser);

    GameSoundService().playLaser();
    HapticFeedback.lightImpact();
  }

  void _fireMissile() {
    if (_missileCount <= 0) return;
    _missileCount--;

    // Target closest enemy
    Mesh3D? bestTarget;
    double bestDist = 9999.0;
    for (final mesh in _worldMeshes) {
      if (mesh.position.z > _playerShip.position.z + 10) {
        final d = _playerShip.position.distanceTo(mesh.position);
        if (d < bestDist) {
          bestDist = d;
          bestTarget = mesh;
        }
      }
    }

    Vector3D targetDir = Vector3D(0, 0, 1);
    if (bestTarget != null) {
      targetDir = (bestTarget.position - _playerShip.position).normalized();
    }

    final missile = Laser3D(
      position: _playerShip.position + Vector3D(0, -2, 8),
      velocity: targetDir * 320.0,
      length: 36.0,
      color: const Color(0xFFFFD700),
      damage: 250.0,
    );
    _lasers.add(missile);

    GameSoundService().playSniper();
    HapticFeedback.mediumImpact();
  }

  void _triggerBarrelRoll() {
    _shipTargetRoll += math.pi * 2;
    _playerShield = (_playerShield + 15.0).clamp(0.0, _maxShield);
    _camera.shake = 0.25;
    GameSoundService().playSlash();
  }

  void _updateLasers(double dt) {
    _lasers.removeWhere((laser) {
      final alive = laser.update(dt);
      return !alive || laser.position.z > 1200 || laser.position.z < -60;
    });
  }

  void _updateEnemies(double dt) {
    // Update non-player meshes
    for (final mesh in _worldMeshes) {
      mesh.position = mesh.position + mesh.velocity * dt;

      // Tumbling rotation for asteroids
      if (mesh.id.startsWith('asteroid')) {
        mesh.rotation.x += dt * 0.8;
        mesh.rotation.y += dt * 1.2;
      }

      // Interceptors weave in 3D
      if (mesh.id.startsWith('enemy')) {
        mesh.rotation.z = math.sin(mesh.position.z * 0.05) * 0.4;
        // Enemy firing logic
        if (_rng.nextDouble() < 0.015 && mesh.position.z > 80 && mesh.position.z < 400) {
          final dir = (_playerShip.position - mesh.position).normalized();
          _lasers.add(Laser3D(
            position: mesh.position.copy(),
            velocity: dir * 180.0,
            color: const Color(0xFFFF0055),
            damage: 15.0,
            isEnemy: true,
          ));
        }
      }

      // Boss special attacks
      if (mesh.id == 'boss') {
        // Slow advance and stop at distance 240
        if (mesh.position.z > 240) {
          mesh.velocity.z = -25.0;
        } else {
          mesh.velocity.z = math.sin(DateTime.now().millisecondsSinceEpoch * 0.001) * 8.0;
          mesh.position.x = math.sin(DateTime.now().millisecondsSinceEpoch * 0.0008) * 45.0;
        }

        _bossAttackTimer += dt;
        if (_bossAttackTimer > 1.8) {
          _bossAttackTimer = 0;
          _fireBossBarrage(mesh.position);
        }
      }
    }

    // Respawn or remove passed enemies
    _worldMeshes.removeWhere((mesh) {
      if (mesh.id != 'boss' && mesh.position.z < -40) {
        return true;
      }
      return false;
    });

    // Check Wave Completion
    if (!_bossSpawned && _worldMeshes.isEmpty) {
      _waveTimer += dt;
      if (_waveTimer > 2.0) {
        _waveTimer = 0.0;
        _spawnWave(_currentWave + 1);
        GameSoundService().playWin();
      }
    }
  }

  void _fireBossBarrage(Vector3D bossPos) {
    // 3-Way Spread Plasma Cannon
    for (int i = -1; i <= 1; i++) {
      final dir = Vector3D(i * 0.25, -0.05, -1.0).normalized();
      _lasers.add(Laser3D(
        position: bossPos + Vector3D(i * 30.0, 0, -20),
        velocity: dir * 210.0,
        length: 32.0,
        color: const Color(0xFFFF2244),
        damage: 25.0,
        isEnemy: true,
      ));
    }
    GameSoundService().playSuperLaser();
  }

  void _updateParticles(double dt) {
    _particles.removeWhere((p) => !p.update(dt));
  }

  void _spawnExplosion(Vector3D pos, Color color, {int count = 28}) {
    for (int i = 0; i < count; i++) {
      final dir = Vector3D(
        (_rng.nextDouble() - 0.5) * 2.0,
        (_rng.nextDouble() - 0.5) * 2.0,
        (_rng.nextDouble() - 0.5) * 2.0,
      ).normalized();
      final speed = 40.0 + _rng.nextDouble() * 110.0;

      _particles.add(Particle3D(
        position: pos.copy(),
        velocity: dir * speed,
        size: 2.5 + _rng.nextDouble() * 3.5,
        life: 0.6 + _rng.nextDouble() * 0.6,
        color: i % 2 == 0 ? color : Colors.white,
      ));
    }
    GameSoundService().playExplosion();
    _camera.shake = 0.45;
  }

  void _checkCollisions() {
    final List<Laser3D> lasersToRemove = [];
    final List<Mesh3D> meshesToRemove = [];

    for (final laser in _lasers) {
      if (laser.isEnemy) {
        // Test hit against player
        final d = laser.position.distanceTo(_playerShip.position);
        if (d < 16.0) {
          lasersToRemove.add(laser);
          _playerShield -= laser.damage;
          _spawnExplosion(laser.position, const Color(0xFFFF2244), count: 12);
          HapticFeedback.heavyImpact();

          if (_playerShield <= 0) {
            _onGameOver();
            return;
          }
        }
      } else {
        // Player laser hitting enemies
        for (final mesh in _worldMeshes) {
          final hitRadius = mesh.id == 'boss' ? 70.0 : (mesh.id.startsWith('asteroid') ? 22.0 : 18.0);
          final d = laser.position.distanceTo(mesh.position);

          if (d < hitRadius) {
            lasersToRemove.add(laser);

            if (mesh.id == 'boss') {
              _bossHealth -= laser.damage;
              _spawnExplosion(laser.position, const Color(0xFFFF2244), count: 8);

              if (_bossHealth <= 0) {
                meshesToRemove.add(mesh);
                _spawnExplosion(mesh.position, const Color(0xFFFFD700), count: 80);
                _score += 15000 * _comboMultiplier;
                _onVictory();
                return;
              }
            } else {
              meshesToRemove.add(mesh);
              _spawnExplosion(mesh.position, const Color(0xFF00E5FF), count: 32);
              _score += (mesh.id.startsWith('asteroid') ? 150 : 350) * _comboMultiplier;
              _incrementCombo();
            }
            break;
          }
        }
      }
    }

    _lasers.removeWhere((l) => lasersToRemove.contains(l));
    _worldMeshes.removeWhere((m) => meshesToRemove.contains(m));
  }

  void _incrementCombo() {
    _comboMultiplier = (_comboMultiplier + 1).clamp(1, 8);
    _comboTimer = 3.5;
  }

  void _updateCombatState(double dt) {
    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) {
        _comboMultiplier = 1;
      }
    }
  }

  void _onGameOver() {
    _isPlaying = false;
    _isGameOver = true;
    _spawnExplosion(_playerShip.position, const Color(0xFFFF0055), count: 60);
    _saveHighScore();
    GameSoundService().playLose();
  }

  void _onVictory() {
    _isPlaying = false;
    _isVictory = true;
    _saveHighScore();
    GameSoundService().playWin();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _gameTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Core 3D Render Canvas (Touch-to-steer)
          GestureDetector(
            onPanStart: (details) => _onPan(details.localPosition, size),
            onPanUpdate: (details) => _onPan(details.localPosition, size),
            child: Positioned.fill(
              child: CustomPaint(
                painter: Engine3DPainter(
                  camera: _camera,
                  meshes: [_playerShip, ..._worldMeshes],
                  lasers: _lasers,
                  particles: _particles,
                  drawGrid: true,
                  gridOffsetZ: _gridOffsetZ,
                  gridColor: _bossSpawned ? const Color(0xFFFF0055) : const Color(0xFF00E5FF),
                ),
              ),
            ),
          ),

          // 2. Sci-Fi Fighter Cockpit HUD
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CockpitReticleHUDPainter(
                  playerShip: _playerShip,
                  worldMeshes: _worldMeshes,
                  camera: _camera,
                ),
              ),
            ),
          ),

          // 3. Top Flight Deck Telemetry
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _buildTopFlightHUD(),
          ),

          // 4. Boss Health Bar (when active)
          if (_bossSpawned && _bossMesh != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 32,
              right: 32,
              child: _buildBossHealthBar(),
            ),

          // 5. On-Screen Action Flight Controls
          if (_isPlaying)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: _buildFlightActionControls(),
            ),

          // 6. Pre-Game Start / Game Over / Victory Modal
          if (!_isPlaying)
            Positioned.fill(
              child: _buildOverlayModal(),
            ),
        ],
      ),
    );
  }

  void _onPan(Offset localPos, Size size) {
    if (!_isPlaying) return;
    final nx = ((localPos.dx / size.width) - 0.5) * 2.0;
    final ny = ((localPos.dy / size.height) - 0.5) * 2.0;

    setState(() {
      _targetX = nx * 32.0;
      _targetY = -ny * 22.0;
    });
  }

  Widget _buildTopFlightHUD() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Exit / Back
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
        ),

        // Shield & Boost Indicators
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Shield Meter
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF00E5FF), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_playerShield / _maxShield).clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          color: _playerShield > 30 ? const Color(0xFF00E5FF) : Colors.redAccent,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_playerShield.toInt()}%',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Boost Meter
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_boostEnergy / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          color: const Color(0xFFFFD700),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_boostEnergy.toInt()}%',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Score & Combo Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SCORE: $_score',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'monospace'),
              ),
              if (_comboMultiplier > 1)
                Text(
                  '${_comboMultiplier}X MULTIPLIER',
                  style: const TextStyle(color: Color(0xFFFF00CC), fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBossHealthBar() {
    final pct = (_bossHealth / _bossMaxHealth).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DREADNOUGHT MOTHERSHIP',
                style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              color: Colors.redAccent,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightActionControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Barrel Roll & Gyro Toggle
        Row(
          children: [
            // Barrel Roll
            FilledButton(
              onPressed: _triggerBarrelRoll,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(18),
              ),
              child: const Icon(Icons.sync_rounded, size: 26),
            ),
            const SizedBox(width: 10),
            // Gyro Toggle
            IconButton.filled(
              onPressed: () {
                setState(() {
                  _gyroEnabled = !_gyroEnabled;
                  if (_gyroEnabled && _gyroSub == null) _startGyro();
                });
              },
              icon: Icon(
                _gyroEnabled ? Icons.screen_rotation_rounded : Icons.screen_lock_rotation_rounded,
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: _gyroEnabled ? const Color(0xFF00FF66).withValues(alpha: 0.3) : Colors.white10,
                foregroundColor: _gyroEnabled ? const Color(0xFF00FF66) : Colors.white60,
              ),
            ),
          ],
        ),

        // Right: Overdrive Boost, Missile Lock, & Laser Cannons
        Row(
          children: [
            // Overdrive Boost
            GestureDetector(
              onTapDown: (_) => setState(() => _isBoosting = true),
              onTapUp: (_) => setState(() => _isBoosting = false),
              onTapCancel: () => setState(() => _isBoosting = false),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBoosting
                      ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFFD700), size: 26),
              ),
            ),
            const SizedBox(width: 14),

            // Homing Missile
            GestureDetector(
              onTap: _fireMissile,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _missileCount > 0
                      ? const Color(0xFFFF00CC).withValues(alpha: 0.3)
                      : Colors.white10,
                  border: Border.all(
                    color: _missileCount > 0 ? const Color(0xFFFF00CC) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: Color(0xFFFF00CC), size: 26),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Text(
                        '$_missileCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Laser Fire (Hold or Tap)
            GestureDetector(
              onTapDown: (_) {
                setState(() => _isFiring = true);
                _fireLasers();
              },
              onTapUp: (_) => setState(() => _isFiring = false),
              onTapCancel: () => setState(() => _isFiring = false),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.flare_rounded, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverlayModal() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF030712),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isVictory
                ? const Color(0xFFFFD700)
                : (_isGameOver ? Colors.redAccent : const Color(0xFF00E5FF)),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isVictory ? const Color(0xFFFFD700) : const Color(0xFF00E5FF))
                  .withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isVictory
                  ? 'GALAXY LIBERATED!'
                  : (_isGameOver ? 'VESSEL DESTROYED' : 'HYPER-VOID 3D'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: _isVictory
                    ? const Color(0xFFFFD700)
                    : (_isGameOver ? Colors.redAccent : const Color(0xFF00E5FF)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isVictory
                  ? 'THE DREADNOUGHT HAS FALLEN'
                  : (_isGameOver ? 'MISSION FAILED' : 'TRUE 3D VECTOR SPACE DOGFIGHT'),
              style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SCORE:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text('$_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('RECORD:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text('$_highScore', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _isGameOver || _isVictory ? 'ENGAGE AGAIN' : 'LAUNCH STARFIGHTER',
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic 3D Target Reticle & Cockpit HUD Custom Painter
class _CockpitReticleHUDPainter extends CustomPainter {
  final Mesh3D playerShip;
  final List<Mesh3D> worldMeshes;
  final Camera3D camera;

  _CockpitReticleHUDPainter({
    required this.playerShip,
    required this.worldMeshes,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double focalLength = (size.width / 2) / math.tan(camera.fov / 2);
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Center Flight Crosshair
    final crosshairPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 18, crosshairPaint);
    canvas.drawLine(Offset(center.dx - 28, center.dy), Offset(center.dx - 8, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx + 8, center.dy), Offset(center.dx + 28, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 28), Offset(center.dx, center.dy - 8), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy + 8), Offset(center.dx, center.dy + 28), crosshairPaint);

    // 2. 3D Enemy Lock-On Reticles Projected to Screen Space
    final lockPaint = Paint()
      ..color = const Color(0xFFFF2244).withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final mesh in worldMeshes) {
      if (mesh.position.z <= camera.position.z + 10) continue;

      var p = mesh.position - camera.position;
      p = p.rotateY(-camera.yaw);
      p = p.rotateX(-camera.pitch);
      p = p.rotateZ(-camera.roll);

      if (p.z <= camera.near) continue;

      final factor = focalLength / p.z;
      final sx = center.dx + p.x * factor;
      final sy = center.dy - p.y * factor;

      if (sx >= -40 && sx <= size.width + 40 && sy >= -40 && sy <= size.height + 40) {
        final boxSize = (1600.0 / p.z).clamp(16.0, 48.0);
        final rect = Rect.fromCenter(center: Offset(sx, sy), width: boxSize, height: boxSize);

        // Draw corner brackets
        final d = boxSize * 0.3;
        // Top-Left
        canvas.drawLine(rect.topLeft, Offset(rect.left + d, rect.top), lockPaint);
        canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + d), lockPaint);
        // Top-Right
        canvas.drawLine(rect.topRight, Offset(rect.right - d, rect.top), lockPaint);
        canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + d), lockPaint);
        // Bottom-Left
        canvas.drawLine(rect.bottomLeft, Offset(rect.left + d, rect.bottom), lockPaint);
        canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - d), lockPaint);
        // Bottom-Right
        canvas.drawLine(rect.bottomRight, Offset(rect.right - d, rect.bottom), lockPaint);
        canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - d), lockPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CockpitReticleHUDPainter oldDelegate) => true;
}
