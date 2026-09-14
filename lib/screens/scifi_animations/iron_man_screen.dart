import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class IronManScreen extends StatelessWidget {
  static const String routeName = '/scifi/iron-man';
  const IronManScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'iron_man_arc');
  }
}
