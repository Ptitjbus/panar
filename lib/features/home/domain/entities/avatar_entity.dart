class AvatarEntity {
  final String id;
  final String userId;
  final String? displayName;
  final String colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AvatarEntity({
    required this.id,
    required this.userId,
    this.displayName,
    required this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AvatarEntity &&
        other.id == id &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.colorHex == colorHex &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        displayName.hashCode ^
        colorHex.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
