import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/profile_model.dart';

class ProfileRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ProfileRemoteDataSource(this._supabaseClient);

  Future<ProfileModel> getProfile(String userId) async {
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return ProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get profile: $e');
    }
  }

  Future<void> updateUsername(String userId, String username) async {
    try {
      await _supabaseClient
          .from('profiles')
          .update({
            'username': username,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const DatabaseFailure('Username is already taken');
      }
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update username: $e');
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      return response == null;
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to check username availability: $e');
    }
  }

  Future<void> markOnboardingComplete(
    String userId, {
    String? avatarColor,
  }) async {
    try {
      final updates = <String, dynamic>{
        'has_completed_onboarding': true,
        'onboarding_username_done': true,
        'onboarding_avatar_done': true,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (avatarColor != null) updates['avatar_color'] = avatarColor;

      await _supabaseClient.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to mark onboarding complete: $e');
    }
  }

  Future<void> updateOnboardingProgress({
    required String userId,
    int? onboardingActivityIndex,
    int? onboardingTimeIndex,
    bool? onboardingUsernameDone,
    bool? onboardingLocationPermissionGranted,
    bool? onboardingNotificationsPermissionGranted,
    bool? onboardingAvatarDone,
    String? avatarColor,
    bool? hasCompletedOnboarding,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (onboardingActivityIndex != null) {
        updates['onboarding_activity_index'] = onboardingActivityIndex;
      }
      if (onboardingTimeIndex != null) {
        updates['onboarding_time_index'] = onboardingTimeIndex;
      }
      if (onboardingUsernameDone != null) {
        updates['onboarding_username_done'] = onboardingUsernameDone;
      }
      if (onboardingLocationPermissionGranted != null) {
        updates['onboarding_location_permission_granted'] =
            onboardingLocationPermissionGranted;
      }
      if (onboardingNotificationsPermissionGranted != null) {
        updates['onboarding_notifications_permission_granted'] =
            onboardingNotificationsPermissionGranted;
      }
      if (onboardingAvatarDone != null) {
        updates['onboarding_avatar_done'] = onboardingAvatarDone;
      }
      if (avatarColor != null) {
        updates['avatar_color'] = avatarColor;
      }
      if (hasCompletedOnboarding != null) {
        updates['has_completed_onboarding'] = hasCompletedOnboarding;
      }

      await _supabaseClient.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update onboarding progress: $e');
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
    String? avatarColor,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (avatarColor != null) updates['avatar_color'] = avatarColor;

      await _supabaseClient.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update profile: $e');
    }
  }
}

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return ProfileRemoteDataSource(supabaseClient);
});
