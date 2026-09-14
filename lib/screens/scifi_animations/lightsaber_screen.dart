import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class LightsaberScreen extends StatelessWidget {
  static const String routeName = '/scifi/lightsaber';
  const LightsaberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'lightsaber_duel');
  }
}
