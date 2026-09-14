import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/active_operations_registry.dart';

const kNeonGreen = Color(0xFF00FF88);
const kNeonBlue = Color(0xFF00D4FF);
const kNeonPurple = Color(0xFFB44FFF);

enum WeaponType { pistol, shotgun, sniper, grenade }

class Weapon {
  final WeaponType type;
  final String name;
  final double damage;
  final double range;
  final double fireRate; // seconds
  final Color color;

  Weapon({
    required this.type,
    required this.name,
    required this.damage,
    required this.range,
    required this.fireRate,
    required this.color,
  });
}

class Entity {
  Offset position;
  double hp;
  double armor;
  Weapon currentWeapon;
  double lastFiredTime = 0;
  bool isDead = false;
  double rotation = 0; // in radians
  int kills = 0;

  Entity({
    required this.position,
    this.hp = 100,
    this.armor = 0,
    required this.currentWeapon,
  });

  void takeDamage(double damage) {
    if (armor > 0) {
      double armorDamage = damage * 0.5;
      if (armor >= armorDamage) {
        armor -= armorDamage;
        hp -= damage - armorDamage;
      } else {
        hp -= damage - armor;
        armor = 0;
      }
    } else {
      hp -= damage;
    }
    if (hp <= 0) {
      hp = 0;
      isDead = true;
    }
  }
}

class Bullet {
  Offset position;
  final Offset velocity;
  final double damage;
  final double maxRange;
  double traveled = 0;
  final Entity owner;
  final bool isGrenade;

  Bullet({
    required this.position,
    required this.velocity,
    required this.damage,
    required this.maxRange,
    required this.owner,
    this.isGrenade = false,
  });
}

class LootCrate {
  final Offset position;
  final Weapon weapon;
  bool pickedUp = false;

  LootCrate({
    required this.position,
    required this.weapon,
    this.pickedUp = false,
  });
}

class KillFeedEntry {
  final String text;
  final double time;

  KillFeedEntry(this.text, this.time);
}

class TerrainFeature {
  final Offset position;
  final double radius;
  final Color color;

  TerrainFeature(this.position, this.radius, this.color);
}

class BattleRoyaleGameScreen extends StatefulWidget {
  static const routeName = '/battle-royale';

  const BattleRoyaleGameScreen({Key? key}) : super(key: key);

  @override
  _BattleRoyaleGameScreenState createState() => _BattleRoyaleGameScreenState();
}

