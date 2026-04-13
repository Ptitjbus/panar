/// User entity representing authenticated user data
class UserEntity {
  final String id;
  final String email;
  final DateTime createdAt;
  final Map<String, dynamic>? userMetadata;

  const UserEntity({
    required this.id,
    required this.email,
    required this.createdAt,
    this.userMetadata,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserEntity &&
        other.id == id &&
        other.email == email &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^ email.hashCode ^ createdAt.hashCode;
  }

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, createdAt: $createdAt)';
  }
}
