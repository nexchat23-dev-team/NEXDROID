import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class OptimusScreen extends StatelessWidget {
  static const String routeName = '/scifi/optimus';
  const OptimusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'optimus_transform');
  }
}
