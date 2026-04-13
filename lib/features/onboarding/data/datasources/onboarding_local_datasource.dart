import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/shared_preferences_provider.dart';

/// Local data source for onboarding using SharedPreferences
class OnboardingLocalDataSource {
  final SharedPreferences _sharedPreferences;

  OnboardingLocalDataSource(this._sharedPreferences);

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    return _sharedPreferences.getBool(AppConstants.hasCompletedOnboardingKey) ??
        false;
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete() async {
    await _sharedPreferences.setBool(
      AppConstants.hasCompletedOnboardingKey,
      true,
    );
  }
}

/// Provider for OnboardingLocalDataSource
final onboardingLocalDataSourceProvider = Provider<OnboardingLocalDataSource>((
  ref,
) {
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  return OnboardingLocalDataSource(sharedPreferences);
});
