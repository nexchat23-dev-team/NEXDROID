import 'package:flutter/material.dart';

class GameCategory {
  const GameCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.levels,
    required this.badges,
    required this.description,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int levels;
  final List<String> badges;
  final String description;
}
