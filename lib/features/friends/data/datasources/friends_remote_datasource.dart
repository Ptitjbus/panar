import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../profile/data/models/profile_model.dart';
import '../models/friendship_model.dart';

/// Remote data source for friends operations using Supabase
class FriendsRemoteDataSource {
  final SupabaseClient _supabaseClient;

  FriendsRemoteDataSource(this._supabaseClient);

  /// Search users by username (case-insensitive) using RPC
  Future<List<ProfileModel>> searchUsersByUsername(String username) async {
    try {
      final response = await _supabaseClient
          .rpc('search_potential_friends', params: {'search_term': username})
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to search users: $e');
    }
  }

  /// Send a friend request
  Future<void> sendFriendRequest({
    required String requesterId,
    required String addresseeId,
  }) async {
    try {
      await _supabaseClient
          .from('friendships')
          .insert({
            'requester_id': requesterId,
            'addressee_id': addresseeId,
            'status': 'pending',
          })
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
        throw const DatabaseFailure(
          'Vous avez déjà envoyé une demande à cet utilisateur',
        );
      } else if (e.code == '23514') {
        // Check constraint violation (self-add)
        throw const DatabaseFailure(
          'Vous ne pouvez pas vous ajouter vous-même',
        );
      } else if (e.code == '42501') {
        // RLS policy violation
        throw const DatabaseFailure('Action non autorisée');
      }
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to send friend request: $e');
    }
  }

  /// Accept a friend request using atomic RPC
  Future<void> acceptFriendRequest(String friendshipId) async {
    try {
      await _supabaseClient
          .rpc(
            'accept_friend_request',
            params: {'p_friendship_id': friendshipId},
          )
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        // RAISE EXCEPTION from PL/pgSQL
        throw DatabaseFailure(e.message);
      }
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to accept friend request: $e');
    }
  }

  /// Reject a friend request (delete row)
  Future<void> rejectFriendRequest(String friendshipId) async {
    try {
      await _supabaseClient
          .from('friendships')
          .delete()
          .eq('id', friendshipId)
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to reject friend request: $e');
    }
  }

  /// Remove a friend using atomic RPC
  Future<void> removeFriend(String friendshipId) async {
    try {
      await _supabaseClient
          .rpc('remove_friend', params: {'p_friendship_id': friendshipId})
          .timeout(const Duration(seconds: 10));
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        throw DatabaseFailure(e.message);
      }
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to remove friend: $e');
    }
  }

  /// Get friendships with optional status filter and profile join
  Future<List<FriendshipModel>> getFriendships({
    required String userId,
    String? status,
    bool? isRequester,
  }) async {
    try {
      // Join profiles to avoid N+1 queries
      var query = _supabaseClient.from('friendships').select('''
        *,
        requester:profiles!friendships_requester_id_fkey(*),
        addressee:profiles!friendships_addressee_id_fkey(*)
      ''');

      // Filter by user being either requester or addressee
      if (isRequester == true) {
        query = query.eq('requester_id', userId);
      } else if (isRequester == false) {
        query = query.eq('addressee_id', userId);
      } else {
        query = query.or('requester_id.eq.$userId,addressee_id.eq.$userId');
      }

      // Filter by status if provided
      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map((json) => FriendshipModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Failed to get friendships: $e');
    }
  }

  /// Subscribe to friendships changes
  Stream<void> subscribeFriendships(String userId) {
    final controller = StreamController<void>();

    final channel = _supabaseClient.channel('friendships:user_$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) {
            // Simply notify that something changed.
            // Better to reload than to try and sync partial data without profiles.
            controller.add(null);
          },
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }
}

/// Provider for FriendsRemoteDataSource
final friendsRemoteDataSourceProvider = Provider<FriendsRemoteDataSource>((
  ref,
) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return FriendsRemoteDataSource(supabaseClient);
});
