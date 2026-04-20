import '../../domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
    super.avatarColor,
    super.onboardingActivityIndex,
    super.onboardingTimeIndex,
    super.onboardingUsernameDone,
    super.onboardingLocationPermissionGranted,
    super.onboardingNotificationsPermissionGranted,
    super.onboardingAvatarDone,
    required super.hasCompletedOnboarding,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarColor: json['avatar_color'] as String?,
      onboardingActivityIndex: json['onboarding_activity_index'] as int?,
      onboardingTimeIndex: json['onboarding_time_index'] as int?,
      onboardingUsernameDone:
          json['onboarding_username_done'] as bool? ?? false,
      onboardingLocationPermissionGranted:
          json['onboarding_location_permission_granted'] as bool?,
      onboardingNotificationsPermissionGranted:
          json['onboarding_notifications_permission_granted'] as bool?,
      onboardingAvatarDone: json['onboarding_avatar_done'] as bool? ?? false,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'avatar_color': avatarColor,
      'onboarding_activity_index': onboardingActivityIndex,
      'onboarding_time_index': onboardingTimeIndex,
      'onboarding_username_done': onboardingUsernameDone,
      'onboarding_location_permission_granted':
          onboardingLocationPermissionGranted,
      'onboarding_notifications_permission_granted':
          onboardingNotificationsPermissionGranted,
      'onboarding_avatar_done': onboardingAvatarDone,
      'has_completed_onboarding': hasCompletedOnboarding,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      avatarColor: avatarColor,
      onboardingActivityIndex: onboardingActivityIndex,
      onboardingTimeIndex: onboardingTimeIndex,
      onboardingUsernameDone: onboardingUsernameDone,
      onboardingLocationPermissionGranted: onboardingLocationPermissionGranted,
      onboardingNotificationsPermissionGranted:
          onboardingNotificationsPermissionGranted,
      onboardingAvatarDone: onboardingAvatarDone,
      hasCompletedOnboarding: hasCompletedOnboarding,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
