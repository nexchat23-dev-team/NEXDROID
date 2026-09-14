import 'package:flutter/material.dart';
import '../utils/constants.dart';

class HubFeature {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HubFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class HubFeaturePanel extends StatelessWidget {
  final VoidCallback onSearch;
  final List<HubFeature> features;

  const HubFeaturePanel({
    super.key,
    required this.onSearch,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D162E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACCESS',
            style: TextStyle(
                color: kNeonPurple,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070B14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search the network',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kNeonPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('SEARCH',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: features.map((feature) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 72) / 2,
                child: _HubFeatureCard(feature: feature),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HubFeatureCard extends StatelessWidget {
  final HubFeature feature;

  const _HubFeatureCard({
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: feature.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1226),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(feature.icon, color: feature.color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(feature.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text(feature.subtitle,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
