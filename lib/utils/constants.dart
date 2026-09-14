import 'package:flutter/material.dart';

const kNeonGreen = Color(0xFF25D366);
const kNeonBlue = Color(0xFF00B8F4);
const kNeonPurple = Color(0xFFB23BFF);
const kNeonDarkPurple = Color(0xFF7D2DDF);
const kNeonDarkGreen = Color(0xFF1BA844);
const kPrimaryGreen = Color(0xFF075E54);
const kPrimaryBlue = Color(0xFF054A85);
const kDarkBackground = Color(0xFF0F0717);
const kSurfaceColor = Color(0xFF1A0E2E);

extension ColorValues on Color {
  Color withValues({double? alpha}) {
    if (alpha == null) return this;
    return withAlpha((alpha.clamp(0.0, 1.0) * 255).round());
  }
}
