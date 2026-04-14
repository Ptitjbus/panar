import '../../domain/entities/run_interaction_entity.dart';

class RunInteractionModel extends RunInteractionEntity {
  const RunInteractionModel({
    required super.id,
    required super.sessionId,
    required super.senderId,
    required super.runnerId,
    required super.type,
    super.content,
    super.audioUrl,
    super.readAt,
    required super.createdAt,
    super.senderName,
    super.senderAvatarUrl,
  });

  factory RunInteractionModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RunInteractionModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      senderId: json['sender_id'] as String,
      runnerId: json['runner_id'] as String,
      type: InteractionType.fromString(json['type'] as String),
      content: json['content'] as String?,
      audioUrl: json['audio_url'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: profile?['display_name'] as String? ??
          profile?['username'] as String?,
      senderAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'session_id': sessionId,
      'sender_id': senderId,
      'runner_id': runnerId,
      'type': type.toJson(),
      'content': content,
      'audio_url': audioUrl,
    };
  }
}
