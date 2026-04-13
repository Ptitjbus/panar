/// Abstract repository for onboarding operations
abstract class OnboardingRepository {
  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding();

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete();
}
