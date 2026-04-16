import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../activities/domain/entities/activity_entity.dart';
import '../../../activities/presentation/providers/activity_provider.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

/// Drawer displaying user information when an avatar is clicked
class UserDrawer extends ConsumerWidget {
  final AvatarEntity avatar;
  final String? email;
  /// Called when the user taps "Voir en direct" (only provided when the friend is running)
  final VoidCallback? onViewLive;

  const UserDrawer({
    super.key,
    required this.avatar,
    this.email,
    this.onViewLive,
  });

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF4ECDC4);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarColor = _parseColor(avatar.colorHex);
    final activitiesAsync = ref.watch(userActivitiesProvider(avatar.userId));

    return SafeArea(
      child: Column(
        children: [
          // Header section with avatar and user info
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              children: [
                // Large avatar animation
                AnimatedAvatarWidget(
                  isMoving: false,
                  size: 160,
                  colorFilter: avatarColor,
                  showShadow: true,
                ),
                const SizedBox(height: 24),
                // Display name
                Text(
                  avatar.displayName ?? 'Utilisateur',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                // Email
                if (email != null)
                  Text(
                    email!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                // "Voir en direct" button when the friend is currently running
                if (onViewLive != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onViewLive,
                    icon: const Icon(Icons.directions_run, size: 18),
                    label: const Text('Voir en direct'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Activities section
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erreur lors du chargement des activités',
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (activities) {
                if (activities.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucune activité',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Text(
                      'Activités (${activities.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...activities.map(
                      (activity) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityCard(
                          activity: activity,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity card displaying activity information
class _ActivityCard extends StatelessWidget {
  final ActivityEntity activity;
  final ColorScheme colorScheme;

  const _ActivityCard({required this.activity, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and time
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(activity.startedAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${activity.distanceKm.toStringAsFixed(2)} km',
                  colorScheme: colorScheme,
                ),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.timer,
                  label: 'Durée',
                  value: activity.formattedDuration,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (activity.formattedPace != null)
                Expanded(
                  child: _StatItem(
                    icon: Icons.speed,
                    label: 'Allure',
                    value: activity.formattedPace!,
                    colorScheme: colorScheme,
                  ),
                ),
              if (activity.calories != null)
                Expanded(
                  child: _StatItem(
                    icon: Icons.local_fire_department,
                    label: 'Calories',
                    value: '${activity.calories!.toStringAsFixed(0)} kcal',
                    colorScheme: colorScheme,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual stat item
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
