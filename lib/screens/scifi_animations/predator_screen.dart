import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class PredatorScreen extends StatelessWidget {
  static const String routeName = '/scifi/predator';
  const PredatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'predator_cloak');
  }
}
