import '../../domain/entities/profile_entity.dart';

/// Profile model that extends ProfileEntity and handles data serialization
class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
    required super.hasCompletedOnboarding,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Creates a ProfileModel from JSON
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts ProfileModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'has_completed_onboarding': hasCompletedOnboarding,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts ProfileModel to ProfileEntity
  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      hasCompletedOnboarding: hasCompletedOnboarding,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
