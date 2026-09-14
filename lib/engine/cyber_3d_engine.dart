import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// 1. 3D VECTOR MATHEMATICS (Vector3D)
// ============================================================================

class Vector3D {
  double x;
  double y;
  double z;

  Vector3D(this.x, this.y, this.z);

  Vector3D.zero() : this(0, 0, 0);

  Vector3D copy() => Vector3D(x, y, z);

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);
  Vector3D operator /(double s) => Vector3D(x / s, y / s, z / s);

  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  Vector3D cross(Vector3D o) => Vector3D(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3D normalized() {
    final l = length;
    if (l == 0) return Vector3D.zero();
    return Vector3D(x / l, y / l, z / l);
  }

  double distanceTo(Vector3D o) => (this - o).length;

  Vector3D rotateX(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vector3D(x, y * c - z * s, y * s + z * c);
  }

  Vector3D rotateY(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vector3D(x * c + z * s, y, -x * s + z * c);
  }

  Vector3D rotateZ(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Vector3D(x * c - y * s, x * s + y * c, z);
  }

  Vector3D rotateEuler(Vector3D angles) {
    return rotateZ(angles.z).rotateX(angles.x).rotateY(angles.y);
  }

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, ${z.toStringAsFixed(1)})';
}

// ============================================================================
// 2. 3D POLYGON & SURFACE NORMAL (Polygon3D)
// ============================================================================

class Polygon3D {
  final List<Vector3D> vertices;
  Vector3D? normal;
  Color fillColor;
  Color edgeColor;
  double strokeWidth;
  bool isWireframe;
  bool twoSided;

  // Runtime projected state (calculated per frame)
  double averageDepth = 0.0;
  List<Offset> projectedPoints = [];
  Color illuminatedColor = Colors.white;
  bool isCulled = false;

  Polygon3D({
    required this.vertices,
    this.normal,
    this.fillColor = const Color(0xFF1E293B),
    this.edgeColor = const Color(0xFF00E5FF),
    this.strokeWidth = 1.2,
    this.isWireframe = false,
    this.twoSided = false,
  }) {
    if (normal == null && vertices.length >= 3) {
      calculateNormal();
    }
  }

  void calculateNormal() {
    final v0 = vertices[0];
    final v1 = vertices[1];
    final v2 = vertices[2];
    final edge1 = v1 - v0;
    final edge2 = v2 - v0;
    normal = edge1.cross(edge2).normalized();
  }

  Polygon3D copy() {
    return Polygon3D(
      vertices: vertices.map((v) => v.copy()).toList(),
      normal: normal?.copy(),
      fillColor: fillColor,
      edgeColor: edgeColor,
      strokeWidth: strokeWidth,
      isWireframe: isWireframe,
      twoSided: twoSided,
    );
  }
}

// ============================================================================
// 3. 3D MESH & PROCEDURAL GENERATORS (Mesh3D)
// ============================================================================

class Mesh3D {
  String id;
  List<Polygon3D> polygons;
  Vector3D position;
  Vector3D rotation; // Euler angles: pitch(x), yaw(y), roll(z)
  Vector3D scale;
  Vector3D velocity;
  bool isVisible;

  Mesh3D({
    required this.id,
    required this.polygons,
    Vector3D? position,
    Vector3D? rotation,
    Vector3D? scale,
    Vector3D? velocity,
    this.isVisible = true,
  })  : position = position ?? Vector3D.zero(),
        rotation = rotation ?? Vector3D.zero(),
        scale = scale ?? Vector3D(1, 1, 1),
        velocity = velocity ?? Vector3D.zero();

