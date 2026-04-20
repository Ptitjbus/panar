import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

class RunLaunchPage extends ConsumerWidget {
  const RunLaunchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background: place art placeholder
          Positioned.fill(
            child: Container(color: AppColors.surface),
          ),

          // Mascot centered
          Positioned.fill(
            child: Center(
              child: AnimatedAvatarWidget(
                isMoving: false,
                size: 260,
                colorFilter: const Color(0xFFF4A574),
                showShadow: true,
              ),
            ),
          ),

          // Top back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ),

          // Bottom action panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("C'est l'heure de courir !", style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Choisis ton mode de course', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),

                  _RunModeButton(
                    label: 'Course libre',
                    subtitle: 'Courez à votre rythme, sans objectif imposé.',
                    icon: Icons.directions_run,
                    onTap: () => context.push(Routes.runTracking),
                  ),
                  const SizedBox(height: 12),
                  _RunModeButton(
                    label: 'Parcours généré',
                    subtitle: 'Bientôt disponible',
                    icon: Icons.map_outlined,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push(Routes.runImport),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.health_and_safety_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Importer depuis Santé', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _RunModeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (enabled)
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
