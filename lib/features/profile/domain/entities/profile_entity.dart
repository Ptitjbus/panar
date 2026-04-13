/// Profile entity representing user profile data
class ProfileEntity {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.hasCompletedOnboarding,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProfileEntity &&
        other.id == id &&
        other.username == username &&
        other.fullName == fullName &&
        other.avatarUrl == avatarUrl &&
        other.hasCompletedOnboarding == hasCompletedOnboarding;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        fullName.hashCode ^
        avatarUrl.hashCode ^
        hasCompletedOnboarding.hashCode;
  }

  @override
  String toString() {
    return 'ProfileEntity(id: $id, username: $username, fullName: $fullName)';
  }
}
