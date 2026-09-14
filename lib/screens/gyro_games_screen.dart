import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

enum Difficulty { easy, medium, hard }

class _GameMeta {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int tokenPrice;
  final Widget Function(int highScore) builder;
  const _GameMeta({required this.id, required this.name, required this.description, required this.icon, required this.color, required this.tokenPrice, required this.builder});
}

class GyroGameLauncher extends StatefulWidget {
  const GyroGameLauncher({super.key});
  @override
  State<GyroGameLauncher> createState() => _GyroGameLauncherState();
}

class _GyroGameLauncherState extends State<GyroGameLauncher> {
  final Map<String, int> _highScores = {};
  int _totalGamesPlayed = 0;
  late final List<_GameMeta> _games;

  @override
  void initState() {
    super.initState();
    _games = [
      _GameMeta(id: 'gyro_ball', name: 'Gyro Ball', description: 'Tilt to roll! Dodge neon walls.', icon: Icons.sports_soccer_rounded, color: kNeonGreen, tokenPrice: 2500, builder: (hs) => GyroBallGame(highScore: hs)),
      _GameMeta(id: 'space_tilt', name: 'Space Tilt', description: 'Pilot your ship by tilting. Destroy asteroids!', icon: Icons.rocket_rounded, color: kNeonBlue, tokenPrice: 3000, builder: (hs) => SpaceTiltGame(highScore: hs)),
      _GameMeta(id: 'gravity_flip', name: 'Gravity Flip', description: 'Tap to flip gravity, tilt to steer. Pass spike walls!', icon: Icons.swap_vert_rounded, color: Colors.purpleAccent, tokenPrice: 2000, builder: (hs) => GravityFlipGame(highScore: hs)),
      _GameMeta(id: 'nex_3d_shooter', name: 'NEX 3D Shooter', description: 'First-person gyro aiming. Tap to blast enemies!', icon: Icons.gps_fixed_rounded, color: Colors.redAccent, tokenPrice: 5000, builder: (hs) => Nex3DShooterGame(highScore: hs)),
      _GameMeta(id: 'orbit_drift', name: 'Orbit Drift 2D', description: 'Control orbit radius with tilt. Auto-fire enemies!', icon: Icons.blur_circular_rounded, color: Colors.orangeAccent, tokenPrice: 3500, builder: (hs) => OrbitDrift2DGame(highScore: hs)),
      _GameMeta(id: 'tilt_maze', name: 'Tilt Maze', description: 'Navigate a neon marble maze with tilt controls.', icon: Icons.grid_4x4_rounded, color: const Color(0xFF00E5FF), tokenPrice: 3000, builder: (hs) => TiltMazeGame(highScore: hs)),
      _GameMeta(id: 'wave_surfer', name: 'Wave Surfer', description: 'Tilt to steer a surfboard on waves. Dodge obstacles!', icon: Icons.surfing_rounded, color: const Color(0xFF0066FF), tokenPrice: 2000, builder: (hs) => WaveSurferGame(highScore: hs)),
      _GameMeta(id: 'crystal_collector', name: 'Crystal Collector', description: 'Catch falling gems, avoid toxic bubbles.', icon: Icons.diamond_rounded, color: const Color(0xFFFFD700), tokenPrice: 2500, builder: (hs) => CrystalCollectorGame(highScore: hs)),
      _GameMeta(id: 'thunder_racer', name: 'Thunder Racer', description: 'Top-down neon racing. Tilt to steer, avoid cars!', icon: Icons.electric_car_rounded, color: const Color(0xFFFF6600), tokenPrice: 3500, builder: (hs) => ThunderRacerGame(highScore: hs)),
    ];
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _totalGamesPlayed = prefs.getInt('total_games_played') ?? 0;
    for (final g in _games) _highScores[g.id] = prefs.getInt('hi_score_${g.id}') ?? 0;
    if (mounted) setState(() {});
  }

