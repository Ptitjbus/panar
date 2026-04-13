import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/entities/onboarding_item.dart';

/// Provider for onboarding items
final onboardingItemsProvider = Provider<List<OnboardingItem>>((ref) {
  return AppConstants.onboardingContent.map((item) {
    return OnboardingItem(
      title: item['title']!,
      description: item['description']!,
      imagePath: item['imagePath'],
    );
  }).toList();
});

/// Provider to check if onboarding is completed
final hasCompletedOnboardingProvider = FutureProvider<bool>((ref) async {
  final onboardingRepository = ref.watch(onboardingRepositoryProvider);
  return await onboardingRepository.hasCompletedOnboarding();
});

/// State notifier for onboarding actions
class OnboardingNotifier extends StateNotifier<bool> {
  final Ref ref;

  OnboardingNotifier(this.ref) : super(false);

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final onboardingRepository = ref.read(onboardingRepositoryProvider);
    await onboardingRepository.markOnboardingComplete();
    state = true;

    // Invalidate the provider to refetch the status
    ref.invalidate(hasCompletedOnboardingProvider);
  }
}

/// Provider for onboarding actions
final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
      return OnboardingNotifier(ref);
    });
