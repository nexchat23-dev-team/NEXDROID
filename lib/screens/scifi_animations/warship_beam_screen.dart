import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class WarshipBeamScreen extends StatelessWidget {
  static const String routeName = '/scifi/warship-beam';
  const WarshipBeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'warship_beam_cannon');
  }
}
