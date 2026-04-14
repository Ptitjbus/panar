import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../domain/entities/activity_entity.dart';

/// Provider for user activities by user ID
/// Fetches the most recent activities (limited to 10)
final userActivitiesProvider =
    FutureProvider.family<List<ActivityEntity>, String>((ref, userId) async {
      final activityRepository = ref.watch(activityRepositoryProvider);
      return await activityRepository.getUserActivities(userId, limit: 10);
    });
