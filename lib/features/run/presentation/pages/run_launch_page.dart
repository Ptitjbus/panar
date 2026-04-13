import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';

class RunLaunchPage extends ConsumerWidget {
  const RunLaunchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Courir')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Choisissez un mode',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Course libre
            _ModeCard(
              icon: Icons.directions_run,
              title: 'Course libre',
              subtitle: 'Courez à votre rythme, sans objectif imposé.',
              enabled: true,
              onTap: () => context.push(Routes.runTracking),
            ),

            const SizedBox(height: 16),

            // Parcours généré — désactivé
            const _ModeCard(
              icon: Icons.map_outlined,
              title: 'Parcours généré',
              subtitle: 'Un parcours adapté à vos objectifs. Bientôt disponible.',
              enabled: false,
              badge: 'Bientôt',
            ),

            const Spacer(),

            // Importer depuis Santé
            TextButton.icon(
              onPressed: () => context.push(Routes.runImport),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Importer depuis Santé'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String? badge;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badge!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
