import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class WormholeScreen extends StatelessWidget {
  static const String routeName = '/scifi/wormhole';
  const WormholeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'interstellar_wormhole');
  }
}
