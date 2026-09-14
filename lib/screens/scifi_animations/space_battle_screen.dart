import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class SpaceBattleScreen extends StatelessWidget {
  static const String routeName = '/scifi/space-battle';
  const SpaceBattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'space_battle_war');
  }
}
