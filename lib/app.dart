import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/route_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/presentation/pages/username_setup_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'shared/providers/shared_preferences_provider.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(userProfileProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      // Get onboarding status from SharedPreferences (synchronous)
      final hasSeenOnboarding =
          prefs.getBool(AppConstants.hasCompletedOnboardingKey) ?? false;

      // Get auth state
      final user = authState.value;
      final isLoggedIn = user != null;

      // Get profile to check username
      String? username;
      bool isProfileLoading = profileAsync.isLoading;

      profileAsync.whenData((profile) {
        username = profile?.username;
      });

      final location = state.matchedLocation;

      // First time users → onboarding
      if (!hasSeenOnboarding && location != Routes.onboarding) {
        return Routes.onboarding;
      }

      // Not logged in → login (except for onboarding and signup)
      if (!isLoggedIn &&
          location != Routes.login &&
          location != Routes.signup &&
          location != Routes.onboarding) {
        return Routes.login;
      }

      // If logged in, wait for profile to load before deciding on username setup
      if (isLoggedIn && isProfileLoading) {
        return null; // Stay where we are until we know if we need setup
      }

      // Logged in but no username (or temporary username) → username setup
      final needsUsernameSetup =
          username == null || (username?.startsWith('user_') ?? false);
      if (isLoggedIn && needsUsernameSetup && location != Routes.usernameSetup) {
        return Routes.usernameSetup;
      }

      // Logged in with username → prevent access to auth pages
      final hasValidUsername =
          username != null && !(username?.startsWith('user_') ?? true);
      if (isLoggedIn && hasValidUsername) {
        if (location == Routes.login ||
            location == Routes.signup ||
            location == Routes.onboarding ||
            location == Routes.usernameSetup) {
          return Routes.home;
        }
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: Routes.usernameSetup,
        builder: (context, state) => const UsernameSetupPage(),
      ),
      GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
    ],
  );
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Panar',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
