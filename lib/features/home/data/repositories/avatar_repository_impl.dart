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
  Future<List<AvatarEntity>> getAvatars(List<String> userIds) async {
    try {
      final avatarModels = await _remoteDataSource.getAvatars(userIds);
      return avatarModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      return [];
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

  @override
  Future<AvatarEntity> updateAvatar({
    required String userId,
    String? displayName,
    String? colorHex,
  }) async {
    final avatarModel = await _remoteDataSource.updateAvatar(
      userId: userId,
      displayName: displayName,
      colorHex: colorHex,
    );
    return avatarModel.toEntity();
  }
}

/// Provider for AvatarRepository
final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  final remoteDataSource = ref.watch(avatarRemoteDataSourceProvider);
  return AvatarRepositoryImpl(remoteDataSource);
});
