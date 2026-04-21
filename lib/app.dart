import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/observers/route_observer.dart';
import 'core/services/analytics_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/constants/route_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/presentation/pages/username_setup_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/friends/presentation/pages/friends_page.dart';
import 'features/challenges/presentation/pages/create_duel_page.dart';
import 'features/challenges/presentation/pages/create_group_challenge_page.dart';
import 'features/challenges/presentation/pages/duel_detail_page.dart';
import 'features/challenges/presentation/pages/duel_waiting_room_page.dart';
import 'features/challenges/presentation/pages/duels_page.dart';
import 'features/challenges/presentation/pages/group_challenge_detail_page.dart';
import 'features/challenges/presentation/pages/group_challenges_page.dart';
import 'features/live_interactions/presentation/pages/friend_live_run_page.dart';
import 'features/run/presentation/pages/run_import_page.dart';
import 'features/run/presentation/pages/run_launch_page.dart';
import 'features/run/presentation/pages/run_reward_page.dart';
import 'features/run/presentation/pages/run_stats_page.dart';
import 'features/run/presentation/pages/run_tracking_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/profile/presentation/pages/edit_avatar_page.dart';
import 'features/profile/presentation/providers/profile_provider.dart'
    show userProfileProvider, wizardCompleteProvider;
import 'shared/layouts/main_layout.dart';
import 'shared/providers/shared_preferences_provider.dart';
import 'features/notifications/notification_setup_service.dart';
import 'features/notifications/notification_handler.dart';

// A simple ChangeNotifier that GoRouter uses to know when to re-evaluate
// its redirect, without creating a new GoRouter instance.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Router provider — GoRouter is created ONCE and never recreated.
/// Auth/profile changes trigger a redirect re-evaluation via refreshListenable,
/// which preserves widget state (e.g. PageView position in UsernameSetupPage).
final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final firebaseAnalytics = ref.watch(firebaseAnalyticsProvider);

  final refreshNotifier = _RouterRefreshNotifier();

  // Listen to auth and profile changes → notify GoRouter to re-evaluate redirect
  ref.listen(authStateProvider, (_, _) => refreshNotifier.notify());
  ref.listen(userProfileProvider, (_, _) => refreshNotifier.notify());
  ref.listen(wizardCompleteProvider, (_, _) => refreshNotifier.notify());

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refreshNotifier,
    observers: [
      appRouteObserver,
      FirebaseAnalyticsObserver(analytics: firebaseAnalytics),
    ],
    redirect: (context, state) {
      // Read current values at redirect-evaluation time (not reactive)
      final authState = ref.read(authStateProvider);
      final profileAsync = ref.read(userProfileProvider);

      final hasSeenOnboarding =
          prefs.getBool(AppConstants.hasCompletedOnboardingKey) ?? false;

      final user = authState.value;
      final isLoggedIn = user != null;

      // wizardCompleteProvider is set to true at the very start of _finish()
      // to prevent router redirect loops while the DB write is in-flight.
      final wizardComplete = ref.read(wizardCompleteProvider);

      bool hasCompletedOnboarding = false;
      final isProfileLoading = profileAsync.isLoading;

      profileAsync.whenData((profile) {
        hasCompletedOnboarding = profile?.hasCompletedOnboarding ?? false;
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

      // Wait for profile to load before deciding
      if (isLoggedIn && isProfileLoading) {
        return null;
      }

      // If the wizard was just completed locally OR confirmed in DB → no redirect to setup
      final needsUsernameSetup = !wizardComplete && !hasCompletedOnboarding;
      if (isLoggedIn &&
          needsUsernameSetup &&
          location != Routes.usernameSetup) {
        return Routes.usernameSetup;
      }

      // Fully done → prevent access to auth/setup pages
      if (isLoggedIn && (wizardComplete || hasCompletedOnboarding)) {
        if (location == Routes.login ||
            location == Routes.signup ||
            location == Routes.onboarding ||
            location == Routes.usernameSetup) {
          return Routes.home;
        }
      }

      return null;
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
      GoRoute(
        path: Routes.home,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final index = extra?['index'] as int? ?? 0;
          return MainLayout(initialIndex: index);
        },
      ),
      GoRoute(
        path: Routes.friends,
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: Routes.runLaunch,
        builder: (context, state) => const RunLaunchPage(),
      ),
      GoRoute(
        path: Routes.runTracking,
        builder: (context, state) => const RunTrackingPage(),
      ),
      GoRoute(
        path: Routes.runReward,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as String?;
          return RunRewardPage(activityId: activityId);
        },
      ),
      GoRoute(
        path: Routes.runStats,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as String? ?? '';
          return RunStatsPage(activityId: activityId);
        },
      ),
      GoRoute(
        path: Routes.runImport,
        builder: (context, state) => const RunImportPage(),
      ),
      GoRoute(
        path: Routes.friendLiveRun,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FriendLiveRunPage(
            sessionId: extra['sessionId'] as String,
            runnerId: extra['runnerId'] as String,
            runnerName: extra['runnerName'] as String,
          );
        },
      ),
      GoRoute(
        path: Routes.duels,
        builder: (context, state) => const DuelsPage(),
      ),
      GoRoute(
        path: Routes.createDuel,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateDuelPage(initialFriendId: extra?['friendId'] as String?);
        },
      ),
      GoRoute(
        path: Routes.duelDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DuelDetailPage(duelId: id);
        },
      ),
      GoRoute(
        path: Routes.duelWaitingRoom,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DuelWaitingRoomPage(duelId: id);
        },
      ),
      GoRoute(
        path: Routes.groupChallenges,
        builder: (context, state) => const GroupChallengesPage(),
      ),
      GoRoute(
        path: Routes.createGroupChallenge,
        builder: (context, state) => const CreateGroupChallengePage(),
      ),
      GoRoute(
        path: Routes.groupChallengeDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return GroupChallengeDetailPage(challengeId: id);
        },
      ),
      GoRoute(
        path: Routes.editAvatar,
        builder: (context, state) => const EditAvatarPage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(experimentsBootstrapProvider);

    ref.listen(authStateProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull != null;
      final isLoggedIn = next.valueOrNull != null;
      final analyticsService = ref.read(analyticsServiceProvider);

      if (!wasLoggedIn && isLoggedIn) {
        ref.read(wizardCompleteProvider.notifier).state = false;
        unawaited(analyticsService.setUserId(next.valueOrNull?.id));
        NotificationSetupService.initialize();
        NotificationHandler.initialize(ref);
      }

      if (wasLoggedIn && !isLoggedIn) {
        ref.read(wizardCompleteProvider.notifier).state = false;
        unawaited(analyticsService.setUserId(null));
      }
    });

    return MaterialApp.router(
      title: 'Panar',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
