import '../../../profile/domain/entities/profile_entity.dart';

enum DuelStatus {
  pending,
  accepted,
  rejected,
  active,
  completed,
  cancelled;

  static DuelStatus fromString(String s) {
    switch (s) {
      case 'accepted':  return DuelStatus.accepted;
      case 'rejected':  return DuelStatus.rejected;
      case 'active':    return DuelStatus.active;
      case 'completed': return DuelStatus.completed;
      case 'cancelled': return DuelStatus.cancelled;
      default:          return DuelStatus.pending;
    }
  }

  String toJson() => name;
}

enum DuelTiming {
  live,
  async;

  static DuelTiming fromString(String s) =>
      s == 'async' ? DuelTiming.async : DuelTiming.live;

  String toJson() => name;
}

class DuelEntity {
  final String id;
  final String challengerId;
  final String? challengedId;
  final DuelStatus status;
  final DuelTiming timing;
  final int? deadlineHours;
  final String? challengerActivityId;
  final String? challengedActivityId;
  final String? winnerId;
  final String? cancelledById;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProfileEntity? challengerProfile;
  final ProfileEntity? challengedProfile;
  final double? targetDistanceMeters;
  final String? description;

  bool get isSolo => challengedId == null;

  const DuelEntity({
    required this.id,
    required this.challengerId,
    this.challengedId,
    required this.status,
    required this.timing,
    this.deadlineHours,
    this.challengerActivityId,
    this.challengedActivityId,
    this.winnerId,
    this.cancelledById,
    required this.createdAt,
    required this.updatedAt,
    this.challengerProfile,
    this.challengedProfile,
    this.targetDistanceMeters,
    this.description,
  });

  bool get isPending   => status == DuelStatus.pending;
  bool get isActive    => status == DuelStatus.active;
  bool get isCompleted => status == DuelStatus.completed;
  bool get isCancelled => status == DuelStatus.cancelled;

  ProfileEntity? getOtherProfile(String currentUserId) =>
      currentUserId == challengerId ? challengedProfile : challengerProfile;

  String? getOtherUserId(String currentUserId) =>
      currentUserId == challengerId ? challengedId : challengerId;
}
