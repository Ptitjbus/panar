import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../models/avatar_model.dart';

/// Remote data source for avatar operations using Supabase
class AvatarRemoteDataSource {
  final SupabaseClient _supabaseClient;

  AvatarRemoteDataSource(this._supabaseClient);

  /// Get user avatar by user ID
  Future<AvatarModel> getAvatar(String userId) async {
    try {
      final response = await _supabaseClient
          .from('avatars')
          .select()
          .eq('user_id', userId)
          .single();

      return AvatarModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get avatar: $e');
    }
  }

  /// Get avatars for multiple users
  Future<List<AvatarModel>> getAvatars(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final response = await _supabaseClient
          .from('avatars')
          .select()
          .inFilter('user_id', userIds);

      return (response as List)
          .map((json) => AvatarModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get avatars: $e');
    }
  }

  /// Create avatar for user
  Future<AvatarModel> createAvatar(String userId, String? displayName) async {
    // List of soft pastel colors
    final colors = [
      '#FF6B6B',
      '#4ECDC4',
      '#45B7D1',
      '#FFA07A',
      '#98D8C8',
      '#F7DC6F',
      '#BB8FCE',
      '#85C1E2',
    ];

    // Pick a random color
    final randomColor = (colors..shuffle()).first;

    try {
      final response = await _supabaseClient
          .from('avatars')
          .insert({
            'user_id': userId,
            'display_name': displayName,
            'color_hex': randomColor,
          })
          .select()
          .single();

      return AvatarModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to create avatar: $e');
    }
  }

  /// Update avatar customizations for user
  Future<AvatarModel> updateAvatar({
    required String userId,
    String? displayName,
    String? colorHex,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) {
        updates['display_name'] = displayName.trim().isEmpty ? null : displayName.trim();
      }
      if (colorHex != null) {
        updates['color_hex'] = colorHex;
      }

      final response = await _supabaseClient
          .from('avatars')
          .update(updates)
          .eq('user_id', userId)
          .select()
          .single();

      return AvatarModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to update avatar: $e');
    }
  }
}

/// Provider for AvatarRemoteDataSource
final avatarRemoteDataSourceProvider = Provider<AvatarRemoteDataSource>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return AvatarRemoteDataSource(supabaseClient);
});
