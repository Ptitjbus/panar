import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/repositories/avatar_repository_impl.dart';
import '../../domain/entities/avatar_entity.dart';

/// Provider for user avatar based on current user ID
/// Automatically creates an avatar if the user doesn't have one
final userAvatarProvider = FutureProvider<AvatarEntity?>((ref) async {
  // Use watch(authStateProvider.future) to wait for the first data value
  // This will naturally suspend this provider while authState is loading
  final user = await ref.watch(authStateProvider.future);

  if (user == null) return null;

  final avatarRepository = ref.watch(avatarRepositoryProvider);

  // Try to get existing avatar
  final existingAvatar = await avatarRepository.getAvatar(user.id);

  if (existingAvatar != null) {
    return existingAvatar;
  }

  // Avatar doesn't exist, create one
  try {
    // Get user profile to use username as display name
    final profile = await ref.read(userProfileProvider.future);
    final displayName = profile?.username;

    // Create new avatar
    final newAvatar = await avatarRepository.createAvatar(user.id, displayName);
    return newAvatar;
  } catch (e) {
    // If creation fails, return null
    return null;
  }
});
