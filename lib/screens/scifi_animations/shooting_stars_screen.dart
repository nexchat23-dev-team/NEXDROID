import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class ShootingStarsScreen extends StatelessWidget {
  static const String routeName = '/scifi/shooting-stars';
  const ShootingStarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'shooting_stars_field');
  }
}
