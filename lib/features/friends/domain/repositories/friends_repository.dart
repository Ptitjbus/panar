import '../../../profile/domain/entities/profile_entity.dart';
import '../entities/friendship_entity.dart';

/// Abstract repository for friends-related operations
abstract class FriendsRepository {
  /// Search users by username
  Future<List<ProfileEntity>> searchUsers(String username);

  /// Send a friend request to another user
  Future<void> sendFriendRequest(String addresseeId);

  /// Accept a friend request
  Future<void> acceptFriendRequest(String friendshipId);

  /// Reject a friend request
  Future<void> rejectFriendRequest(String friendshipId);

  /// Remove a friend
  Future<void> removeFriend(String friendshipId);

  /// Get list of accepted friends
  Future<List<FriendshipEntity>> getMyFriends();

  /// Get list of received friend requests (pending, where current user is addressee)
  Future<List<FriendshipEntity>> getReceivedRequests();

  /// Get list of sent friend requests (pending, where current user is requester)
  Future<List<FriendshipEntity>> getSentRequests();

  /// Watch friendships for real-time updates (notifies to reload)
  Stream<void> watchFriendships();
}
