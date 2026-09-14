import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class RobocopScreen extends StatelessWidget {
  static const String routeName = '/scifi/robocop';
  const RobocopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'robocop_hud');
  }
}
