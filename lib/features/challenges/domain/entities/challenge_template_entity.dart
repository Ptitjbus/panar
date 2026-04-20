class ChallengeTemplateEntity {
  final String id;
  final String title;
  final String? description;
  final String challengeType; // 'solo', 'group', 'monthly'
  final double targetDistanceMeters;
  final int durationDays;
  final String? difficulty;
  final String emoji;
  final int points;
  final DateTime createdAt;

  const ChallengeTemplateEntity({
    required this.id,
    required this.title,
    this.description,
    required this.challengeType,
    required this.targetDistanceMeters,
    required this.durationDays,
    this.difficulty,
    required this.emoji,
    required this.points,
    required this.createdAt,
  });

  bool get isSolo => challengeType == 'solo';
  bool get isGroup => challengeType == 'group';
  bool get isMonthly => challengeType == 'monthly';

  String get targetDistanceLabel {
    final km = targetDistanceMeters / 1000;
    return km == km.truncateToDouble() ? '${km.toInt()}km' : '${km}km';
  }
}
