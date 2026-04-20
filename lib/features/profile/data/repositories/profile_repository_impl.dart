import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _profileRemoteDataSource;

  ProfileRepositoryImpl(this._profileRemoteDataSource);

  @override
  Future<ProfileEntity> getProfile(String userId) async {
    final profileModel = await _profileRemoteDataSource.getProfile(userId);
    return profileModel.toEntity();
  }

  @override
  Future<void> updateUsername(String userId, String username) async {
    await _profileRemoteDataSource.updateUsername(userId, username);
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    return await _profileRemoteDataSource.checkUsernameAvailability(username);
  }

  @override
  Future<void> markOnboardingComplete(
    String userId, {
    String? avatarColor,
  }) async {
    await _profileRemoteDataSource.markOnboardingComplete(
      userId,
      avatarColor: avatarColor,
    );
  }

  @override
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
  }) async {
    await _profileRemoteDataSource.updateOnboardingProgress(
      userId: userId,
      onboardingActivityIndex: onboardingActivityIndex,
      onboardingTimeIndex: onboardingTimeIndex,
      onboardingUsernameDone: onboardingUsernameDone,
      onboardingLocationPermissionGranted: onboardingLocationPermissionGranted,
      onboardingNotificationsPermissionGranted:
          onboardingNotificationsPermissionGranted,
      onboardingAvatarDone: onboardingAvatarDone,
      avatarColor: avatarColor,
      hasCompletedOnboarding: hasCompletedOnboarding,
    );
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
    String? avatarColor,
  }) async {
    await _profileRemoteDataSource.updateProfile(
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      avatarColor: avatarColor,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final profileRemoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(profileRemoteDataSource);
});
