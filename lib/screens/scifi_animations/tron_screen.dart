import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class TronScreen extends StatelessWidget {
  static const String routeName = '/scifi/tron';
  const TronScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'tron_grid');
  }
}
