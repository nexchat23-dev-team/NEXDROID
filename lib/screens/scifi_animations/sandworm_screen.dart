import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class SandwormScreen extends StatelessWidget {
  static const String routeName = '/scifi/sandworm';
  const SandwormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'dune_sandworm');
  }
}
