import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/profile_model.dart';

/// Remote data source for profile operations using Supabase
class ProfileRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ProfileRemoteDataSource(this._supabaseClient);

  /// Get user profile by ID
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

  /// Update username
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
        // Unique constraint violation
        throw const DatabaseFailure('Username is already taken');
      }
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update username: $e');
    }
  }

  /// Check if username is available
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

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete(String userId) async {
    try {
      await _supabaseClient
          .from('profiles')
          .update({
            'has_completed_onboarding': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to mark onboarding complete: $e');
    }
  }

  /// Update profile
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabaseClient.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update profile: $e');
    }
  }
}

/// Provider for ProfileRemoteDataSource
final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return ProfileRemoteDataSource(supabaseClient);
});
