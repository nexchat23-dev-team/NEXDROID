import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class AlienInvasionScreen extends StatelessWidget {
  static const String routeName = '/scifi/alien-invasion';
  const AlienInvasionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'alien_invasion_ship');
  }
}
