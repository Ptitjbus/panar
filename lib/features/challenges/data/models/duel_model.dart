import '../../../profile/data/models/profile_model.dart';
import '../../domain/entities/duel_entity.dart';

class DuelModel extends DuelEntity {
  const DuelModel({
    required super.id,
    required super.challengerId,
    required super.challengedId,
    required super.status,
    required super.timing,
    super.deadlineHours,
    super.challengerActivityId,
    super.challengedActivityId,
    super.winnerId,
    required super.createdAt,
    required super.updatedAt,
    super.challengerProfile,
    super.challengedProfile,
    super.targetDistanceMeters,
    super.description,
  });

  factory DuelModel.fromJson(Map<String, dynamic> json) {
    return DuelModel(
      id: json['id'] as String,
      challengerId: json['challenger_id'] as String,
      challengedId: json['challenged_id'] as String,
      status: DuelStatus.fromString(json['status'] as String),
      timing: DuelTiming.fromString(json['timing'] as String),
      deadlineHours: json['deadline_hours'] as int?,
      challengerActivityId: json['challenger_activity_id'] as String?,
      challengedActivityId: json['challenged_activity_id'] as String?,
      winnerId: json['winner_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      challengerProfile: json['challenger'] != null
          ? ProfileModel.fromJson(json['challenger'] as Map<String, dynamic>).toEntity()
          : null,
      challengedProfile: json['challenged'] != null
          ? ProfileModel.fromJson(json['challenged'] as Map<String, dynamic>).toEntity()
          : null,
      targetDistanceMeters: (json['target_distance_meters'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenger_id': challengerId,
    'challenged_id': challengedId,
    'status': status.toJson(),
    'timing': timing.toJson(),
    if (deadlineHours != null) 'deadline_hours': deadlineHours,
    if (challengerActivityId != null) 'challenger_activity_id': challengerActivityId,
    if (challengedActivityId != null) 'challenged_activity_id': challengedActivityId,
    if (winnerId != null) 'winner_id': winnerId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (targetDistanceMeters != null) 'target_distance_meters': targetDistanceMeters,
    if (description != null) 'description': description,
  };

  DuelEntity toEntity() => DuelEntity(
    id: id,
    challengerId: challengerId,
    challengedId: challengedId,
    status: status,
    timing: timing,
    deadlineHours: deadlineHours,
    challengerActivityId: challengerActivityId,
    challengedActivityId: challengedActivityId,
    winnerId: winnerId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    challengerProfile: challengerProfile,
    challengedProfile: challengedProfile,
    targetDistanceMeters: targetDistanceMeters,
    description: description,
  );
}
