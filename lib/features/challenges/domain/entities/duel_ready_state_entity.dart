// lib/features/challenges/domain/entities/duel_ready_state_entity.dart
class DuelReadyStateEntity {
  final String id;
  final String duelId;
  final String userId;
  final DateTime? readyAt;

  const DuelReadyStateEntity({
    required this.id,
    required this.duelId,
    required this.userId,
    this.readyAt,
  });

  bool get isReady => readyAt != null;

  factory DuelReadyStateEntity.fromJson(Map<String, dynamic> json) {
    final rawReadyAt = json['ready_at'];
    return DuelReadyStateEntity(
      id: json['id'] as String,
      duelId: json['duel_id'] as String,
      userId: json['user_id'] as String,
      readyAt: rawReadyAt == null
          ? null
          : rawReadyAt is DateTime
              ? rawReadyAt
              : DateTime.parse(rawReadyAt.toString()),
    );
  }
}
