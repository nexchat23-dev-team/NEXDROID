import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class TerminatorScreen extends StatelessWidget {
  static const String routeName = '/scifi/terminator';
  const TerminatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'terminator_endoskeleton');
  }
}
