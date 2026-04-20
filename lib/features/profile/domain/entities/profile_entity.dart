/// Profile entity representing user profile data
class ProfileEntity {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? avatarColor;
  final int? onboardingActivityIndex;
  final int? onboardingTimeIndex;
  final bool onboardingUsernameDone;
  final bool? onboardingLocationPermissionGranted;
  final bool? onboardingNotificationsPermissionGranted;
  final bool onboardingAvatarDone;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.avatarColor,
    this.onboardingActivityIndex,
    this.onboardingTimeIndex,
    this.onboardingUsernameDone = false,
    this.onboardingLocationPermissionGranted,
    this.onboardingNotificationsPermissionGranted,
    this.onboardingAvatarDone = false,
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
        other.avatarColor == avatarColor &&
        other.onboardingActivityIndex == onboardingActivityIndex &&
        other.onboardingTimeIndex == onboardingTimeIndex &&
        other.onboardingUsernameDone == onboardingUsernameDone &&
        other.onboardingLocationPermissionGranted ==
            onboardingLocationPermissionGranted &&
        other.onboardingNotificationsPermissionGranted ==
            onboardingNotificationsPermissionGranted &&
        other.onboardingAvatarDone == onboardingAvatarDone &&
        other.hasCompletedOnboarding == hasCompletedOnboarding;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        fullName.hashCode ^
        avatarUrl.hashCode ^
        avatarColor.hashCode ^
        onboardingActivityIndex.hashCode ^
        onboardingTimeIndex.hashCode ^
        onboardingUsernameDone.hashCode ^
        onboardingLocationPermissionGranted.hashCode ^
        onboardingNotificationsPermissionGranted.hashCode ^
        onboardingAvatarDone.hashCode ^
        hasCompletedOnboarding.hashCode;
  }

  @override
  String toString() {
    return 'ProfileEntity(id: $id, username: $username, fullName: $fullName)';
  }
}
