enum InteractionType {
  encouragement,
  emoji,
  directMessage,
  voiceMessage,
  soundboard;

  static InteractionType fromString(String value) {
    switch (value) {
      case 'encouragement':
        return InteractionType.encouragement;
      case 'emoji':
        return InteractionType.emoji;
      case 'direct_message':
        return InteractionType.directMessage;
      case 'voice_message':
        return InteractionType.voiceMessage;
      case 'soundboard':
        return InteractionType.soundboard;
      default:
        return InteractionType.encouragement;
    }
  }

  String toJson() {
    switch (this) {
      case InteractionType.encouragement:
        return 'encouragement';
      case InteractionType.emoji:
        return 'emoji';
      case InteractionType.directMessage:
        return 'direct_message';
      case InteractionType.voiceMessage:
        return 'voice_message';
      case InteractionType.soundboard:
        return 'soundboard';
    }
  }
}

class RunInteractionEntity {
  final String id;
  final String sessionId;
  final String senderId;
  final String runnerId;
  final InteractionType type;
  final String? content;
  final String? audioUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  // Optional: display name of sender (populated from join)
  final String? senderName;
  final String? senderAvatarUrl;

  const RunInteractionEntity({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.runnerId,
    required this.type,
    this.content,
    this.audioUrl,
    this.readAt,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  bool get hasAudio =>
      type == InteractionType.voiceMessage ||
      type == InteractionType.soundboard;

  bool get isRead => readAt != null;
}
