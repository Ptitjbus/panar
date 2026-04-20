import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';

/// Prevents the router from redirecting back to /username-setup while the
/// wizard is still in progress or immediately after completion.
/// Set to true at the start of _finish() before any async operations.
final wizardCompleteProvider = StateProvider<bool>((ref) => false);

final userProfileProvider = FutureProvider<ProfileEntity?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;

  try {
    final profileRepository = ref.watch(profileRepositoryProvider);
    return await profileRepository.getProfile(user.id);
  } catch (e) {
    return null;
  }
});

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

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref ref;

  ProfileNotifier(this.ref) : super(const ProfileState());

  Future<bool> updateUsername(String username) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw const AuthFailure('User not authenticated');

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateUsername(user.id, username);

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

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      return await profileRepository.checkUsernameAvailability(username);
    } catch (e) {
      return false;
    }
  }

  Future<void> markOnboardingComplete({String? avatarColor}) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.markOnboardingComplete(
        user.id,
        avatarColor: avatarColor,
      );
    } catch (e) {
      debugPrint('[ProfileNotifier] markOnboardingComplete error: $e');
    } finally {
      // Always invalidate so the router gets fresh data, regardless of success/failure.
      // The wizardCompleteProvider flag protects against the redirect loop.
      ref.invalidate(userProfileProvider);
    }
  }

  Future<void> updateOnboardingProgress({
    int? onboardingActivityIndex,
    int? onboardingTimeIndex,
    bool? onboardingUsernameDone,
    bool? onboardingLocationPermissionGranted,
    bool? onboardingNotificationsPermissionGranted,
    bool? onboardingAvatarDone,
    String? avatarColor,
    bool? hasCompletedOnboarding,
  }) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateOnboardingProgress(
        userId: user.id,
        onboardingActivityIndex: onboardingActivityIndex,
        onboardingTimeIndex: onboardingTimeIndex,
        onboardingUsernameDone: onboardingUsernameDone,
        onboardingLocationPermissionGranted:
            onboardingLocationPermissionGranted,
        onboardingNotificationsPermissionGranted:
            onboardingNotificationsPermissionGranted,
        onboardingAvatarDone: onboardingAvatarDone,
        avatarColor: avatarColor,
        hasCompletedOnboarding: hasCompletedOnboarding,
      );
    } catch (e) {
      debugPrint('[ProfileNotifier] updateOnboardingProgress error: $e');
    } finally {
      ref.invalidate(userProfileProvider);
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? avatarColor,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw const AuthFailure('User not authenticated');

      final profileRepository = ref.read(profileRepositoryProvider);
      await profileRepository.updateProfile(
        userId: user.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
        avatarColor: avatarColor,
      );

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

  void clearError() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
      return ProfileNotifier(ref);
    });
