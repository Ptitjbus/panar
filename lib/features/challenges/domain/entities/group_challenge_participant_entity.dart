import '../../../profile/domain/entities/profile_entity.dart';

enum ParticipantStatus {
  invited,
  accepted,
  rejected;

  static ParticipantStatus fromString(String s) {
    switch (s) {
      case 'accepted': return ParticipantStatus.accepted;
      case 'rejected': return ParticipantStatus.rejected;
      default:         return ParticipantStatus.invited;
    }
  }

  String toJson() => name;
}

class GroupChallengeParticipantEntity {
  final String id;
  final String challengeId;
  final String userId;
  final ParticipantStatus status;
  final double totalDistanceMeters;
  final DateTime? joinedAt;
  final ProfileEntity? profile;

  const GroupChallengeParticipantEntity({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.totalDistanceMeters,
    this.joinedAt,
    this.profile,
  });

  String get formattedDistance {
    final km = totalDistanceMeters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }
}
