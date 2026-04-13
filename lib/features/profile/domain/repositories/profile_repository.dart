import '../entities/profile_entity.dart';

/// Abstract repository for profile operations
abstract class ProfileRepository {
  /// Get user profile by ID
  Future<ProfileEntity> getProfile(String userId);

  /// Update username
  Future<void> updateUsername(String userId, String username);

  /// Check if username is available
  Future<bool> checkUsernameAvailability(String username);

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete(String userId);

  /// Update profile
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  });
}
