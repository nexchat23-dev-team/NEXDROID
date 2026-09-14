import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class MandalorianScreen extends StatelessWidget {
  static const String routeName = '/scifi/mandalorian';
  const MandalorianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'mandalorian_jetpack');
  }
}
