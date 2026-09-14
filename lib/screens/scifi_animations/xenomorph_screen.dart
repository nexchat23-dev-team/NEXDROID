import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class XenomorphScreen extends StatelessWidget {
  static const String routeName = '/scifi/xenomorph';
  const XenomorphScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'xenomorph_shadow');
  }
}
