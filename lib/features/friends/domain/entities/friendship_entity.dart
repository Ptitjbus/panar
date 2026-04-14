import '../../../profile/domain/entities/profile_entity.dart';

/// Friendship status enum
enum FriendshipStatus {
  pending,
  accepted,
  rejected;

  /// Convert string to enum
  static FriendshipStatus fromString(String status) {
    try {
      switch (status.toLowerCase()) {
        case 'pending':
          return FriendshipStatus.pending;
        case 'accepted':
          return FriendshipStatus.accepted;
        case 'rejected':
          return FriendshipStatus.rejected;
        default:
          return FriendshipStatus.pending;
      }
    } catch (e) {
      return FriendshipStatus.pending;
    }
  }

  /// Convert enum to string
  String toJson() => name;
}

/// Friendship entity representing a friendship relationship
class FriendshipEntity {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional profile info (used to avoid N+1 queries)
  final ProfileEntity? requesterProfile;
  final ProfileEntity? addresseeProfile;

  const FriendshipEntity({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.requesterProfile,
    this.addresseeProfile,
  });

  /// Get the other user ID in this friendship
  String getOtherUserId(String currentUserId) {
    return currentUserId == requesterId ? addresseeId : requesterId;
  }

  /// Get the other user profile if available
  ProfileEntity? getOtherUserProfile(String currentUserId) {
    return currentUserId == requesterId ? addresseeProfile : requesterProfile;
  }

  /// Check if friendship is pending
  bool isPending() => status == FriendshipStatus.pending;

  /// Check if friendship is accepted
  bool isAccepted() => status == FriendshipStatus.accepted;

  /// Check if friendship is rejected
  bool isRejected() => status == FriendshipStatus.rejected;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FriendshipEntity &&
        other.id == id &&
        other.requesterId == requesterId &&
        other.addresseeId == addresseeId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        requesterId.hashCode ^
        addresseeId.hashCode ^
        status.hashCode;
  }

  @override
  String toString() {
    return 'FriendshipEntity(id: $id, requesterId: $requesterId, addresseeId: $addresseeId, status: $status)';
  }
}
