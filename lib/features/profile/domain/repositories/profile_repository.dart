import '../entities/profile_entity.dart';

/// Abstract repository for profile operations
abstract class ProfileRepository {
  Future<ProfileEntity> getProfile(String userId);
  Future<void> updateUsername(String userId, String username);
  Future<bool> checkUsernameAvailability(String username, {String? excludeUserId});
  Future<void> markOnboardingComplete(String userId, {String? avatarColor});
  Future<void> updateOnboardingProgress({
    required String userId,
    int? onboardingActivityIndex,
    int? onboardingTimeIndex,
    bool? onboardingUsernameDone,
    bool? onboardingLocationPermissionGranted,
    bool? onboardingNotificationsPermissionGranted,
    bool? onboardingAvatarDone,
    String? avatarColor,
    bool? hasCompletedOnboarding,
  });
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
    String? avatarColor,
  });
}
