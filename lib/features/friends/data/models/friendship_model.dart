import '../../../profile/data/models/profile_model.dart';
import '../../domain/entities/friendship_entity.dart';

/// Friendship model that extends FriendshipEntity and handles data serialization
class FriendshipModel extends FriendshipEntity {
  const FriendshipModel({
    required super.id,
    required super.requesterId,
    required super.addresseeId,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.requesterProfile,
    super.addresseeProfile,
  });

  /// Creates a FriendshipModel from JSON
  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: FriendshipStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      requesterProfile: json['requester'] != null
          ? ProfileModel.fromJson(
              json['requester'] as Map<String, dynamic>,
            ).toEntity()
          : null,
      addresseeProfile: json['addressee'] != null
          ? ProfileModel.fromJson(
              json['addressee'] as Map<String, dynamic>,
            ).toEntity()
          : null,
    );
  }

  /// Converts FriendshipModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts FriendshipModel to FriendshipEntity
  FriendshipEntity toEntity() {
    return FriendshipEntity(
      id: id,
      requesterId: requesterId,
      addresseeId: addresseeId,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      requesterProfile: requesterProfile,
      addresseeProfile: addresseeProfile,
    );
  }
}
