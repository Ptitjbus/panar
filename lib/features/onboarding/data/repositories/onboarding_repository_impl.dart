import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

/// Implementation of OnboardingRepository using OnboardingLocalDataSource
class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource _onboardingLocalDataSource;

  OnboardingRepositoryImpl(this._onboardingLocalDataSource);

  @override
  Future<bool> hasCompletedOnboarding() async {
    return await _onboardingLocalDataSource.hasCompletedOnboarding();
  }

  @override
  Future<void> markOnboardingComplete() async {
    await _onboardingLocalDataSource.markOnboardingComplete();
  }
}

/// Provider for OnboardingRepository
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final onboardingLocalDataSource = ref.watch(
    onboardingLocalDataSourceProvider,
  );
  return OnboardingRepositoryImpl(onboardingLocalDataSource);
});
