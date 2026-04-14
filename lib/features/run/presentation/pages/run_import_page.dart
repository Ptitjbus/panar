import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';

import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/petons_datasource.dart';
import '../../data/repositories/run_repository_impl.dart';
import '../../data/services/health_service.dart';
import '../../domain/entities/gps_point_entity.dart';

/// Provider qui charge les workouts externes depuis Apple Health / Health Connect
/// des 30 derniers jours.
final _externalWorkoutsProvider =
    FutureProvider.autoDispose<List<HealthDataPoint>>((ref) async {
      final service = ref.watch(healthServiceProvider);
      await service.requestPermissions();
      final since = DateTime.now().subtract(const Duration(days: 30));
      return service.getExternalWorkouts(since);
    });

class RunImportPage extends ConsumerWidget {
  const RunImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!Platform.isIOS && !Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Importer depuis Santé')),
        body: const Center(
          child: Text('Disponible sur iOS et Android uniquement.'),
        ),
      );
    }

    final workoutsAsync = ref.watch(_externalWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer depuis Santé'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: workoutsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Impossible d\'accéder à Santé.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                Platform.isIOS
                    ? 'Activez HealthKit dans Xcode puis autorisez l\'accès dans Réglages > Santé.'
                    : 'Installez Health Connect et accordez les permissions.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (workouts) {
          if (workouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune course trouvée',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune course des 30 derniers jours dans Santé.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final point = workouts[index];
              final val = point.value;
              double? distanceMeters;
              double? calories;
              if (val is WorkoutHealthValue) {
                distanceMeters = val.totalDistance?.toDouble();
                calories = val.totalEnergyBurned?.toDouble();
              }

              return _WorkoutImportCard(
                point: point,
                distanceMeters: distanceMeters,
                calories: calories,
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkoutImportCard extends ConsumerStatefulWidget {
  final HealthDataPoint point;
  final double? distanceMeters;
  final double? calories;

  const _WorkoutImportCard({
    required this.point,
    this.distanceMeters,
    this.calories,
  });

  @override
  ConsumerState<_WorkoutImportCard> createState() => _WorkoutImportCardState();
}

class _WorkoutImportCardState extends ConsumerState<_WorkoutImportCard> {
  bool _importing = false;
  bool _imported = false;

  Future<void> _import() async {
    setState(() => _importing = true);

    final userId = ref.read(authStateProvider).value?.id;
    if (userId == null) {
      setState(() => _importing = false);
      return;
    }

    final start = widget.point.dateFrom;
    final end = widget.point.dateTo;
    final durationSec = end.difference(start).inSeconds;
    final distM = widget.distanceMeters ?? 0;
    final pace = distM > 0 && durationSec > 0
        ? (durationSec / (distM / 1000)).round()
        : null;

    try {
      await ref
          .read(runRepositoryProvider)
          .saveActivity(
            userId: userId,
            startedAt: start,
            endedAt: end,
            durationSeconds: durationSec,
            distanceMeters: distM,
            avgPaceSecondsPerKm: pace,
            points: const <GpsPointEntity>[],
          );

      // Attribuer les petons
      final petons = distM > 0 ? (distM / 100).floor().clamp(1, 9999) : 1;
      await ref.read(petonsDatasourceProvider).awardPetons(userId, petons);

      if (mounted) setState(() => _imported = true);
    } catch (_) {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = widget.point.dateFrom;
    final end = widget.point.dateTo;
    final duration = end.difference(start);
    final distKm = (widget.distanceMeters ?? 0) / 1000;

    final dateStr = '${start.day}/${start.month}/${start.year}';
    final durationStr =
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_run,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${distKm.toStringAsFixed(2)} km · $durationStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_imported)
              Icon(Icons.check_circle, color: Colors.green)
            else
              SizedBox(
                width: 90,
                child: CustomButton(
                  text: _importing ? '...' : 'Importer',
                  isLoading: _importing,
                  onPressed: _importing ? null : _import,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
