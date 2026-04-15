import '../../../profile/data/models/profile_model.dart';
import '../../domain/entities/group_challenge_participant_entity.dart';

class GroupChallengeParticipantModel extends GroupChallengeParticipantEntity {
  const GroupChallengeParticipantModel({
    required super.id,
    required super.challengeId,
    required super.userId,
    required super.status,
    required super.totalDistanceMeters,
    super.joinedAt,
    super.profile,
  });

  factory GroupChallengeParticipantModel.fromJson(Map<String, dynamic> json) {
    return GroupChallengeParticipantModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      userId: json['user_id'] as String,
      status: ParticipantStatus.fromString(json['status'] as String),
      totalDistanceMeters: (json['total_distance_meters'] as num).toDouble(),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      profile: json['profile'] != null
          ? ProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
              .toEntity()
          : null,
    );
  }

  GroupChallengeParticipantEntity toEntity() => GroupChallengeParticipantEntity(
        id: id,
        challengeId: challengeId,
        userId: userId,
        status: status,
        totalDistanceMeters: totalDistanceMeters,
        joinedAt: joinedAt,
        profile: profile,
      );
}
