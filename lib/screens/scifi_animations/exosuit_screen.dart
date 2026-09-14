import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class ExosuitScreen extends StatelessWidget {
  static const String routeName = '/scifi/exosuit';
  const ExosuitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'exosuit_powerup');
  }
}
