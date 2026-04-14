import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../domain/entities/friendship_entity.dart';
import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_remote_datasource.dart';

/// Implementation of FriendsRepository using FriendsRemoteDataSource
class FriendsRepositoryImpl implements FriendsRepository {
  final FriendsRemoteDataSource _friendsRemoteDataSource;
  final String _currentUserId;

  FriendsRepositoryImpl(this._friendsRemoteDataSource, this._currentUserId);

  @override
  Future<List<ProfileEntity>> searchUsers(String username) async {
    final profileModels = await _friendsRemoteDataSource.searchUsersByUsername(
      username,
    );
    return profileModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> sendFriendRequest(String addresseeId) async {
    await _friendsRemoteDataSource.sendFriendRequest(
      requesterId: _currentUserId,
      addresseeId: addresseeId,
    );
  }

  @override
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _friendsRemoteDataSource.acceptFriendRequest(friendshipId);
  }

  @override
  Future<void> rejectFriendRequest(String friendshipId) async {
    await _friendsRemoteDataSource.rejectFriendRequest(friendshipId);
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    await _friendsRemoteDataSource.removeFriend(friendshipId);
  }

  @override
  Future<List<FriendshipEntity>> getMyFriends() async {
    final friendshipModels = await _friendsRemoteDataSource.getFriendships(
      userId: _currentUserId,
      status: 'accepted',
      isRequester:
          true, // Only fetch where current user is requester to avoid duplicates
    );
    return friendshipModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<FriendshipEntity>> getReceivedRequests() async {
    final friendshipModels = await _friendsRemoteDataSource.getFriendships(
      userId: _currentUserId,
      status: 'pending',
      isRequester: false, // Current user is addressee
    );
    return friendshipModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<FriendshipEntity>> getSentRequests() async {
    final friendshipModels = await _friendsRemoteDataSource.getFriendships(
      userId: _currentUserId,
      status: 'pending',
      isRequester: true, // Current user is requester
    );
    return friendshipModels.map((model) => model.toEntity()).toList();
  }

  @override
  Stream<void> watchFriendships() {
    return _friendsRemoteDataSource.subscribeFriendships(_currentUserId);
  }
}

/// Provider for FriendsRepository
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final friendsRemoteDataSource = ref.watch(friendsRemoteDataSourceProvider);
  final authState = ref.watch(authStateProvider);
  final currentUserId = authState.value?.id ?? '';

  return FriendsRepositoryImpl(friendsRemoteDataSource, currentUserId);
});
