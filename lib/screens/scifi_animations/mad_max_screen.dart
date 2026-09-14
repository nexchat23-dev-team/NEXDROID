import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class MadMaxScreen extends StatelessWidget {
  static const String routeName = '/scifi/mad-max';
  const MadMaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'fury_road_fire');
  }
}