class _BattleRoyaleGameScreenState extends State<BattleRoyaleGameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _lastTime = 0;
  double _gameTime = 0;

  final double _worldWidth = 2000;
  final double _worldHeight = 2000;
  final math.Random _rnd = math.Random();

  late Entity _player;
  List<Entity> _bots = [];
  List<Bullet> _bullets = [];
  List<LootCrate> _crates = [];
  List<KillFeedEntry> _killFeed = [];
  List<TerrainFeature> _terrain = [];

  // Zone
  double _zoneRadius = 900;
  final double _initialZoneRadius = 900;
  final double _zoneDuration = 300; // 5 minutes to close
  Offset _zoneCenter = const Offset(1000, 1000);

  // Controls
  Offset _joystickVector = Offset.zero;
  bool _isFiring = false;
  LootCrate? _nearbyCrate;

  // Stats
  double _survivalTime = 0;
  double _damageDealt = 0;
  bool _gameOver = false;
  bool _victory = false;
  int _placement = 21;

  final Weapon _pistol = Weapon(
      type: WeaponType.pistol,
      name: "Pistol",
      damage: 15,
      range: 300,
      fireRate: 0.8,
      color: Colors.grey);
  final Weapon _shotgun = Weapon(
      type: WeaponType.shotgun,
      name: "Shotgun",
      damage: 45,
      range: 150,
      fireRate: 1.2,
      color: Colors.redAccent);
  final Weapon _sniper = Weapon(
      type: WeaponType.sniper,
      name: "Sniper",
      damage: 90,
      range: 600,
      fireRate: 1.5,
      color: Colors.orange);
  final Weapon _grenade = Weapon(
      type: WeaponType.grenade,
      name: "Grenade",
      damage: 80,
      range: 200,
      fireRate: 2.0,
      color: kNeonGreen);

  @override
  void initState() {
    super.initState();
    _initGame();
    _ticker = createTicker(_tick)..start();

    // Register this game loop in System Operations Registry
    ActiveOperationsRegistry.instance.register(
      'battle_royale_loop',
      'Battle Royale Game Loop',
      'Game Loop',
      onCancel: () {
        if (mounted) {
          setState(() {
            _gameOver = true;
            if (_ticker.isActive) {
              _ticker.stop();
            }
          });
        }
      },
      cpuUsage: 16.8,
      memoryMB: 54.2,
    );
  }

  @override
  void dispose() {
    // Deregister game loop
    ActiveOperationsRegistry.instance.deregister('battle_royale_loop');
    if (_ticker.isActive) {
      _ticker.dispose();
    }
    super.dispose();
  }

  void _initGame() {
    _player = Entity(
      position: Offset(_worldWidth / 2, _worldHeight / 2),
      armor: 50,
      currentWeapon: _pistol,
    );
    _zoneCenter = Offset(_worldWidth / 2, _worldHeight / 2);
    _zoneRadius = _initialZoneRadius;
    _survivalTime = 0;
    _damageDealt = 0;
    _gameOver = false;
    _victory = false;
    _gameTime = 0;
    _placement = 21;
    _killFeed.clear();
    _bullets.clear();
    _crates.clear();
    _bots.clear();
    _terrain.clear();

    // Generate terrain
    for (int i = 0; i < 20; i++) {
      _terrain.add(TerrainFeature(
        Offset(_rnd.nextDouble() * _worldWidth, _rnd.nextDouble() * _worldHeight),
        _rnd.nextDouble() * 100 + 50,
        Colors.brown[700]!, // Dirt
      ));
    }
    for (int i = 0; i < 15; i++) {
      _terrain.add(TerrainFeature(
        Offset(_rnd.nextDouble() * _worldWidth, _rnd.nextDouble() * _worldHeight),
        _rnd.nextDouble() * 60 + 30,
        Colors.grey[700]!, // Rock
      ));
    }
    for (int i = 0; i < 10; i++) {
      _terrain.add(TerrainFeature(
        Offset(_rnd.nextDouble() * _worldWidth, _rnd.nextDouble() * _worldHeight),
        _rnd.nextDouble() * 120 + 80,
        Colors.blue[700]!, // Water
      ));
    }

    // Generate Loot
    List<Weapon> weaponPool = [_shotgun, _sniper, _grenade];
    for (int i = 0; i < 15; i++) {
      _crates.add(LootCrate(
        position: Offset(_rnd.nextDouble() * _worldWidth, _rnd.nextDouble() * _worldHeight),
        weapon: weaponPool[_rnd.nextInt(weaponPool.length)],
      ));
    }

    // Generate Bots
    for (int i = 0; i < 20; i++) {
      _bots.add(Entity(
        position: Offset(_rnd.nextDouble() * _worldWidth, _rnd.nextDouble() * _worldHeight),
        currentWeapon: _pistol,
      ));
    }
  }

  void _tick(Duration elapsed) {
    if (_gameOver) return;

    double time = elapsed.inMicroseconds / 1000000.0;
    double dt = time - _lastTime;
    _lastTime = time;

    // Cap dt
    if (dt > 0.1) dt = 0.1;
    _gameTime += dt;
    _survivalTime += dt;

    _update(dt);
    setState(() {});
  }

  void _update(double dt) {
    // Update Zone
    double progress = _gameTime / _zoneDuration;
    if (progress > 1.0) progress = 1.0;
    _zoneRadius = _initialZoneRadius * (1.0 - progress);

    // Player Move
    if (_joystickVector != Offset.zero) {
      double speed = 150 * dt;
      Offset nextPos = _player.position + _joystickVector * speed;
      if (nextPos.dx >= 0 && nextPos.dx <= _worldWidth && nextPos.dy >= 0 && nextPos.dy <= _worldHeight) {
        _player.position = nextPos;
        _player.rotation = math.atan2(_joystickVector.dy, _joystickVector.dx);
      }
    }

    // Zone Damage Player
    if ((_player.position - _zoneCenter).distance > _zoneRadius) {
      _player.takeDamage(2 * dt);
      if (_player.isDead) {
        _endGame(false);
        return;
      }
    }

    // Player Fire
    if (_isFiring) {
      _fireWeapon(_player, _joystickVector == Offset.zero ? Offset(math.cos(_player.rotation), math.sin(_player.rotation)) : _joystickVector);
    }

    // Check near crate
    _nearbyCrate = null;
    for (var crate in _crates) {
      if (!crate.pickedUp && (crate.position - _player.position).distance < 60) {
        _nearbyCrate = crate;
        break;
      }
    }

    // Update Bots
    for (var bot in _bots) {
      if (bot.isDead) continue;

      // Zone Damage Bot
      if ((bot.position - _zoneCenter).distance > _zoneRadius) {
        bot.takeDamage(2 * dt);
        if (bot.isDead) {
          _killFeed.add(KillFeedEntry("Zone eliminated Bot_${bot.hashCode % 100}", _gameTime));
          continue;
        }
      }

      double distToPlayer = (bot.position - _player.position).distance;
      if (distToPlayer < bot.currentWeapon.range && !_player.isDead) {
        // Shoot player
        bot.rotation = math.atan2(_player.position.dy - bot.position.dy, _player.position.dx - bot.position.dx);
        _fireWeapon(bot, Offset(math.cos(bot.rotation), math.sin(bot.rotation)));
      } else if (distToPlayer < 400 && !_player.isDead) {
        // Chase player
        Offset dir = (_player.position - bot.position) / distToPlayer;
        bot.position += dir * 120 * dt;
        bot.rotation = math.atan2(dir.dy, dir.dx);
      } else {
        // Roam towards center if outside, else random
        if ((bot.position - _zoneCenter).distance > _zoneRadius * 0.8) {
           Offset dir = (_zoneCenter - bot.position);
           double d = dir.distance;
           if (d > 0) {
             bot.position += (dir / d) * 100 * dt;
             bot.rotation = math.atan2(dir.dy, dir.dx);
           }
        }
      }
    }

    // Remove dead bots
    int botsBefore = _bots.where((b) => !b.isDead).length;
    _bots.removeWhere((bot) => bot.isDead);
    int botsAfter = _bots.where((b) => !b.isDead).length;
    if (botsAfter < botsBefore) {
        _placement = botsAfter + 1;
    }

    // Check Victory
    if (_bots.isEmpty) {
      _endGame(true);
      return;
    }

    // Update Bullets
    for (var bullet in _bullets) {
      double moveDist = 600 * dt;
      if (bullet.isGrenade) moveDist = 300 * dt;
      bullet.position += bullet.velocity * moveDist;
      bullet.traveled += moveDist;

      if (!bullet.isGrenade) {
        // Hit detection
        if (bullet.owner != _player && (bullet.position - _player.position).distance < 20) {
          _player.takeDamage(bullet.damage);
          bullet.traveled = bullet.maxRange + 1; // mark for removal
          if (_player.isDead) _endGame(false);
          continue;
        }

        for (var bot in _bots) {
          if (bullet.owner != bot && !bot.isDead && (bullet.position - bot.position).distance < 20) {
            bot.takeDamage(bullet.damage);
            bullet.traveled = bullet.maxRange + 1;
            if (bullet.owner == _player) _damageDealt += bullet.damage;
            if (bot.isDead) {
              if (bullet.owner == _player) _player.kills++;
              _killFeed.add(KillFeedEntry("${bullet.owner == _player ? 'You' : 'Bot_${bullet.owner.hashCode % 100}'} eliminated Bot_${bot.hashCode % 100}", _gameTime));
            }
            break; // Bullet hits one target
          }
        }
      } else if (bullet.traveled >= bullet.maxRange) {
        // Grenade Explosion
        if ((bullet.position - _player.position).distance < 100) {
           _player.takeDamage(bullet.damage);
           if (_player.isDead) _endGame(false);
        }
        for (var bot in _bots) {
          if ((bullet.position - bot.position).distance < 100) {
             bot.takeDamage(bullet.damage);
             if (bullet.owner == _player) _damageDealt += bullet.damage;
             if (bot.isDead) {
                if (bullet.owner == _player) _player.kills++;
                _killFeed.add(KillFeedEntry("${bullet.owner == _player ? 'You' : 'Bot_${bullet.owner.hashCode % 100}'} exploded Bot_${bot.hashCode % 100}", _gameTime));
             }
          }
        }
      }
    }
    _bullets.removeWhere((b) => b.traveled >= b.maxRange);

    // Clean Killfeed
    _killFeed.removeWhere((k) => _gameTime - k.time > 5);
  }

  void _fireWeapon(Entity entity, Offset direction) {
    if (_gameTime - entity.lastFiredTime < entity.currentWeapon.fireRate) return;
    entity.lastFiredTime = _gameTime;

    if (direction == Offset.zero) direction = const Offset(1, 0);

    if (entity.currentWeapon.type == WeaponType.shotgun) {
      for (int i = -2; i <= 2; i++) {
        double angle = math.atan2(direction.dy, direction.dx) + (i * 0.15);
        _bullets.add(Bullet(
          position: entity.position,
          velocity: Offset(math.cos(angle), math.sin(angle)),
          damage: entity.currentWeapon.damage / 5,
          maxRange: entity.currentWeapon.range,
          owner: entity,
        ));
      }
    } else {
      _bullets.add(Bullet(
        position: entity.position,
        velocity: direction,
        damage: entity.currentWeapon.damage,
        maxRange: entity.currentWeapon.range,
        owner: entity,
        isGrenade: entity.currentWeapon.type == WeaponType.grenade,
      ));
    }
  }

  void _endGame(bool isVictory) {
    _gameOver = true;
    _victory = isVictory;
    if (_victory) _placement = 1;
    setState(() {});
  }

  String _formatTime(double s) {
    int mins = (s / 60).floor();
    int secs = (s % 60).floor();
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    Offset cameraOffset = _player.position - Offset(screenSize.width / 2, screenSize.height / 2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Game World
          CustomPaint(
            size: Size.infinite,
            painter: GamePainter(
              player: _player,
              bots: _bots,
              bullets: _bullets,
              crates: _crates,
              terrain: _terrain,
              cameraOffset: cameraOffset,
              zoneCenter: _zoneCenter,
              zoneRadius: _zoneRadius,
              worldSize: Size(_worldWidth, _worldHeight),
            ),
          ),
          
          // HUD: Safe Zone indicator (White)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  "ZONE CLOSING IN: ${_formatTime(math.max(0, _zoneDuration - _gameTime))}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // HUD: Alive Count
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "🟢 ${_bots.length + (_player.isDead ? 0 : 1)} ALIVE",
                style: const TextStyle(color: kNeonGreen, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // HUD: HP / Armor
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("PLAYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: 150,
                  height: 10,
                  color: Colors.grey[800],
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _player.hp / 100,
                    child: Container(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 150,
                  height: 10,
                  color: Colors.grey[800],
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _player.armor / 50,
                    child: Container(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          // HUD: Weapon
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_player.currentWeapon.name, style: TextStyle(color: _player.currentWeapon.color, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("∞", style: TextStyle(color: Colors.white, fontSize: 24)),
              ],
            ),
          ),

          // HUD: Kill Feed
          Positioned(
            top: 80,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _killFeed.map((k) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(k.text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              )).toList(),
            ),
          ),

          // Controls: Joystick
          Positioned(
            bottom: 40,
            left: 40,
            child: GestureDetector(
              onPanStart: (details) => _updateJoystick(details.localPosition, const Size(120, 120)),
              onPanUpdate: (details) => _updateJoystick(details.localPosition, const Size(120, 120)),
              onPanEnd: (_) => setState(() => _joystickVector = Offset.zero),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
                child: Center(
                  child: Transform.translate(
                    offset: _joystickVector * 40,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls: Fire Button
          Positioned(
            bottom: 40,
            right: 40,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isFiring = true),
              onTapUp: (_) => setState(() => _isFiring = false),
              onTapCancel: () => setState(() => _isFiring = false),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isFiring ? Colors.red : Colors.red.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 3),
                  boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)],
                ),
                child: const Icon(Icons.my_location, color: Colors.white, size: 40),
              ),
            ),
          ),

          // Controls: Loot Button
          if (_nearbyCrate != null)
            Positioned(
              bottom: 140,
              right: 40,
              child: GestureDetector(
                onTap: () {
                  if (_nearbyCrate != null) {
                    setState(() {
                      _player.currentWeapon = _nearbyCrate!.weapon;
                      _nearbyCrate!.pickedUp = true;
                      _nearbyCrate = null;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.amberAccent, blurRadius: 10)],
                  ),
                  child: const Text("LOOT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ),

          // Game Over Overlay
          if (_gameOver)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _victory ? "VICTORY ROYALE" : "YOU DIED",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _victory ? Colors.amber : Colors.red,
                        shadows: [Shadow(color: _victory ? Colors.amberAccent : Colors.redAccent, blurRadius: 20)],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("PLACEMENT: #$_placement", style: const TextStyle(color: Colors.white, fontSize: 24)),
                    Text("KILLS: ${_player.kills}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                    Text("DAMAGE: ${_damageDealt.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                    Text("SURVIVED: ${_formatTime(_survivalTime)}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kNeonPurple),
                          onPressed: () {
                            setState(() {
                              _initGame();
                            });
                          },
                          child: const Text("PLAY AGAIN"),
                        ),
                        const SizedBox(width: 20),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("BACK TO HUB"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateJoystick(Offset localPos, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    Offset vector = localPos - center;
    if (vector.distance > 40) {
      vector = (vector / vector.distance);
    } else {
      vector = vector / 40;
    }
    setState(() {
      _joystickVector = vector;
    });
  }
}

class GamePainter extends CustomPainter {
  final Entity player;
  final List<Entity> bots;
  final List<Bullet> bullets;
  final List<LootCrate> crates;
  final List<TerrainFeature> terrain;
  final Offset cameraOffset;
  final Offset zoneCenter;
  final double zoneRadius;
  final Size worldSize;

  GamePainter({
    required this.player,
    required this.bots,
    required this.bullets,
    required this.crates,
    required this.terrain,
    required this.cameraOffset,
    required this.zoneCenter,
    required this.zoneRadius,
    required this.worldSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(-cameraOffset.dx, -cameraOffset.dy);

    // Draw Grass Background
    Paint grassPaint = Paint()..color = Colors.lightGreen[800]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, worldSize.width, worldSize.height), grassPaint);

    // Draw Terrain
    for (var t in terrain) {
      canvas.drawCircle(t.position, t.radius, Paint()..color = t.color);
    }

    // Draw Zone
    Paint zonePaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(zoneCenter, 5000, zonePaint); // dark overlay outside
    canvas.drawCircle(zoneCenter, zoneRadius, Paint()..color = Colors.lightGreen[800]!..blendMode = BlendMode.dstOut);
    
    Paint zoneBorder = Paint()
      ..color = kNeonBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 10);
    canvas.drawCircle(zoneCenter, zoneRadius, zoneBorder);

    // Draw Crates
    for (var crate in crates) {
      if (!crate.pickedUp) {
        canvas.drawRect(
          Rect.fromCenter(center: crate.position, width: 20, height: 20),
          Paint()..color = Colors.amber,
        );
      }
    }

    // Draw Bullets
    for (var bullet in bullets) {
      if (bullet.isGrenade) {
        canvas.drawCircle(bullet.position, 5, Paint()..color = kNeonGreen);
      } else {
        canvas.drawLine(
          bullet.position,
          bullet.position - bullet.velocity * 10,
          Paint()..color = Colors.yellow..strokeWidth = 3,
        );
      }
    }

    // Draw Bots
    for (var bot in bots) {
      if (!bot.isDead) _drawEntity(canvas, bot, Colors.red);
    }

    // Draw Player
    if (!player.isDead) {
      _drawEntity(canvas, player, kNeonBlue);
    }

    canvas.restore();
  }

  void _drawEntity(Canvas canvas, Entity entity, Color color) {
    canvas.save();
    canvas.translate(entity.position.dx, entity.position.dy);
    canvas.rotate(entity.rotation);

    // Body
    canvas.drawCircle(Offset.zero, 15, Paint()..color = color);
    
    // Weapon / Hands
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(15, 0), width: 20, height: 6),
      Paint()..color = Colors.grey[800]!,
    );

    canvas.restore();

    // HP Bar
    canvas.drawRect(
      Rect.fromLTWH(entity.position.dx - 15, entity.position.dy - 25, 30, 4),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(entity.position.dx - 15, entity.position.dy - 25, 30 * (entity.hp / 100), 4),
      Paint()..color = Colors.green,
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
