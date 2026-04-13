import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';

/// Provider for user profile based on current user ID
final userProfileProvider = FutureProvider<ProfileEntity?>((ref) async {
  // Use watch(authStateProvider.future) to wait for the first data value
  // This will naturally suspend this provider while authState is loading
  final user = await ref.watch(authStateProvider.future);

  if (user == null) return null;

  try {
    final profileRepository = ref.watch(profileRepositoryProvider);
    return await profileRepository.getProfile(user.id);
  } catch (e) {
    // If getting profile fails (e.g. doesn't exist yet), return null
    return null;
  }
});

/// State class for profile actions
class ProfileState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Profile actions state notifier
class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref ref;

  ProfileNotifier(this.ref) : super(const ProfileState());

  /// Update username
  Future<bool> updateUsername(String username) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;

      if (user == null) {
        throw const AuthFailure('User not authenticated');
      }

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateUsername(user.id, username);

      // Invalidate the profile provider to refetch the updated profile
      ref.invalidate(userProfileProvider);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Username updated successfully!',
      );
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Check username availability
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      return await profileRepository.checkUsernameAvailability(username);
    } catch (e) {
      return false;
    }
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;

      if (user == null) return;

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.markOnboardingComplete(user.id);

      // Invalidate the profile provider to refetch the updated profile
      ref.invalidate(userProfileProvider);
    } catch (e) {
      // Silently fail
    }
  }

  /// Update profile
  Future<bool> updateProfile({String? fullName, String? avatarUrl}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final authState = ref.read(authStateProvider);
      final user = authState.value;

      if (user == null) {
        throw const AuthFailure('User not authenticated');
      }

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateProfile(
        userId: user.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

      // Invalidate the profile provider to refetch the updated profile
      ref.invalidate(userProfileProvider);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Profile updated successfully!',
      );
      return true;
    } on DatabaseFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}

/// Provider for profile actions
final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
      return ProfileNotifier(ref);
    });
