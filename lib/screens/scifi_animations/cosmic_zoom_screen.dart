import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class CosmicZoomScreen extends StatelessWidget {
  static const String routeName = '/scifi/cosmic-zoom';
  const CosmicZoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'cosmic_zoom_bigbang');
  }
}
