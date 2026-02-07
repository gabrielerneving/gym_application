import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class StatCard extends ConsumerWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool isPrimary;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.isPrimary = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeIndex = ref.watch(themeIndexProvider);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // Use gradient only for primary cards in pink theme
        gradient: isPrimary && themeIndex == 1 ? theme.primaryGradient : null,
        color: isPrimary && themeIndex == 1 ? null : (isPrimary ? theme.primary : theme.card),
        borderRadius: BorderRadius.circular(20),
        border: isPrimary
            ? null
            : Border.all(
                color: theme.textSecondary.withOpacity(0.2),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: isPrimary ? Colors.white : theme.primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isPrimary ? Colors.white.withOpacity(0.8) : theme.textSecondary, fontSize: 14)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isPrimary ? Colors.white : theme.text,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: TextStyle(color: isPrimary ? Colors.white.withOpacity(0.8) : theme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}