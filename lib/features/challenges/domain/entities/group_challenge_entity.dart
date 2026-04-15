import 'group_challenge_participant_entity.dart';

enum GroupChallengeStatus {
  pending,
  active,
  completed;

  static GroupChallengeStatus fromString(String s) {
    switch (s) {
      case 'active':    return GroupChallengeStatus.active;
      case 'completed': return GroupChallengeStatus.completed;
      default:          return GroupChallengeStatus.pending;
    }
  }

  String toJson() => name;
}

class GroupChallengeEntity {
  final String id;
  final String creatorId;
  final String title;
  final int durationDays;
  final GroupChallengeStatus status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final List<GroupChallengeParticipantEntity> participants;
  final double? targetDistanceMeters;
  final String? description;

  const GroupChallengeEntity({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.durationDays,
    required this.status,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    this.participants = const [],
    this.targetDistanceMeters,
    this.description,
  });

  bool get isPending   => status == GroupChallengeStatus.pending;
  bool get isActive    => status == GroupChallengeStatus.active;
  bool get isCompleted => status == GroupChallengeStatus.completed;

  List<GroupChallengeParticipantEntity> get sortedLeaderboard {
    final accepted = participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList()
      ..sort((a, b) => b.totalDistanceMeters.compareTo(a.totalDistanceMeters));
    return accepted;
  }

  int get daysRemaining {
    if (endsAt == null) return durationDays;
    final diff = endsAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get canForceStart {
    final accepted = participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .length;
    return accepted >= 1 &&
        participants.any((p) => p.status == ParticipantStatus.rejected);
  }
}
