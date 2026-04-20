import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/activity_entity.dart';

class ActivityStatsSummary {
  final int activitiesCount;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int weeklyStreak;
  final int bestDistanceMeters;
  final double averageDistanceKm;

  const ActivityStatsSummary({
    required this.activitiesCount,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.weeklyStreak,
    required this.bestDistanceMeters,
    required this.averageDistanceKm,
  });

  factory ActivityStatsSummary.fromActivities(List<ActivityEntity> activities) {
    if (activities.isEmpty) {
      return const ActivityStatsSummary(
        activitiesCount: 0,
        totalDistanceKm: 0,
        totalDurationSeconds: 0,
        weeklyStreak: 0,
        bestDistanceMeters: 0,
        averageDistanceKm: 0,
      );
    }

    final totalDistanceMeters = activities.fold<double>(
      0,
      (sum, a) => sum + a.distanceMeters,
    );
    final totalDurationSeconds = activities.fold<int>(
      0,
      (sum, a) => sum + a.durationSeconds,
    );
    final bestDistanceMeters = activities
        .map((a) => a.distanceMeters.toInt())
        .fold<int>(0, (best, current) => current > best ? current : best);

    return ActivityStatsSummary(
      activitiesCount: activities.length,
      totalDistanceKm: totalDistanceMeters / 1000,
      totalDurationSeconds: totalDurationSeconds,
      weeklyStreak: _computeWeeklyStreak(activities),
      bestDistanceMeters: bestDistanceMeters,
      averageDistanceKm: (totalDistanceMeters / activities.length) / 1000,
    );
  }

  static int _computeWeeklyStreak(List<ActivityEntity> activities) {
    final now = DateTime.now();
    final sortedWeeks =
        activities.map((a) => _weekKey(a.startedAt)).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    if (sortedWeeks.isEmpty) return 0;

    final currentWeek = _weekKey(now);
    var expectedWeek = currentWeek;
    var streak = 0;

    for (final week in sortedWeeks) {
      if (week == expectedWeek) {
        streak += 1;
        expectedWeek -= 1;
      } else if (week < expectedWeek) {
        break;
      }
    }

    return streak;
  }

  static int _weekKey(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays;
    return date.year * 100 + (dayOfYear ~/ 7);
  }
}

class ActivityStatsRecapCard extends StatelessWidget {
  final ActivityStatsSummary summary;
  final String title;
  final String subtitle;

  const ActivityStatsRecapCard({
    super.key,
    required this.summary,
    this.title = 'Bien ouej !',
    this.subtitle = 'Récap de tes stats',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.londrinaSolid(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  emoji: '🏃',
                  value: summary.activitiesCount.toString(),
                  label: 'Activités',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  emoji: '📏',
                  value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                  label: 'Distance',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  emoji: '🔥',
                  value: '${summary.weeklyStreak} sem.',
                  label: 'Série active',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  emoji: '⭐',
                  value:
                      '${(summary.bestDistanceMeters / 1000).toStringAsFixed(1)} km',
                  label: 'Meilleure sortie',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityTimelineList extends StatelessWidget {
  final List<ActivityEntity> activities;

  const ActivityTimelineList({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Aucune activité pour le moment.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: activities
          .map((activity) => _ActivityRow(activity: activity))
          .toList(),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _MetricTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntity activity;

  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('dd MMM · HH:mm').format(activity.startedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_run_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.distanceKm.toStringAsFixed(2)} km',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${activity.formattedDuration}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (activity.avgPaceSecondsPerKm != null)
            Text(
              _formatPace(activity.avgPaceSecondsPerKm!),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }
}
