import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

/// Implementation of ProfileRepository using ProfileRemoteDataSource
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
  Future<void> markOnboardingComplete(String userId) async {
    await _profileRemoteDataSource.markOnboardingComplete(userId);
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    await _profileRemoteDataSource.updateProfile(
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
  }
}

/// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final profileRemoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(profileRemoteDataSource);
});
