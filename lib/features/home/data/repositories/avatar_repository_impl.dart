import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/avatar_entity.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../datasources/avatar_remote_datasource.dart';

/// Implementation of AvatarRepository
class AvatarRepositoryImpl implements AvatarRepository {
  final AvatarRemoteDataSource _remoteDataSource;

  AvatarRepositoryImpl(this._remoteDataSource);

  @override
  Future<AvatarEntity?> getAvatar(String userId) async {
    try {
      final avatarModel = await _remoteDataSource.getAvatar(userId);
      return avatarModel.toEntity();
    } catch (e) {
      // Return null if avatar doesn't exist or on error
      return null;
    }
  }

  @override
  Future<AvatarEntity> createAvatar(String userId, String? displayName) async {
    final avatarModel = await _remoteDataSource.createAvatar(
      userId,
      displayName,
    );
    return avatarModel.toEntity();
  }
}

/// Provider for AvatarRepository
final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  final remoteDataSource = ref.watch(avatarRemoteDataSourceProvider);
  return AvatarRepositoryImpl(remoteDataSource);
});
