import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Virtual Joystick
class VirtualJoystick extends StatefulWidget {
  final double size;
  final Color baseColor;
  final Color knobColor;
  final void Function(Offset direction) onDirectionChanged;

  const VirtualJoystick({
    Key? key,
    this.size = 120.0,
    this.baseColor = const Color(0xFF00B8F4),
    this.knobColor = const Color(0xFF25D366),
    required this.onDirectionChanged,
  }) : super(key: key);

  @override
  _VirtualJoystickState createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  final double _deadZoneRadius = 0.15;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animationController.addListener(() {
      setState(() {
        _position = _animation.value;
      });
      _notifyDirection();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _animationController.stop();
    _updatePosition(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updatePosition(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _animation = Tween<Offset>(begin: _position, end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward(from: 0.0);
  }

  void _updatePosition(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final offsetFromCenter = localPosition - center;
    final maxRadius = widget.size / 2 - 20; // 20 is knob radius
    
    double distance = offsetFromCenter.distance;
    if (distance > maxRadius) {
      final ratio = maxRadius / distance;
      _position = offsetFromCenter * ratio;
    } else {
      _position = offsetFromCenter;
    }
    setState(() {});
    _notifyDirection();
  }

  void _notifyDirection() {
    final maxRadius = widget.size / 2 - 20;
    double normalizedX = _position.dx / maxRadius;
    double normalizedY = _position.dy / maxRadius;
    
    double distance = sqrt(normalizedX * normalizedX + normalizedY * normalizedY);
    if (distance < _deadZoneRadius) {
      widget.onDirectionChanged(Offset.zero);
    } else {
      widget.onDirectionChanged(Offset(normalizedX, normalizedY));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.baseColor.withOpacity(0.1),
          border: Border.all(color: widget.baseColor.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.baseColor.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 5,
            )
          ],
        ),
        child: CustomPaint(
          painter: _GridPainter(widget.baseColor),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: _position,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.knobColor,
                    boxShadow: [
                      BoxShadow(
                        color: widget.knobColor.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw crosshairs
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    
    // Draw inner circles
    canvas.drawCircle(center, radius * 0.33, paint);
    canvas.drawCircle(center, radius * 0.66, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Action Button
class ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final double size;

  const ActionButton({
    Key? key,
    required this.icon,
    required this.color,
    this.label = '',
    this.onPressed,
    this.onPressStart,
    this.onPressEnd,
    this.size = 60.0,
  }) : super(key: key);

  @override
  _ActionButtonState createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _controller.forward();
    if (widget.onPressStart != null) {
      widget.onPressStart!();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onPressed != null) {
      widget.onPressed!();
    }
    if (widget.onPressEnd != null) {
      widget.onPressEnd!();
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
    if (widget.onPressEnd != null) {
      widget.onPressEnd!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.2),
                border: Border.all(color: widget.color.withOpacity(0.8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: widget.color.withOpacity(0.8), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// FPS Control Overlay
class FPSControlOverlay extends StatelessWidget {
  final Function(Offset) onMove;
  final Function(Offset) onAim;
  final VoidCallback onFire;
  final VoidCallback onReload;
  final VoidCallback onSpecial;
  final int ammo;
  final int maxAmmo;

  const FPSControlOverlay({
    Key? key,
    required this.onMove,
    required this.onAim,
    required this.onFire,
    required this.onReload,
    required this.onSpecial,
    required this.ammo,
    required this.maxAmmo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left Joystick - Movement
        Positioned(
          left: 40,
          bottom: 40,
          child: VirtualJoystick(
            size: 140,
            baseColor: const Color(0xFF00B8F4), // Neon Blue
            knobColor: Colors.white,
            onDirectionChanged: onMove,
          ),
        ),
        
        // Right Joystick - Aiming
        Positioned(
          right: 200,
          bottom: 40,
          child: VirtualJoystick(
            size: 140,
            baseColor: const Color(0xFFB23BFF), // Neon Purple
            knobColor: Colors.white,
            onDirectionChanged: onAim,
          ),
        ),
        
        // Fire Button
        Positioned(
          right: 40,
          bottom: 60,
          child: ActionButton(
            icon: Icons.whatshot,
            color: const Color(0xFFFF3B30),
            label: "FIRE",
            size: 80,
            onPressed: onFire,
            onPressStart: () => HapticFeedback.heavyImpact(),
          ),
        ),
        
        // Reload Button
        Positioned(
          right: 50,
          bottom: 160,
          child: ActionButton(
            icon: Icons.refresh,
            color: const Color(0xFFFFCC00),
            label: "RELOAD",
            size: 50,
            onPressed: onReload,
          ),
        ),
        
        // Special/Grenade Button
        Positioned(
          right: 140,
          bottom: 40,
          child: ActionButton(
            icon: Icons.sports_baseball, // Grenade-like icon
            color: const Color(0xFF25D366),
            label: "GRENADE",
            size: 50,
            onPressed: onSpecial,
          ),
        ),
        
        // Ammo Counter
        Positioned(
          right: 40,
          top: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00B8F4).withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B8F4).withOpacity(0.2),
                  blurRadius: 10,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.line_weight, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  "$ammo / $maxAmmo",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
