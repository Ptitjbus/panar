import '../../domain/entities/challenge_template_entity.dart';

class ChallengeTemplateModel extends ChallengeTemplateEntity {
  const ChallengeTemplateModel({
    required super.id,
    required super.title,
    super.description,
    required super.challengeType,
    required super.targetDistanceMeters,
    required super.durationDays,
    super.difficulty,
    required super.emoji,
    required super.points,
    required super.createdAt,
  });

  factory ChallengeTemplateModel.fromJson(Map<String, dynamic> json) {
    return ChallengeTemplateModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      challengeType: json['challenge_type'] as String,
      targetDistanceMeters: (json['target_distance_meters'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
      difficulty: json['difficulty'] as String?,
      emoji: json['emoji'] as String? ?? '🏃',
      points: json['points'] as int? ?? 200,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ChallengeTemplateEntity toEntity() => ChallengeTemplateEntity(
    id: id,
    title: title,
    description: description,
    challengeType: challengeType,
    targetDistanceMeters: targetDistanceMeters,
    durationDays: durationDays,
    difficulty: difficulty,
    emoji: emoji,
    points: points,
    createdAt: createdAt,
  );
}
