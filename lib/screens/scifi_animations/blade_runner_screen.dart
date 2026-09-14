import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class BladeRunnerScreen extends StatelessWidget {
  static const String routeName = '/scifi/blade-runner';
  const BladeRunnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'blade_runner_spinner');
  }
}
