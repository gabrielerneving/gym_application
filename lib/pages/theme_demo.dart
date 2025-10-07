import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

/// Demo page to show theme switching
class ThemeDemo extends ConsumerWidget {
  const ThemeDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.card,
        title: Text(
          'Theme Demo',
          style: TextStyle(color: theme.text),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme switcher
            Text(
              'Choose Theme:',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ThemeButton(
                  theme: AppTheme.darkRedTheme,
                  label: 'Dark Red',
                  isSelected: theme == AppTheme.darkRedTheme,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppTheme.darkRedTheme),
                ),
                const SizedBox(width: 16),
                _ThemeButton(
                  theme: AppTheme.pinkTheme,
                  label: 'Pink',
                  isSelected: theme == AppTheme.pinkTheme,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(AppTheme.pinkTheme),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Demo elements
            Text(
              'Demo Elements:',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Primary button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Primary Button',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card example
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.surface),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example Card',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is an example of how cards look with the current theme.',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star, color: theme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Primary accent color',
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Color showcase
            Text(
              'Color Palette:',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ColorSwatch(color: theme.primary, label: 'Primary'),
                _ColorSwatch(color: theme.accent, label: 'Accent'),
                _ColorSwatch(color: theme.card, label: 'Card'),
                _ColorSwatch(color: theme.surface, label: 'Surface'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final AppColors theme;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.theme,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary : theme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.primary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.primary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends ConsumerWidget {
  final Color color;
  final String label;

  const _ColorSwatch({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.surface),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}