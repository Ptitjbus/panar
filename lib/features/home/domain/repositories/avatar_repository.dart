import '../entities/avatar_entity.dart';

abstract class AvatarRepository {
  Future<AvatarEntity?> getAvatar(String userId);
  Future<List<AvatarEntity>> getAvatars(List<String> userIds);
  Future<AvatarEntity> createAvatar(String userId, String? displayName);
  Future<AvatarEntity> updateAvatar({
    required String userId,
    String? displayName,
    String? colorHex,
  });
}
