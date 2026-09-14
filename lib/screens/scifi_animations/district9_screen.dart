import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class District9Screen extends StatelessWidget {
  static const String routeName = '/scifi/district9';
  const District9Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'district9_mech');
  }
}
