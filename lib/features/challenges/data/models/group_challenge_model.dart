import '../../domain/entities/group_challenge_entity.dart';
import 'group_challenge_participant_model.dart';

class GroupChallengeModel extends GroupChallengeEntity {
  const GroupChallengeModel({
    required super.id,
    required super.creatorId,
    required super.title,
    required super.durationDays,
    required super.status,
    super.startsAt,
    super.endsAt,
    required super.createdAt,
    super.participants,
    super.targetDistanceMeters,
    super.description,
  });

  factory GroupChallengeModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List? ?? [];
    return GroupChallengeModel(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      durationDays: json['duration_days'] as int,
      status: GroupChallengeStatus.fromString(json['status'] as String),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: rawParticipants
          .map((p) =>
              GroupChallengeParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      targetDistanceMeters: (json['target_distance_meters'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  GroupChallengeEntity toEntity() => GroupChallengeEntity(
        id: id,
        creatorId: creatorId,
        title: title,
        durationDays: durationDays,
        status: status,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: createdAt,
        participants: participants,
        targetDistanceMeters: targetDistanceMeters,
        description: description,
      );
}
