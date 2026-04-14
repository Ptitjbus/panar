import '../entities/avatar_entity.dart';

abstract class AvatarRepository {
  Future<AvatarEntity?> getAvatar(String userId);
  Future<AvatarEntity> createAvatar(String userId, String? displayName);
}
