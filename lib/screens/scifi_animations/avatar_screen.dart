import 'package:flutter/material.dart';
import 'scifi_detail_screen.dart';

class AvatarBansheeScreen extends StatelessWidget {
  static const String routeName = '/scifi/avatar';
  const AvatarBansheeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SciFiDetailScreen(animationId: 'avatar_banshee');
  }
}
