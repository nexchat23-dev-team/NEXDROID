import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class MultipassScreen extends StatelessWidget {
  static const String routeName = '/scifi/multipass';
  const MultipassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'multipass_holo');
  }
}