  // --------------------------------------------------------------------------
  // PROCEDURAL MESH: Advanced Futuristic Starfighter (StarFox style)
  // --------------------------------------------------------------------------
  static Mesh3D createStarfighter({
    String id = 'starfighter',
    Color mainColor = const Color(0xFF0055FF),
    Color wingColor = const Color(0xFF00E5FF),
    Color cockpitColor = const Color(0xFFFFD700),
    Color engineColor = const Color(0xFFFF2244),
  }) {
    final List<Polygon3D> polys = [];

    // Fuselage Nose Point
    final nose = Vector3D(0, 0, 30);
    // Fuselage Mid
    final topMid = Vector3D(0, 5, 8);
    final bottomMid = Vector3D(0, -4, 8);
    final leftMid = Vector3D(-6, 0, 8);
    final rightMid = Vector3D(6, 0, 8);

    // Fuselage Rear
    final topRear = Vector3D(0, 6, -18);
    final bottomRear = Vector3D(0, -4, -18);
    final leftRear = Vector3D(-7, 0, -18);
    final rightRear = Vector3D(7, 0, -18);

    // Cockpit Glass
    final cockpitPeak = Vector3D(0, 8, 2);
    final cockpitFront = Vector3D(0, 6, 14);

    // Nose Cone Faces
    polys.add(Polygon3D(vertices: [nose, rightMid, topMid], fillColor: mainColor, edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [nose, topMid, leftMid], fillColor: mainColor, edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [nose, leftMid, bottomMid], fillColor: mainColor.withValues(alpha: 0.8), edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [nose, bottomMid, rightMid], fillColor: mainColor.withValues(alpha: 0.8), edgeColor: wingColor));

    // Cockpit Canopy (Glowing Gold)
    polys.add(Polygon3D(vertices: [cockpitFront, rightMid, cockpitPeak], fillColor: cockpitColor, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [cockpitFront, cockpitPeak, leftMid], fillColor: cockpitColor, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [cockpitPeak, topRear, leftMid], fillColor: cockpitColor.withValues(alpha: 0.85), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [cockpitPeak, rightMid, topRear], fillColor: cockpitColor.withValues(alpha: 0.85), edgeColor: Colors.white));

    // Main Fuselage Body
    polys.add(Polygon3D(vertices: [topMid, topRear, leftRear, leftMid], fillColor: mainColor, edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [topMid, rightMid, rightRear, topRear], fillColor: mainColor, edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [bottomMid, leftMid, leftRear, bottomRear], fillColor: Colors.black87, edgeColor: wingColor));
    polys.add(Polygon3D(vertices: [bottomMid, bottomRear, rightRear, rightMid], fillColor: Colors.black87, edgeColor: wingColor));

    // Swept Forward / Backward Wings (Left & Right)
    final leftWingTip = Vector3D(-34, -1, -6);
    final leftWingUpper = Vector3D(-32, 6, -14);
    final rightWingTip = Vector3D(34, -1, -6);
    final rightWingUpper = Vector3D(32, 6, -14);

    // Left Main Wing
    polys.add(Polygon3D(vertices: [leftMid, leftWingTip, leftRear], fillColor: wingColor, edgeColor: Colors.white, twoSided: true));
    polys.add(Polygon3D(vertices: [leftWingTip, leftWingUpper, leftRear], fillColor: mainColor, edgeColor: wingColor, twoSided: true));

    // Right Main Wing
    polys.add(Polygon3D(vertices: [rightMid, rightRear, rightWingTip], fillColor: wingColor, edgeColor: Colors.white, twoSided: true));
    polys.add(Polygon3D(vertices: [rightWingTip, rightRear, rightWingUpper], fillColor: mainColor, edgeColor: wingColor, twoSided: true));

    // Wingtip Laser Cannons
    final leftCannon = Vector3D(-34, -1, 10);
    final rightCannon = Vector3D(34, -1, 10);
    polys.add(Polygon3D(vertices: [leftWingTip, leftCannon, Vector3D(-32, 1, 0)], fillColor: Colors.white, edgeColor: wingColor, twoSided: true));
    polys.add(Polygon3D(vertices: [rightWingTip, Vector3D(32, 1, 0), rightCannon], fillColor: Colors.white, edgeColor: wingColor, twoSided: true));

    // Vertical Stabilizer Fins (Twin Tails)
    final leftFinTip = Vector3D(-12, 16, -20);
    final rightFinTip = Vector3D(12, 16, -20);
    polys.add(Polygon3D(vertices: [topRear, leftFinTip, leftRear], fillColor: wingColor, edgeColor: Colors.white, twoSided: true));
    polys.add(Polygon3D(vertices: [topRear, rightRear, rightFinTip], fillColor: wingColor, edgeColor: Colors.white, twoSided: true));

    // Glowing Thruster Exhaust (Red / Magenta)
    polys.add(Polygon3D(vertices: [topRear, rightRear, bottomRear, leftRear], fillColor: engineColor, edgeColor: Colors.amber, twoSided: true));

    return Mesh3D(id: id, polygons: polys);
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL MESH: Colossal Alien Dreadnought Boss
  // --------------------------------------------------------------------------
  static Mesh3D createDreadnought({
    String id = 'boss_dreadnought',
    Color hullColor = const Color(0xFF7B1FA2),
    Color coreColor = const Color(0xFFFF2244),
  }) {
    final List<Polygon3D> polys = [];

    // Colossal Battleship Geometry (Huge multi-segmented mothership)
    final prow = Vector3D(0, -6, 90);
    final prowTop = Vector3D(0, 15, 60);
    final prowLeft = Vector3D(-28, 0, 45);
    final prowRight = Vector3D(28, 0, 45);

    final midLeft = Vector3D(-65, -5, -10);
    final midRight = Vector3D(65, -5, -10);
    final midTop = Vector3D(0, 32, -15);
    final midBottom = Vector3D(0, -22, -15);

    final rearLeft = Vector3D(-50, 0, -80);
    final rearRight = Vector3D(50, 0, -80);
    final rearTop = Vector3D(0, 26, -95);
    final rearBottom = Vector3D(0, -18, -95);

    // Front Ram Prow
    polys.add(Polygon3D(vertices: [prow, prowTop, prowRight], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [prow, prowLeft, prowTop], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [prow, prowRight, Vector3D(0, -15, 50)], fillColor: Colors.black87, edgeColor: hullColor));
    polys.add(Polygon3D(vertices: [prow, Vector3D(0, -15, 50), prowLeft], fillColor: Colors.black87, edgeColor: hullColor));

    // Mid Hull Sections
    polys.add(Polygon3D(vertices: [prowTop, midTop, midRight, prowRight], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [prowTop, prowLeft, midLeft, midTop], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [Vector3D(0, -15, 50), midRight, midBottom, midLeft], fillColor: Colors.black87, edgeColor: hullColor));

    // Gigantic Broadside Wing Battlestations
    polys.add(Polygon3D(vertices: [prowLeft, Vector3D(-80, 8, -25), midLeft], fillColor: const Color(0xFF311B92), edgeColor: Colors.cyanAccent, twoSided: true));
    polys.add(Polygon3D(vertices: [prowRight, midRight, Vector3D(80, 8, -25)], fillColor: const Color(0xFF311B92), edgeColor: Colors.cyanAccent, twoSided: true));

    // Dreadnought Command Bridge Citadel
    final bridgePeak = Vector3D(0, 48, -25);
    polys.add(Polygon3D(vertices: [midTop, bridgePeak, Vector3D(18, 28, -25)], fillColor: coreColor, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [midTop, Vector3D(-18, 28, -25), bridgePeak], fillColor: coreColor, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [bridgePeak, rearTop, Vector3D(15, 24, -55)], fillColor: coreColor.withValues(alpha: 0.8), edgeColor: Colors.amber));
    polys.add(Polygon3D(vertices: [bridgePeak, Vector3D(-15, 24, -55), rearTop], fillColor: coreColor.withValues(alpha: 0.8), edgeColor: Colors.amber));

    // Rear Engines & Core Reactor Vents
    polys.add(Polygon3D(vertices: [midTop, rearTop, rearRight, midRight], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [midTop, midLeft, rearLeft, rearTop], fillColor: hullColor, edgeColor: coreColor));
    polys.add(Polygon3D(vertices: [rearTop, rearLeft, rearBottom, rearRight], fillColor: const Color(0xFFFF0055), edgeColor: Colors.yellow, twoSided: true));

    return Mesh3D(id: id, polygons: polys, scale: Vector3D(1.4, 1.4, 1.4));
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL MESH: Enemy Cyber Interceptor
  // --------------------------------------------------------------------------
  static Mesh3D createInterceptor({
    String id = 'interceptor',
    Color color = const Color(0xFFFF2244),
  }) {
    final List<Polygon3D> polys = [];
    final nose = Vector3D(0, 0, 18);
    final top = Vector3D(0, 5, 0);
    final bottom = Vector3D(0, -4, 0);
    final leftWing = Vector3D(-18, 0, -8);
    final rightWing = Vector3D(18, 0, -8);
    final tail = Vector3D(0, 0, -14);

    polys.add(Polygon3D(vertices: [nose, rightWing, top], fillColor: color, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [nose, top, leftWing], fillColor: color, edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [nose, leftWing, bottom], fillColor: Colors.black87, edgeColor: color));
    polys.add(Polygon3D(vertices: [nose, bottom, rightWing], fillColor: Colors.black87, edgeColor: color));
    polys.add(Polygon3D(vertices: [top, rightWing, tail], fillColor: color.withValues(alpha: 0.9), edgeColor: Colors.yellow));
    polys.add(Polygon3D(vertices: [top, tail, leftWing], fillColor: color.withValues(alpha: 0.9), edgeColor: Colors.yellow));

    return Mesh3D(id: id, polygons: polys);
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL MESH: 3D Faceted Asteroid
  // --------------------------------------------------------------------------
  static Mesh3D createAsteroid({
    String id = 'asteroid',
    double radius = 16.0,
    int seed = 42,
  }) {
    final List<Polygon3D> polys = [];
    final rng = math.Random(seed);

    Vector3D perturb(Vector3D v) {
      final factor = 1.0 + (rng.nextDouble() - 0.5) * 0.45;
      return v * factor;
    }

    final top = perturb(Vector3D(0, radius, 0));
    final bottom = perturb(Vector3D(0, -radius, 0));
    final p1 = perturb(Vector3D(radius, 0, 0));
    final p2 = perturb(Vector3D(0, 0, radius));
    final p3 = perturb(Vector3D(-radius, 0, 0));
    final p4 = perturb(Vector3D(0, 0, -radius));

    const rockColor = Color(0xFF334155);
    const edgeColor = Color(0xFF94A3B8);

    polys.add(Polygon3D(vertices: [top, p1, p2], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [top, p2, p3], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [top, p3, p4], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [top, p4, p1], fillColor: rockColor, edgeColor: edgeColor));

    polys.add(Polygon3D(vertices: [bottom, p2, p1], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [bottom, p3, p2], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [bottom, p4, p3], fillColor: rockColor, edgeColor: edgeColor));
    polys.add(Polygon3D(vertices: [bottom, p1, p4], fillColor: rockColor, edgeColor: edgeColor));

    return Mesh3D(id: id, polygons: polys);
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL MESH: Floating Cyber Obelisk / Energy Power-Up
  // --------------------------------------------------------------------------
  static Mesh3D createCyberPyramid({
    String id = 'powerup',
    double size = 12.0,
    Color color = const Color(0xFF00FF66),
  }) {
    final List<Polygon3D> polys = [];
    final top = Vector3D(0, size, 0);
    final bottom = Vector3D(0, -size, 0);
    final p1 = Vector3D(size * 0.7, 0, 0);
    final p2 = Vector3D(0, 0, size * 0.7);
    final p3 = Vector3D(-size * 0.7, 0, 0);
    final p4 = Vector3D(0, 0, -size * 0.7);

    polys.add(Polygon3D(vertices: [top, p1, p2], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [top, p2, p3], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [top, p3, p4], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [top, p4, p1], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));

    polys.add(Polygon3D(vertices: [bottom, p2, p1], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [bottom, p3, p2], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [bottom, p4, p3], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));
    polys.add(Polygon3D(vertices: [bottom, p1, p4], fillColor: color.withValues(alpha: 0.5), edgeColor: Colors.white));

    return Mesh3D(id: id, polygons: polys);
  }
}

// ============================================================================
// 4. 3D CAMERA (Camera3D)
// ============================================================================

class Camera3D {
  Vector3D position;
  double yaw;   // Rotation around Y
  double pitch; // Rotation around X
  double roll;  // Rotation around Z
  double fov;   // Field of view in radians (default 60 deg = pi/3)
  double near;
  double far;
  double shake;

  Camera3D({
    Vector3D? position,
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.fov = math.pi / 3,
    this.near = 1.0,
    this.far = 1500.0,
    this.shake = 0.0,
  }) : position = position ?? Vector3D(0, 20, -70);

  Vector3D get forward {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    return Vector3D(sy * cp, -sp, cy * cp).normalized();
  }

  Vector3D get right {
    return forward.cross(Vector3D(0, 1, 0)).normalized();
  }

  Vector3D get up {
    return right.cross(forward).normalized();
  }
}

// ============================================================================
// 5. 3D PARTICLES & LASERS
// ============================================================================

class Particle3D {
  Vector3D position;
  Vector3D velocity;
  double size;
  double life;
  double maxLife;
  Color color;

  Particle3D({
    required this.position,
    required this.velocity,
    required this.size,
    required this.life,
    required this.color,
  }) : maxLife = life;

  bool update(double dt) {
    position = position + velocity * dt;
    life -= dt;
    return life > 0;
  }
}

class Laser3D {
  Vector3D position;
  Vector3D velocity;
  double length;
  Color color;
  double damage;
  bool isEnemy;
  double life;

  Laser3D({
    required this.position,
    required this.velocity,
    this.length = 24.0,
    required this.color,
    required this.damage,
    this.isEnemy = false,
    this.life = 3.0,
  });

  bool update(double dt) {
    position = position + velocity * dt;
    life -= dt;
    return life > 0;
  }
}

// ============================================================================
// 6. TRUE 3D PIPELINE RENDERER (Engine3DPainter)
// ============================================================================

class Engine3DPainter extends CustomPainter {
  final Camera3D camera;
  final List<Mesh3D> meshes;
  final List<Laser3D> lasers;
  final List<Particle3D> particles;
  final bool drawGrid;
  final double gridOffsetZ;
  final Color gridColor;

  Engine3DPainter({
    required this.camera,
    required this.meshes,
    required this.lasers,
    required this.particles,
    this.drawGrid = true,
    this.gridOffsetZ = 0.0,
    this.gridColor = const Color(0xFF00E5FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double focalLength = (size.width / 2) / math.tan(camera.fov / 2);
    final Offset screenCenter = Offset(size.width / 2, size.height / 2);

    // Apply Camera Screen Shake if active
    Offset shakeOffset = Offset.zero;
    if (camera.shake > 0.05) {
      final rng = math.Random();
      shakeOffset = Offset(
        (rng.nextDouble() - 0.5) * camera.shake * 12.0,
        (rng.nextDouble() - 0.5) * camera.shake * 12.0,
      );
    }

    // 1. Draw 3D Infinite Cyber Grid Floor
    if (drawGrid) {
      _draw3DGroundGrid(canvas, size, focalLength, screenCenter + shakeOffset);
    }

    // 2. Transform & Depth-Sort All 3D Polygons
    final List<Polygon3D> renderQueue = [];
    final Vector3D sunDirection = Vector3D(-0.4, 0.8, -0.6).normalized();

    for (final mesh in meshes) {
      if (!mesh.isVisible) continue;

      for (final poly in mesh.polygons) {
        // Transform vertices: Model Space -> World Space
        final List<Vector3D> worldVertices = [];
        for (final v in poly.vertices) {
          // Scale
          var p = Vector3D(v.x * mesh.scale.x, v.y * mesh.scale.y, v.z * mesh.scale.z);
          // Rotation (Euler)
          p = p.rotateEuler(mesh.rotation);
          // Position
          p = p + mesh.position;
          worldVertices.add(p);
        }

        // World -> Camera View Space
        final List<Vector3D> viewVertices = [];
        for (final wv in worldVertices) {
          var p = wv - camera.position;
          // Rotate by inverse camera Euler (Yaw, Pitch, Roll)
          p = p.rotateY(-camera.yaw);
          p = p.rotateX(-camera.pitch);
          p = p.rotateZ(-camera.roll);
          viewVertices.add(p);
        }

        // Near Plane Clipping / Culling
        bool behindCamera = false;
        double depthSum = 0.0;
        for (final vv in viewVertices) {
          if (vv.z <= camera.near) {
            behindCamera = true;
            break;
          }
          depthSum += vv.z;
        }
        if (behindCamera) continue;

        // Surface Normal in View Space
        final edge1 = viewVertices[1] - viewVertices[0];
        final edge2 = viewVertices[2] - viewVertices[0];
        final viewNormal = edge1.cross(edge2).normalized();

        // Backface Culling (if not two-sided)
        if (!poly.twoSided) {
          // Camera looks down +Z in view space
          final viewDir = viewVertices[0].normalized();
          if (viewNormal.dot(viewDir) >= 0.0) {
            continue; // Facing away from camera
          }
        }

        // Perspective Projection: View Space -> Screen Space
        final List<Offset> screenPoints = [];
        for (final vv in viewVertices) {
          final factor = focalLength / vv.z;
          final sx = screenCenter.dx + shakeOffset.dx + vv.x * factor;
          final sy = screenCenter.dy + shakeOffset.dy - vv.y * factor;
          screenPoints.add(Offset(sx, sy));
        }

        // Directional Light Shading
        final transformedNormal = (poly.normal ?? viewNormal).rotateEuler(mesh.rotation);
        final lightIntensity = (transformedNormal.dot(sunDirection)).clamp(0.2, 1.0);
        final shadedColor = Color.lerp(
          Colors.black,
          poly.fillColor,
          0.35 + lightIntensity * 0.65,
        )!;

        // Setup Polygon for Rendering
        final preparedPoly = poly.copy();
        preparedPoly.projectedPoints = screenPoints;
        preparedPoly.averageDepth = depthSum / viewVertices.length;
        preparedPoly.illuminatedColor = shadedColor;
        renderQueue.add(preparedPoly);
      }
    }

    // 3. Painter's Algorithm: Sort polygons by average depth (furthest to nearest)
    renderQueue.sort((a, b) => b.averageDepth.compareTo(a.averageDepth));

    // 4. Rasterize Polygons with Antialiased Glowing Edges
    for (final poly in renderQueue) {
      if (poly.projectedPoints.length < 3) continue;

      final path = Path();
      path.moveTo(poly.projectedPoints[0].dx, poly.projectedPoints[0].dy);
      for (int i = 1; i < poly.projectedPoints.length; i++) {
        path.lineTo(poly.projectedPoints[i].dx, poly.projectedPoints[i].dy);
      }
      path.close();

      // Fill
      if (!poly.isWireframe) {
        final fillPaint = Paint()
          ..color = poly.illuminatedColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);
      }

      // Neon Wireframe Edge
      final edgePaint = Paint()
        ..color = poly.edgeColor
        ..strokeWidth = poly.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, edgePaint);
    }

    // 5. Render 3D Lasers
    _draw3DLasers(canvas, focalLength, screenCenter + shakeOffset);

    // 6. Render 3D Explosions & Engine Trail Particles
    _draw3DParticles(canvas, focalLength, screenCenter + shakeOffset);
  }

  void _draw3DGroundGrid(Canvas canvas, Size size, double focalLength, Offset screenCenter) {
    const double floorY = -35.0; // Beneath ship
    const double gridSpacing = 80.0;
    const int linesCount = 28;
    const double gridRange = 900.0;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;

    final glowPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.1)
      ..strokeWidth = 3.0;

    // Depth lines (parallel to Z)
    for (int i = -linesCount ~/ 2; i <= linesCount ~/ 2; i++) {
      final double wx = i * gridSpacing;
      final start = _projectWorldPoint(Vector3D(wx, floorY, 15), focalLength, screenCenter);
      final end = _projectWorldPoint(Vector3D(wx, floorY, gridRange), focalLength, screenCenter);
      if (start != null && end != null) {
        canvas.drawLine(start, end, gridPaint);
      }
    }

    // Horizontal lines (perpendicular to Z, scrolling)
    final zOffset = gridOffsetZ % gridSpacing;
    for (double z = 20.0; z <= gridRange; z += gridSpacing) {
      final effectiveZ = z - zOffset;
      if (effectiveZ < 10) continue;

      final start = _projectWorldPoint(Vector3D(-gridRange * 0.8, floorY, effectiveZ), focalLength, screenCenter);
      final end = _projectWorldPoint(Vector3D(gridRange * 0.8, floorY, effectiveZ), focalLength, screenCenter);
      if (start != null && end != null) {
        final distFactor = (1.0 - (effectiveZ / gridRange)).clamp(0.0, 1.0);
        gridPaint.color = gridColor.withValues(alpha: 0.35 * distFactor);
        canvas.drawLine(start, end, gridPaint);
        if (effectiveZ < 300) {
          canvas.drawLine(start, end, glowPaint);
        }
      }
    }
  }

  void _draw3DLasers(Canvas canvas, double focalLength, Offset screenCenter) {
    for (final laser in lasers) {
      final p1 = _projectWorldPoint(laser.position, focalLength, screenCenter);
      final p2 = _projectWorldPoint(laser.position + laser.velocity.normalized() * laser.length, focalLength, screenCenter);

      if (p1 != null && p2 != null) {
        // Laser Core
        final laserPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, laserPaint);

        // Laser Neon Glow
        final glowPaint = Paint()
          ..color = laser.color
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, glowPaint);
      }
    }
  }

  void _draw3DParticles(Canvas canvas, double focalLength, Offset screenCenter) {
    for (final particle in particles) {
      final p = _projectWorldPoint(particle.position, focalLength, screenCenter);
      if (p != null) {
        // View depth scaling
        final viewZ = (particle.position - camera.position).z;
        final scale = (focalLength / (viewZ > 1.0 ? viewZ : 1.0)).clamp(0.3, 4.0);
        final alpha = (particle.life / particle.maxLife).clamp(0.0, 1.0);

        final particlePaint = Paint()
          ..color = particle.color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, particle.size * scale, particlePaint);
      }
    }
  }

  Offset? _projectWorldPoint(Vector3D worldPoint, double focalLength, Offset screenCenter) {
    var p = worldPoint - camera.position;
    p = p.rotateY(-camera.yaw);
    p = p.rotateX(-camera.pitch);
    p = p.rotateZ(-camera.roll);

    if (p.z <= camera.near) return null;

    final factor = focalLength / p.z;
    final sx = screenCenter.dx + p.x * factor;
    final sy = screenCenter.dy - p.y * factor;
    return Offset(sx, sy);
  }

  @override
  bool shouldRepaint(covariant Engine3DPainter oldDelegate) => true;
}
