import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class GrootScreen extends StatelessWidget {
  static const String routeName = '/scifi/groot';
  const GrootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'groot_growth');
  }
}