  void _launchGame(_GameMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_games_played', _totalGamesPlayed + 1);
    setState(() => _totalGamesPlayed++);
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a1, a2) => meta.builder(_highScores[meta.id] ?? 0),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
    _loadPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          ..._games.map((g) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildGameCard(g))),
        ],
      ),
    );
  }

  Widget _buildHeader() => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [kNeonGreen.withValues(alpha: 0.12), kNeonBlue.withValues(alpha: 0.08)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kNeonGreen.withValues(alpha: 0.3), kNeonBlue.withValues(alpha: 0.3)])),
            child: const Icon(Icons.screen_rotation_rounded, color: kNeonGreen, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GYRO ZONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.4)),
              const SizedBox(height: 4),
              const Text('Tilt your device to play real motion-controlled games', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
              const SizedBox(height: 4),
              Text('Total Games Played: $_totalGamesPlayed', style: const TextStyle(color: kNeonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          )),
        ]),
      ),
    ),
  );

  Widget _buildGameCard(_GameMeta meta) {
    final hi = _highScores[meta.id] ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
            border: Border.all(color: meta.color.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(shape: BoxShape.circle, color: meta.color.withValues(alpha: 0.15), border: Border.all(color: meta.color.withValues(alpha: 0.5))),
                child: Icon(meta.icon, color: meta.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(meta.description, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (hi > 0) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 13),
                      const SizedBox(width: 4),
                      Text(meta.id == 'tilt_maze' ? 'Best: ${hi/10}s' : 'Best: $hi', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ],
              )),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => _launchGame(meta),
                style: FilledButton.styleFrom(
                  backgroundColor: meta.color, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 1 — GYRO BALL
// ═══════════════════════════════════════════════════════════════════════════════
class GyroBallGame extends StatefulWidget {
  final int highScore;
  const GyroBallGame({super.key, required this.highScore});
  @override
  State<GyroBallGame> createState() => _GyroBallGameState();
}
class _GyroBallGameState extends State<GyroBallGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Offset _ball = const Offset(0.5, 0.5);
  Offset _velocity = Offset.zero;
  final List<Offset> _trail = [];
  int _score = 0;
  int _lives = 3;
  bool _gameOver = false;
  bool _started = false;
  double _ax = 0, _ay = 0;
  int _highScore = 0;
  bool _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;

  static const _walls = [
    (0.1, 0.2, 0.3, 0.2), (0.6, 0.15, 0.9, 0.15), (0.2, 0.5, 0.5, 0.5), (0.7, 0.4, 0.9, 0.55),
    (0.1, 0.7, 0.4, 0.7), (0.55, 0.75, 0.85, 0.75), (0.3, 0.35, 0.3, 0.65), (0.65, 0.25, 0.65, 0.55),
  ];

  @override
  void initState() {
    super.initState();
    _highScore = widget.highScore;
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick);
  }
  void _startGame() {
    _ball = const Offset(0.5, 0.5); _velocity = Offset.zero; _trail.clear();
    _score = 0; _lives = 3; _gameOver = false; _started = true; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) { _ax = e.x * -0.0015; _ay = e.y * 0.0015; });
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _velocity = Offset(_velocity.dx + _ax, _velocity.dy + _ay);
      _velocity = Offset(_velocity.dx * 0.92, _velocity.dy * 0.92);
      _ball = Offset((_ball.dx + _velocity.dx).clamp(0.02, 0.98), (_ball.dy + _velocity.dy).clamp(0.02, 0.98));
      _trail.add(_ball);
      if (_trail.length > 30) _trail.removeAt(0);
      double diffMult = _difficulty == Difficulty.easy ? 0.5 : (_difficulty == Difficulty.hard ? 2.0 : 1.0);
      _score = (_score + 1) ~/ (60 / diffMult) * (60 ~/ diffMult) == _score ? _score + 1 : _score + 0;

      bool hit = false;
      for (final w in _walls) {
        if ((_ball.dx - w.$3.clamp(w.$1, w.$3)).abs() < 0.03 && (_ball.dy - w.$4.clamp(w.$2, w.$4)).abs() < 0.03) { hit = true; break; }
      }
      if (hit) {
        _lives--; _ball = const Offset(0.5, 0.5); _velocity = Offset.zero; _trail.clear();
        if (_lives <= 0) _endGame();
      }
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) {
      _highScore = _score; _isNewRecord = true;
      (await SharedPreferences.getInstance()).setInt('hi_score_gyro_ball', _highScore);
    }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050D1A),
        title: Row(children: [
          const Icon(Icons.sports_soccer_rounded, color: kNeonGreen), const SizedBox(width: 8),
          const Text('GYRO BALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.w900)),
          const SizedBox(width: 16),
          ...List.generate(3, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 18)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('GYRO BALL', _score, _highScore, _isNewRecord, kNeonGreen, Icons.sports_soccer_rounded, _startGame, context) : Stack(
        children: [
          LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _GyroBallPainter(_ball, _trail, _walls), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('GYRO BALL', 'Tilt your device to roll the ball\nDodge the neon walls!', kNeonGreen, _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _GyroBallPainter extends CustomPainter {
  final Offset ball; final List<Offset> trail; final List<(double, double, double, double)> walls;
  _GyroBallPainter(this.ball, this.trail, this.walls);
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = kNeonBlue.withValues(alpha: 0.07)..strokeWidth = 0.5;
    for (var i = 0; i < 20; i++) {
      canvas.drawLine(Offset(size.width * i / 20, 0), Offset(size.width * i / 20, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * i / 20), Offset(size.width, size.height * i / 20), gridPaint);
    }
    final wallPaint = Paint()..color = Colors.redAccent.withValues(alpha: 0.7)..strokeWidth = 6..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final w in walls) canvas.drawLine(Offset(w.$1 * size.width, w.$2 * size.height), Offset(w.$3 * size.width, w.$4 * size.height), wallPaint);
    for (var i = 0; i < trail.length; i++) canvas.drawCircle(Offset(trail[i].dx * size.width, trail[i].dy * size.height), 4 * i / trail.length, Paint()..color = kNeonGreen.withValues(alpha: i / trail.length * 0.5));
    canvas.drawCircle(Offset(ball.dx * size.width, ball.dy * size.height), 18, Paint()..color = kNeonGreen.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(ball.dx * size.width, ball.dy * size.height), 10, Paint()..color = kNeonGreen);
  }
  @override
  bool shouldRepaint(covariant _GyroBallPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 2 — SPACE TILT
// ═══════════════════════════════════════════════════════════════════════════════
class SpaceTiltGame extends StatefulWidget {
  final int highScore;
  const SpaceTiltGame({super.key, required this.highScore});
  @override
  State<SpaceTiltGame> createState() => _SpaceTiltGameState();
}
class _SpaceTiltGameState extends State<SpaceTiltGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _shipY = 0.5;
  List<_Asteroid> _asteroids = [];
  List<_Laser> _lasers = [];
  int _score = 0;
  int _lives = 3;
  bool _gameOver = false;
  bool _started = false;
  double _accelY = 0;
  final _rng = Random();
  int _frameCount = 0;
  int _highScore = 0;
  bool _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    _highScore = widget.highScore;
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick);
  }
  void _startGame() {
    _shipY = 0.5; _asteroids = []; _lasers = []; _score = 0; _lives = 3;
    _gameOver = false; _started = true; _frameCount = 0; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _accelY = e.y * 0.012);
    _ticker.repeat();
    setState(() {});
  }
  void _fire() { if (_started && !_gameOver) _lasers.add(_Laser(x: 0.12, y: _shipY)); }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frameCount++;
      _shipY = (_shipY + _accelY).clamp(0.05, 0.95);
      for (final l in _lasers) l.x += 0.03;
      _lasers.removeWhere((l) => l.x > 1.1);
      double spawnRate = _difficulty == Difficulty.easy ? 60 : (_difficulty == Difficulty.hard ? 20 : 40);
      if (_frameCount % max(8, spawnRate - _score ~/ 20).toInt() == 0) {
        _asteroids.add(_Asteroid(x: 1.05, y: _rng.nextDouble() * 0.85 + 0.05, radius: _rng.nextDouble() * 0.04 + 0.03, speed: _rng.nextDouble() * 0.01 + 0.008, sides: 5 + _rng.nextInt(4)));
      }
      for (final a in _asteroids) a.x -= a.speed;
      final toRemoveLasers = <_Laser>{}; final toRemoveAsteroids = <_Asteroid>{};
      for (final l in _lasers) {
        for (final a in _asteroids) {
          if ((l.x - a.x).abs() < a.radius + 0.02 && (l.y - a.y).abs() < a.radius) { toRemoveLasers.add(l); toRemoveAsteroids.add(a); _score += 10; }
        }
      }
      _lasers.removeWhere(toRemoveLasers.contains); _asteroids.removeWhere(toRemoveAsteroids.contains);
      for (final a in _asteroids) {
        if ((a.x - 0.08).abs() < a.radius + 0.04 && (a.y - _shipY).abs() < a.radius + 0.06) {
          _lives--; _asteroids.remove(a);
          if (_lives <= 0) _endGame();
          break;
        }
      }
      _asteroids.removeWhere((a) => a.x < -0.1);
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_space_tilt', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020912),
        title: Row(children: [
          const Icon(Icons.rocket_rounded, color: kNeonBlue), const SizedBox(width: 8),
          const Text('SPACE TILT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: kNeonBlue, fontWeight: FontWeight.w900)),
          const SizedBox(width: 16),
          ...List.generate(3, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 18)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('SPACE TILT', _score, _highScore, _isNewRecord, kNeonBlue, Icons.rocket_rounded, _startGame, context) : GestureDetector(
        onTapDown: (_) => _fire(),
        child: Stack(
          children: [
            LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _SpaceTiltPainter(_shipY, _asteroids, _lasers), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
            if (!_started) Center(child: _gameStartPrompt('SPACE TILT', 'Tilt up/down to steer your ship\nTap to fire lasers!', kNeonBlue, _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
          ],
        ),
      ),
    );
  }
}
class _Asteroid { double x, y, speed, radius; int sides; _Asteroid({required this.x, required this.y, required this.radius, required this.speed, required this.sides}); }
class _Laser { double x, y; _Laser({required this.x, required this.y}); }
class _SpaceTiltPainter extends CustomPainter {
  final double shipY; final List<_Asteroid> asteroids; final List<_Laser> lasers;
  _SpaceTiltPainter(this.shipY, this.asteroids, this.lasers);
  @override
  void paint(Canvas canvas, Size size) {
    final starRng = Random(42); final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 80; i++) canvas.drawCircle(Offset(starRng.nextDouble() * size.width, starRng.nextDouble() * size.height), starRng.nextDouble() * 1.4 + 0.3, starPaint);
    final sx = size.width * 0.08, sy = size.height * shipY;
    final ship = Path()..moveTo(sx + 24, sy)..lineTo(sx - 12, sy - 14)..lineTo(sx - 6, sy)..lineTo(sx - 12, sy + 14)..close();
    canvas.drawPath(ship, Paint()..color = kNeonBlue..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(ship, Paint()..color = Colors.white);
    for (final l in lasers) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(l.x * size.width, l.y * size.height), width: 20, height: 4), const Radius.circular(2)), Paint()..color = kNeonGreen..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    for (final a in asteroids) {
      final center = Offset(a.x * size.width, a.y * size.height); final r = a.radius * size.width; final path = Path();
      for (var i = 0; i < a.sides; i++) {
        final angle = 2 * pi * i / a.sides; final ir = r * (0.7 + 0.3 * ((i * 1337) % 7) / 7);
        final p = Offset(center.dx + cos(angle) * ir, center.dy + sin(angle) * ir);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = Colors.deepOrangeAccent.withValues(alpha: 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(path, Paint()..color = Colors.orangeAccent..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }
  @override
  bool shouldRepaint(covariant _SpaceTiltPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 3 — GRAVITY FLIP
// ═══════════════════════════════════════════════════════════════════════════════
class GravityFlipGame extends StatefulWidget {
  final int highScore;
  const GravityFlipGame({super.key, required this.highScore});
  @override
  State<GravityFlipGame> createState() => _GravityFlipGameState();
}
class _GravityFlipGameState extends State<GravityFlipGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _ballX = 0.2, _ballY = 0.5, _vx = 0.008, _vy = 0, _gravity = 0.0008;
  bool _gravFlipped = false, _gameOver = false, _started = false, _isNewRecord = false;
  int _score = 0, _highScore = 0, _frameCount = 0;
  Difficulty _difficulty = Difficulty.medium;
  List<_Wall> _walls = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _highScore = widget.highScore;
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick);
  }
  void _startGame() {
    _ballX = 0.2; _ballY = 0.5; _vx = 0.008; _vy = 0; _gravFlipped = false; _score = 0;
    _gameOver = false; _started = true; _frameCount = 0; _walls = []; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _vx = (0.008 + e.x * 0.001).clamp(0.004, 0.015));
    _ticker.repeat();
    setState(() {});
  }
  void _flip() { setState(() => _gravFlipped = !_gravFlipped); }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frameCount++;
      _vy += _gravFlipped ? -_gravity : _gravity;
      _ballY = (_ballY + _vy).clamp(0.03, 0.97);
      int spawnRate = _difficulty == Difficulty.easy ? 100 : (_difficulty == Difficulty.hard ? 60 : 80);
      if (_frameCount % spawnRate == 0) {
        final gapY = _rng.nextDouble() * 0.4 + 0.2;
        final gapH = _difficulty == Difficulty.hard ? 0.18 : 0.25;
        _walls.add(_Wall(x: 1.05, topH: gapY - gapH / 2, botY: gapY + gapH / 2));
        _score++;
      }
      for (final w in _walls) w.x -= _vx;
      _walls.removeWhere((w) => w.x < -0.1);
      if (_ballY <= 0.03 || _ballY >= 0.97) { _endGame(); return; }
      for (final w in _walls) {
        if ((_ballX - w.x).abs() < 0.04 && (_ballY < w.topH || _ballY > w.botY)) { _endGame(); return; }
      }
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_gravity_flip', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08001A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08001A),
        title: Row(children: [
          const Icon(Icons.swap_vert_rounded, color: Colors.purpleAccent), const SizedBox(width: 8),
          const Text('GRAVITY FLIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w900)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('GRAVITY FLIP', _score, _highScore, _isNewRecord, Colors.purpleAccent, Icons.swap_vert_rounded, _startGame, context)
          : GestureDetector(
        onTapDown: (_) => _started ? _flip() : null,
        child: Stack(
          children: [
            LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _GravityFlipPainter(_ballX, _ballY, _walls, _gravFlipped), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
            if (!_started) Center(child: _gameStartPrompt('GRAVITY FLIP', 'TAP to flip gravity!\nNavigate through the spike walls', Colors.purpleAccent, _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
          ],
        ),
      ),
    );
  }
}
class _Wall { double x, topH, botY; _Wall({required this.x, required this.topH, required this.botY}); }
class _GravityFlipPainter extends CustomPainter {
  final double bx, by; final List<_Wall> walls; final bool flipped;
  _GravityFlipPainter(this.bx, this.by, this.walls, this.flipped);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF08001A), Color(0xFF1A003A)]).createShader(Offset.zero & size));
    final wallPaint = Paint()..color = Colors.purpleAccent.withValues(alpha: 0.85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (final w in walls) {
      final wx = w.x * size.width;
      canvas.drawRect(Rect.fromLTWH(wx - 8, 0, 16, w.topH * size.height), wallPaint);
      canvas.drawRect(Rect.fromLTWH(wx - 8, w.botY * size.height, 16, size.height), wallPaint);
    }
    final ballOff = Offset(bx * size.width, by * size.height);
    canvas.drawCircle(ballOff, 16, Paint()..color = Colors.purpleAccent.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(ballOff, 9, Paint()..color = Colors.white);
    canvas.drawCircle(ballOff, 9, Paint()..color = Colors.purpleAccent..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _GravityFlipPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 4 — NEX 3D SHOOTER
// ═══════════════════════════════════════════════════════════════════════════════
class Nex3DShooterGame extends StatefulWidget {
  final int highScore;
  const Nex3DShooterGame({super.key, required this.highScore});
  @override
  State<Nex3DShooterGame> createState() => _Nex3DShooterGameState();
}
class _Nex3DShooterGameState extends State<Nex3DShooterGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  List<_Enemy3D> _enemies = [];
  double _crosshairX = 0, _tiltX = 0;
  int _score = 0, _ammo = 30, _highScore = 0, _frameCount = 0;
  bool _gameOver = false, _started = false, _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;
  final _rng = Random();
  List<_Explosion> _explosions = [];

  @override
  void initState() {
    super.initState();
    _highScore = widget.highScore;
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick);
  }
  void _startGame() {
    _enemies = []; _score = 0; _ammo = 30; _gameOver = false; _started = true; _frameCount = 0; _tiltX = 0; _crosshairX = 0; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _tiltX = e.x);
    _ticker.repeat();
    setState(() {});
  }
  void _shoot() {
    if (!_started || _gameOver || _ammo <= 0) return;
    setState(() {
      _ammo--;
      final hit = _enemies.where((e) => (e.xOffset - _crosshairX).abs() < 0.1 + e.scale * 0.15).toList();
      if (hit.isNotEmpty) {
        final e = hit.first; _explosions.add(_Explosion(x: e.xOffset, scale: e.scale, frame: 0)); _enemies.remove(e); _score += (e.scale * 100).round();
      }
      if (_ammo <= 0 && _enemies.isEmpty) _endGame();
    });
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frameCount++;
      _crosshairX = (_crosshairX + _tiltX * -0.008).clamp(-0.5, 0.5);
      int spawnRate = _difficulty == Difficulty.easy ? 80 : (_difficulty == Difficulty.hard ? 40 : 60);
      if (_frameCount % spawnRate == 0) _enemies.add(_Enemy3D(xOffset: (_rng.nextDouble() - 0.5) * 0.8, scale: 0.01, speed: 0.003 + _score * 0.00001));
      for (final e in _enemies) { e.scale += e.speed; e.xOffset *= 1.005; }
      final hitPlayer = _enemies.where((e) => e.scale > 0.55).toList();
      for (final e in hitPlayer) {
        _enemies.remove(e); _ammo -= 5;
        if (_ammo <= 0) { _endGame(); return; }
      }
      for (final ex in _explosions) ex.frame++;
      _explosions.removeWhere((ex) => ex.frame > 20);
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_nex_3d_shooter', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000510),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000510),
        title: Row(children: [
          const Icon(Icons.gps_fixed_rounded, color: Colors.redAccent), const SizedBox(width: 8),
          const Text('NEX 3D SHOOTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 16),
          Text(' $_ammo', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('NEX 3D SHOOTER', _score, _highScore, _isNewRecord, Colors.redAccent, Icons.gps_fixed_rounded, _startGame, context)
          : GestureDetector(
        onTapDown: (_) => _started ? _shoot() : null,
        child: Stack(
          children: [
            LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _Shooter3DPainter(_enemies, _explosions, _crosshairX), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
            if (!_started) Center(child: _gameStartPrompt('NEX 3D SHOOTER', 'Tilt to aim • Tap to shoot!\nDon\'t let enemies reach you!', Colors.redAccent, _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
          ],
        ),
      ),
    );
  }
}
class _Enemy3D { double xOffset, scale, speed; _Enemy3D({required this.xOffset, required this.scale, required this.speed}); }
class _Explosion { double x, scale; int frame; _Explosion({required this.x, required this.scale, required this.frame}); }
class _Shooter3DPainter extends CustomPainter {
  final List<_Enemy3D> enemies; final List<_Explosion> explosions; final double crosshairX;
  _Shooter3DPainter(this.enemies, this.explosions, this.crosshairX);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000510));
    final gridP = Paint()..color = Colors.blueAccent.withValues(alpha: 0.12)..strokeWidth = 1;
    for (var i = -8; i <= 8; i++) canvas.drawLine(Offset(cx + i * 15, cy), Offset(i * 60.0 + cx, size.height), gridP);
    for (var i = 1; i <= 8; i++) { final t = i / 8; final y = cy + (size.height - cy) * t; final w = size.width * t; canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y), gridP); }
    for (final e in enemies) {
      final ex = cx + e.xOffset * size.width; final r = e.scale * size.height * 0.4; final danger = e.scale > 0.4;
      canvas.drawCircle(Offset(ex, cy), r * 1.3, Paint()..color = (danger ? Colors.redAccent : Colors.orangeAccent).withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
      canvas.drawCircle(Offset(ex, cy), r, Paint()..color = danger ? Colors.redAccent : Colors.deepOrangeAccent);
      canvas.drawCircle(Offset(ex, cy), r * 0.5, Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
    for (final ex in explosions) {
      final t = ex.frame / 20; final ep = Offset(cx + ex.x * size.width, cy);
      canvas.drawCircle(ep, ex.scale * size.height * 0.6 * t, Paint()..color = Colors.orange.withValues(alpha: 1 - t)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
    final chx = cx + crosshairX * size.width; final chPaint = Paint()..color = Colors.greenAccent..strokeWidth = 2;
    canvas.drawLine(Offset(chx - 20, cy), Offset(chx - 8, cy), chPaint); canvas.drawLine(Offset(chx + 8, cy), Offset(chx + 20, cy), chPaint);
    canvas.drawLine(Offset(chx, cy - 20), Offset(chx, cy - 8), chPaint); canvas.drawLine(Offset(chx, cy + 8), Offset(chx, cy + 20), chPaint);
    canvas.drawCircle(Offset(chx, cy), 5, Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _Shooter3DPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 5 — ORBIT DRIFT 2D
// ═══════════════════════════════════════════════════════════════════════════════
class OrbitDrift2DGame extends StatefulWidget {
  final int highScore;
  const OrbitDrift2DGame({super.key, required this.highScore});
  @override
  State<OrbitDrift2DGame> createState() => _OrbitDrift2DGameState();
}
class _OrbitDrift2DGameState extends State<OrbitDrift2DGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _orbitRadius = 0.25, _orbitAngle = 0, _health = 100, _tiltZ = 0;
  int _score = 0, _highScore = 0, _frameCount = 0;
  bool _gameOver = false, _started = false, _doubleShot = false, _hasShield = false, _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;
  List<_OrbEnemy> _enemies = []; List<_OrbBullet> _bullets = []; List<_OrbPowerUp> _powerUps = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _highScore = widget.highScore;
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick);
  }
  void _startGame() {
    _orbitRadius = 0.25; _orbitAngle = 0; _health = 100; _score = 0; _gameOver = false; _started = true; _frameCount = 0; _isNewRecord = false;
    _enemies = []; _bullets = []; _powerUps = []; _doubleShot = false; _hasShield = false;
    _accelSub = accelerometerEventStream().listen((e) => _tiltZ = e.z);
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frameCount++; _orbitAngle += 0.02; _orbitRadius = (_orbitRadius + _tiltZ * 0.001).clamp(0.08, 0.42);
      if (_frameCount % 30 == 0) {
        final bx = 0.5 + cos(_orbitAngle) * _orbitRadius; final by = 0.5 + sin(_orbitAngle) * _orbitRadius;
        _bullets.add(_OrbBullet(x: bx, y: by, vx: 0.03, vy: 0)); if (_doubleShot) _bullets.add(_OrbBullet(x: bx, y: by, vx: 0.03, vy: 0.01));
      }
      int spawnRate = _difficulty == Difficulty.easy ? 70 : (_difficulty == Difficulty.hard ? 30 : 50);
      if (_frameCount % spawnRate == 0) _enemies.add(_OrbEnemy(x: 1.05, y: _rng.nextDouble() * 0.8 + 0.1, speed: 0.006 + _score * 0.00005, hp: 2));
      if (_frameCount % 200 == 0) _powerUps.add(_OrbPowerUp(x: 1.05, y: _rng.nextDouble() * 0.8 + 0.1, type: _rng.nextBool() ? 'shield' : 'double'));
      for (final b in _bullets) { b.x += b.vx; b.y += b.vy; }
      _bullets.removeWhere((b) => b.x > 1.1);
      for (final e in _enemies) e.x -= e.speed;
      for (final p in _powerUps) p.x -= 0.005;
      _enemies.removeWhere((e) => e.x < -0.05); _powerUps.removeWhere((p) => p.x < -0.05);
      final killBullets = <_OrbBullet>{};
      for (final b in _bullets) {
        for (final e in _enemies) {
          if ((b.x - e.x).abs() < 0.05 && (b.y - e.y).abs() < 0.05) { killBullets.add(b); e.hp--; if (e.hp <= 0) { _score += 15; _enemies.remove(e); break; } }
        }
      }
      _bullets.removeWhere(killBullets.contains);
      final sx = 0.5 + cos(_orbitAngle) * _orbitRadius, sy = 0.5 + sin(_orbitAngle) * _orbitRadius;
      for (final e in _enemies) {
        if ((e.x - sx).abs() < 0.06 && (e.y - sy).abs() < 0.06) {
          if (!_hasShield) _health -= 10; _enemies.remove(e);
          if (_health <= 0) { _endGame(); return; } break;
        }
      }
      for (final p in _powerUps) {
        if ((p.x - sx).abs() < 0.06 && (p.y - sy).abs() < 0.06) {
          if (p.type == 'shield') _hasShield = true; if (p.type == 'double') _doubleShot = true;
          _powerUps.remove(p); break;
        }
      }
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_orbit_drift', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030D1E),
        title: Row(children: [
          const Icon(Icons.blur_circular_rounded, color: Colors.orangeAccent), const SizedBox(width: 8),
          const Text('ORBIT DRIFT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('ORBIT DRIFT 2D', _score, _highScore, _isNewRecord, Colors.orangeAccent, Icons.blur_circular_rounded, _startGame, context)
          : Stack(
        children: [
          LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _OrbitDriftPainter(_orbitAngle, _orbitRadius, _enemies, _bullets, _powerUps, _health, _hasShield), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('ORBIT DRIFT 2D', 'Tilt to change orbit radius\nAuto-fires enemies coming from the right!', Colors.orangeAccent, _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _OrbEnemy { double x, y, speed; int hp; _OrbEnemy({required this.x, required this.y, required this.speed, required this.hp}); }
class _OrbBullet { double x, y, vx, vy; _OrbBullet({required this.x, required this.y, required this.vx, required this.vy}); }
class _OrbPowerUp { double x, y; String type; _OrbPowerUp({required this.x, required this.y, required this.type}); }
class _OrbitDriftPainter extends CustomPainter {
  final double angle, radius, health; final bool shield; final List<_OrbEnemy> enemies; final List<_OrbBullet> bullets; final List<_OrbPowerUp> powerUps;
  _OrbitDriftPainter(this.angle, this.radius, this.enemies, this.bullets, this.powerUps, this.health, this.shield);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF030D1E));
    final rng = Random(42);
    for (var i = 0; i < 60; i++) canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), rng.nextDouble() + 0.5, Paint()..color = Colors.white.withValues(alpha: 0.4));
    canvas.drawCircle(Offset(cx, cy), 18, Paint()..color = Colors.yellowAccent.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = Colors.yellowAccent);
    canvas.drawCircle(Offset(cx, cy), radius * size.width, Paint()..color = Colors.white.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final sx = cx + cos(angle) * radius * size.width, sy = cy + sin(angle) * radius * size.height;
    if (shield) canvas.drawCircle(Offset(sx, sy), 20, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(Offset(sx, sy), 8, Paint()..color = Colors.orangeAccent); canvas.drawCircle(Offset(sx, sy), 8, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    for (final b in bullets) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x * size.width, b.y * size.height), width: 14, height: 3), const Radius.circular(2)), Paint()..color = Colors.yellowAccent..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    for (final e in enemies) {
      final ep = Offset(e.x * size.width, e.y * size.height);
      canvas.drawCircle(ep, 16, Paint()..color = Colors.redAccent.withValues(alpha: 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(ep, 10, Paint()..color = Colors.redAccent);
    }
    for (final p in powerUps) canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), 12, Paint()..color = (p.type == 'shield' ? Colors.cyanAccent : Colors.purpleAccent).withValues(alpha: 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    final barW = size.width * 0.4;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(16, size.height - 30, barW, 12), const Radius.circular(6)), Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(16, size.height - 30, barW * health / 100, 12), const Radius.circular(6)), Paint()..color = health > 50 ? kNeonGreen : Colors.redAccent);
  }
  @override
  bool shouldRepaint(covariant _OrbitDriftPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 6 — TILT MAZE
// ═══════════════════════════════════════════════════════════════════════════════
class TiltMazeGame extends StatefulWidget {
  final int highScore;
  const TiltMazeGame({super.key, required this.highScore});
  @override
  State<TiltMazeGame> createState() => _TiltMazeGameState();
}
class _MazeCell { bool top = true, right = true, bottom = true, left = true, visited = false; }
class _TiltMazeGameState extends State<TiltMazeGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _bx = 0, _by = 0, _vx = 0, _vy = 0, _ax = 0, _ay = 0;
  bool _gameOver = false, _started = false, _isNewRecord = false;
  int _score = 0, _highScore = 0, _frames = 0, _mazeSize = 5;
  Difficulty _difficulty = Difficulty.medium;
  late List<List<_MazeCell>> _maze;

  @override
  void initState() { super.initState(); _highScore = widget.highScore; _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick); }
  void _generateMaze() {
    _mazeSize = _difficulty == Difficulty.easy ? 5 : (_difficulty == Difficulty.hard ? 12 : 8);
    _maze = List.generate(_mazeSize, (_) => List.generate(_mazeSize, (_) => _MazeCell()));
    final rng = Random();
    void carve(int cx, int cy) {
      _maze[cy][cx].visited = true;
      var dirs = [[0,-1],[1,0],[0,1],[-1,0]]; dirs.shuffle(rng);
      for (var d in dirs) {
        int nx = cx + d[0], ny = cy + d[1];
        if (nx >= 0 && nx < _mazeSize && ny >= 0 && ny < _mazeSize && !_maze[ny][nx].visited) {
          if (d[0] == 1) { _maze[cy][cx].right = false; _maze[ny][nx].left = false; }
          else if (d[0] == -1) { _maze[cy][cx].left = false; _maze[ny][nx].right = false; }
          else if (d[1] == 1) { _maze[cy][cx].bottom = false; _maze[ny][nx].top = false; }
          else if (d[1] == -1) { _maze[cy][cx].top = false; _maze[ny][nx].bottom = false; }
          carve(nx, ny);
        }
      }
    }
    carve(0, 0);
  }
  void _startGame() {
    _generateMaze();
    _bx = 0.5 / _mazeSize; _by = 0.5 / _mazeSize; _vx = 0; _vy = 0; _frames = 0; _score = 0;
    _gameOver = false; _started = true; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) { _ax = e.x * -0.0005; _ay = e.y * 0.0005; });
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frames++; _score = _frames ~/ 6;
      _vx += _ax; _vy += _ay; _vx *= 0.85; _vy *= 0.85;
      double nextX = _bx + _vx, nextY = _by + _vy;
      int cx = (_bx * _mazeSize).floor().clamp(0, _mazeSize - 1);
      int cy = (_by * _mazeSize).floor().clamp(0, _mazeSize - 1);
      final cell = _maze[cy][cx];
      double cr = 0.3 / _mazeSize;
      if (cell.left && nextX - cr < cx / _mazeSize) { nextX = cx / _mazeSize + cr; _vx = 0; }
      if (cell.right && nextX + cr > (cx + 1) / _mazeSize) { nextX = (cx + 1) / _mazeSize - cr; _vx = 0; }
      if (cell.top && nextY - cr < cy / _mazeSize) { nextY = cy / _mazeSize + cr; _vy = 0; }
      if (cell.bottom && nextY + cr > (cy + 1) / _mazeSize) { nextY = (cy + 1) / _mazeSize - cr; _vy = 0; }
      _bx = nextX.clamp(0.0, 1.0); _by = nextY.clamp(0.0, 1.0);
      if (_bx > 1 - 1 / _mazeSize && _by > 1 - 1 / _mazeSize) _endGame();
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_highScore == 0 || _score < _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_tilt_maze', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00111A),
        title: Row(children: [
          const Icon(Icons.grid_4x4_rounded, color: Color(0xFF00E5FF)), const SizedBox(width: 8),
          const Text('TILT MAZE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Time: ${_score / 10}s', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('TILT MAZE', _score, _highScore, _isNewRecord, const Color(0xFF00E5FF), Icons.grid_4x4_rounded, _startGame, context, lowerIsBetter: true)
          : Stack(
        children: [
          if (_started) LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _TiltMazePainter(_maze, _mazeSize, _bx, _by), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('TILT MAZE', 'Tilt to guide the ball\nReach the bottom right corner!', const Color(0xFF00E5FF), _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _TiltMazePainter extends CustomPainter {
  final List<List<_MazeCell>> maze; final int size; final double bx, by;
  _TiltMazePainter(this.maze, this.size, this.bx, this.by);
  @override
  void paint(Canvas canvas, Size sz) {
    final double sq = min(sz.width, sz.height);
    final double padX = (sz.width - sq) / 2, padY = (sz.height - sq) / 2;
    canvas.translate(padX, padY);
    final wallPaint = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 3..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final cellSz = sq / size;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final c = maze[y][x]; final px = x * cellSz, py = y * cellSz;
        if (c.top) canvas.drawLine(Offset(px, py), Offset(px + cellSz, py), wallPaint);
        if (c.left) canvas.drawLine(Offset(px, py), Offset(px, py + cellSz), wallPaint);
        if (c.right && x == size - 1) canvas.drawLine(Offset(px + cellSz, py), Offset(px + cellSz, py + cellSz), wallPaint);
        if (c.bottom && y == size - 1) canvas.drawLine(Offset(px, py + cellSz), Offset(px + cellSz, py + cellSz), wallPaint);
      }
    }
    canvas.drawRect(Rect.fromLTWH((size - 1) * cellSz, (size - 1) * cellSz, cellSz, cellSz), Paint()..color = Colors.greenAccent.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(bx * sq, by * sq), cellSz * 0.3, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _TiltMazePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 7 — WAVE SURFER
// ═══════════════════════════════════════════════════════════════════════════════
class WaveSurferGame extends StatefulWidget {
  final int highScore;
  const WaveSurferGame({super.key, required this.highScore});
  @override
  State<WaveSurferGame> createState() => _WaveSurferGameState();
}
class _WaveSurferGameState extends State<WaveSurferGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _surferX = 0.5, _tiltX = 0, _time = 0;
  int _score = 0, _highScore = 0, _frames = 0, _lives = 3;
  bool _gameOver = false, _started = false, _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;
  List<_Obstacle> _obstacles = [];
  final _rng = Random();

  @override
  void initState() { super.initState(); _highScore = widget.highScore; _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick); }
  void _startGame() {
    _surferX = 0.5; _score = 0; _lives = 3; _frames = 0; _time = 0; _obstacles = [];
    _gameOver = false; _started = true; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _tiltX = e.x * -0.015);
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frames++; _time += 0.05; _surferX = (_surferX + _tiltX).clamp(0.1, 0.9);
      if (_frames % 10 == 0) _score += 1;
      int spawnRate = _difficulty == Difficulty.easy ? 80 : (_difficulty == Difficulty.hard ? 30 : 50);
      if (_frames % spawnRate == 0) _obstacles.add(_Obstacle(x: _rng.nextDouble() * 0.8 + 0.1, y: -0.1, isShark: _rng.nextBool()));
      final killObs = <_Obstacle>{};
      for (final o in _obstacles) {
        o.y += 0.01 + (_score * 0.00005);
        if (o.y > 1.1) killObs.add(o);
        if ((o.x - _surferX).abs() < 0.08 && (o.y - 0.8).abs() < 0.08) { _lives--; killObs.add(o); if (_lives <= 0) _endGame(); }
      }
      _obstacles.removeWhere(killObs.contains);
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_wave_surfer', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003366),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: Row(children: [
          const Icon(Icons.surfing_rounded, color: Color(0xFF0066FF)), const SizedBox(width: 8),
          const Text('WAVE SURFER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w900)),
          const SizedBox(width: 16),
          ...List.generate(3, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 18)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('WAVE SURFER', _score, _highScore, _isNewRecord, const Color(0xFF0066FF), Icons.surfing_rounded, _startGame, context)
          : Stack(
        children: [
          LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _WavePainter(_time, _surferX, _tiltX, _obstacles), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('WAVE SURFER', 'Tilt to steer the surfboard\nDodge rocks and sharks!', const Color(0xFF0066FF), _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _Obstacle { double x, y; bool isShark; _Obstacle({required this.x, required this.y, required this.isShark}); }
class _WavePainter extends CustomPainter {
  final double time, sx, tilt; final List<_Obstacle> obs;
  _WavePainter(this.time, this.sx, this.tilt, this.obs);
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF003366); canvas.drawRect(Offset.zero & size, bgPaint);
    final wavePaint = Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.3)..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 10) {
        double y = size.height * (0.2 + i * 0.2) + sin(x * 0.02 + time * 2 + i) * 30;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, wavePaint);
    }
    for (final o in obs) {
      final op = Offset(o.x * size.width, o.y * size.height);
      if (o.isShark) {
        canvas.drawPath(Path()..moveTo(op.dx, op.dy - 15)..lineTo(op.dx - 10, op.dy + 10)..lineTo(op.dx + 10, op.dy + 10)..close(), Paint()..color = Colors.grey);
      } else {
        canvas.drawCircle(op, 15, Paint()..color = Colors.brown);
      }
    }
    canvas.save();
    canvas.translate(sx * size.width, size.height * 0.8); canvas.rotate(tilt * 10);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 24, height: 60), const Radius.circular(12)), Paint()..color = Colors.yellowAccent);
    canvas.drawCircle(const Offset(0, 10), 8, Paint()..color = Colors.redAccent);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 8 — CRYSTAL COLLECTOR
// ═══════════════════════════════════════════════════════════════════════════════
class CrystalCollectorGame extends StatefulWidget {
  final int highScore;
  const CrystalCollectorGame({super.key, required this.highScore});
  @override
  State<CrystalCollectorGame> createState() => _CrystalCollectorGameState();
}
class _CrystalCollectorGameState extends State<CrystalCollectorGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _px = 0.5, _tiltX = 0;
  int _score = 0, _highScore = 0, _frames = 0, _lives = 3;
  bool _gameOver = false, _started = false, _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;
  List<_Gem> _items = [];
  final _rng = Random();

  @override
  void initState() { super.initState(); _highScore = widget.highScore; _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick); }
  void _startGame() {
    _px = 0.5; _score = 0; _lives = 3; _frames = 0; _items = []; _gameOver = false; _started = true; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _tiltX = e.x * -0.02);
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frames++; _px = (_px + _tiltX).clamp(0.05, 0.95);
      int spawnRate = _difficulty == Difficulty.easy ? 60 : (_difficulty == Difficulty.hard ? 20 : 40);
      if (_frames % spawnRate == 0) _items.add(_Gem(x: _rng.nextDouble() * 0.9 + 0.05, y: -0.1, isToxic: _rng.nextDouble() < 0.3));
      final killItems = <_Gem>{};
      for (final i in _items) {
        i.y += 0.01 + (_score * 0.00005); if (i.y > 1.1) killItems.add(i);
        if ((i.x - _px).abs() < 0.1 && (i.y - 0.9).abs() < 0.05) {
          killItems.add(i);
          if (i.isToxic) { _lives--; if (_lives <= 0) _endGame(); } else { _score += 10; }
        }
      }
      _items.removeWhere(killItems.contains);
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_crystal_collector', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A00),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A00),
        title: Row(children: [
          const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700)), const SizedBox(width: 8),
          const Text('CRYSTAL COLLECTOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Score: $_score', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900)),
          const SizedBox(width: 16),
          ...List.generate(3, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent, size: 18)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('CRYSTAL COLLECTOR', _score, _highScore, _isNewRecord, const Color(0xFFFFD700), Icons.diamond_rounded, _startGame, context)
          : Stack(
        children: [
          LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _CrystalPainter(_px, _items), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('CRYSTAL COLLECTOR', 'Catch the falling gems!\nAvoid the red toxic bubbles.', const Color(0xFFFFD700), _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _Gem { double x, y; bool isToxic; _Gem({required this.x, required this.y, required this.isToxic}); }
class _CrystalPainter extends CustomPainter {
  final double px; final List<_Gem> items; _CrystalPainter(this.px, this.items);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A1A00));
    for (final i in items) {
      final p = Offset(i.x * size.width, i.y * size.height);
      if (i.isToxic) {
        canvas.drawCircle(p, 12, Paint()..color = Colors.redAccent.withValues(alpha: 0.8));
      } else {
        canvas.drawPath(Path()..moveTo(p.dx, p.dy - 12)..lineTo(p.dx + 12, p.dy)..lineTo(p.dx, p.dy + 12)..lineTo(p.dx - 12, p.dy)..close(), Paint()..color = const Color(0xFFFFD700));
      }
    }
    final playerRect = Rect.fromCenter(center: Offset(px * size.width, size.height * 0.9), width: 60, height: 20);
    canvas.drawRRect(RRect.fromRectAndRadius(playerRect, const Radius.circular(10)), Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.drawRRect(RRect.fromRectAndRadius(playerRect, const Radius.circular(10)), Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _CrystalPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GAME 9 — THUNDER RACER
// ═══════════════════════════════════════════════════════════════════════════════
class ThunderRacerGame extends StatefulWidget {
  final int highScore;
  const ThunderRacerGame({super.key, required this.highScore});
  @override
  State<ThunderRacerGame> createState() => _ThunderRacerGameState();
}
class _ThunderRacerGameState extends State<ThunderRacerGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _carX = 0.5, _tiltX = 0, _speed = 0.02;
  int _score = 0, _highScore = 0, _frames = 0;
  bool _gameOver = false, _started = false, _isNewRecord = false;
  Difficulty _difficulty = Difficulty.medium;
  List<_RaceCar> _others = [];
  final _rng = Random();

  @override
  void initState() { super.initState(); _highScore = widget.highScore; _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))..addListener(_tick); }
  void _startGame() {
    _carX = 0.5; _score = 0; _frames = 0; _others = []; _speed = 0.02; _gameOver = false; _started = true; _isNewRecord = false;
    _accelSub = accelerometerEventStream().listen((e) => _tiltX = e.x * -0.015);
    _ticker.repeat();
    setState(() {});
  }
  void _tick() {
    if (!_started || _gameOver) return;
    setState(() {
      _frames++; _carX = (_carX + _tiltX).clamp(0.15, 0.85); _speed += 0.00001; _score += (_speed * 100).toInt();
      int spawnRate = _difficulty == Difficulty.easy ? 60 : (_difficulty == Difficulty.hard ? 20 : 40);
      if (_frames % spawnRate == 0) _others.add(_RaceCar(x: _rng.nextDouble() * 0.7 + 0.15, y: -0.2));
      final killCars = <_RaceCar>{};
      for (final c in _others) {
        c.y += _speed * 0.8; if (c.y > 1.2) killCars.add(c);
        if ((c.x - _carX).abs() < 0.1 && (c.y - 0.8).abs() < 0.1) _endGame();
      }
      _others.removeWhere(killCars.contains);
    });
  }
  void _endGame() async {
    _gameOver = true; _ticker.stop(); _accelSub?.cancel();
    if (_score > _highScore) { _highScore = _score; _isNewRecord = true; (await SharedPreferences.getInstance()).setInt('hi_score_thunder_racer', _highScore); }
  }
  @override
  void dispose() { _ticker.dispose(); _accelSub?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A00),
        title: Row(children: [
          const Icon(Icons.electric_car_rounded, color: Color(0xFFFF6600)), const SizedBox(width: 8),
          const Text('THUNDER RACER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('Dist: $_score', style: const TextStyle(color: Color(0xFFFF6600), fontWeight: FontWeight.w900)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
      ),
      body: _gameOver ? _gameOverWidget('THUNDER RACER', _score, _highScore, _isNewRecord, const Color(0xFFFF6600), Icons.electric_car_rounded, _startGame, context)
          : Stack(
        children: [
          LayoutBuilder(builder: (ctx, box) => CustomPaint(painter: _RacerPainter(_carX, _others, _frames, _speed), child: SizedBox(width: box.maxWidth, height: box.maxHeight))),
          if (!_started) Center(child: _gameStartPrompt('THUNDER RACER', 'Tilt to steer left/right\nAvoid the incoming traffic!', const Color(0xFFFF6600), _difficulty, (d) => setState(() => _difficulty = d), _startGame)),
        ],
      ),
    );
  }
}
class _RaceCar { double x, y; _RaceCar({required this.x, required this.y}); }
class _RacerPainter extends CustomPainter {
  final double carX, speed; final List<_RaceCar> others; final int frames;
  _RacerPainter(this.carX, this.others, this.frames, this.speed);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A0A00));
    final roadP = Paint()..color = Colors.white24..strokeWidth = 4;
    double offset = (frames * speed * size.height) % 40;
    for (double y = offset - 40; y < size.height; y += 40) {
      canvas.drawLine(Offset(size.width * 0.33, y), Offset(size.width * 0.33, y + 20), roadP);
      canvas.drawLine(Offset(size.width * 0.66, y), Offset(size.width * 0.66, y + 20), roadP);
    }
    for (final c in others) {
      canvas.drawRect(Rect.fromCenter(center: Offset(c.x * size.width, c.y * size.height), width: 30, height: 50), Paint()..color = Colors.blueAccent);
    }
    canvas.drawRect(Rect.fromCenter(center: Offset(carX * size.width, size.height * 0.8), width: 30, height: 50), Paint()..color = const Color(0xFFFF6600));
  }
  @override
  bool shouldRepaint(covariant _RacerPainter old) => true;
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────
Widget _gameStartPrompt(String name, String hint, Color color, Difficulty diff, ValueChanged<Difficulty> onDiff, VoidCallback onStart) => Container(
  padding: const EdgeInsets.all(24), margin: const EdgeInsets.symmetric(horizontal: 24),
  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.5))),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.touch_app_rounded, color: color, size: 44),
    const SizedBox(height: 12),
    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
    const SizedBox(height: 8),
    Text(hint, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 13), textAlign: TextAlign.center),
    const SizedBox(height: 20),
    SegmentedButton<Difficulty>(
      segments: const [
        ButtonSegment(value: Difficulty.easy, label: Text('Easy')),
        ButtonSegment(value: Difficulty.medium, label: Text('Medium')),
        ButtonSegment(value: Difficulty.hard, label: Text('Hard')),
      ],
      selected: <Difficulty>{diff},
      onSelectionChanged: (Set<Difficulty> newSelection) => onDiff(newSelection.first),
      style: SegmentedButton.styleFrom(selectedBackgroundColor: color, selectedForegroundColor: Colors.black, foregroundColor: Colors.white),
    ),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: onStart, style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 48)),
      child: const Text('TAP TO BEGIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
    )
  ]),
);

Widget _gameOverWidget(String name, int score, int hiScore, bool newRecord, Color color, IconData icon, VoidCallback onRetry, BuildContext ctx, {bool lowerIsBetter = false}) => Center(
  child: Container(
    margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: const Color(0xFF0F1A2E), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withValues(alpha: 0.5))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 52),
      const SizedBox(height: 16),
      const Text('GAME OVER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
      const SizedBox(height: 8),
      Text(lowerIsBetter ? 'Time: ${score/10}s' : 'Score: $score', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      if (newRecord) ...[
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)), child: const Text('NEW RECORD!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))),
      ] else if (hiScore > 0) ...[
        const SizedBox(height: 8),
        Text(lowerIsBetter ? 'Best: ${hiScore/10}s' : 'Best: $hiScore', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: color), child: Text('PLAY AGAIN', style: TextStyle(color: color == Colors.white ? Colors.black : Colors.black, fontWeight: FontWeight.w900))),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24)), child: const Text('EXIT')),
      ]),
    ]),
  ),
);
