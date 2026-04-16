import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../core/constants/route_constants.dart';

/// Gère la navigation lorsque l'utilisateur tape sur une notification.
class NotificationHandler {
  static void initialize(Ref ref) {
    // App en arrière-plan → tap sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _route(ref, message.data);
    });

    // App terminée → tap sur la notif au démarrage
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _route(ref, message.data);
    });
  }

  static void _route(Ref ref, Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final type = data['type'] as String?;

    switch (type) {
      case 'run_started':
        router.push(Routes.friendLiveRun, extra: {
          'sessionId': data['session_id'] as String? ?? '',
          'runnerId': data['runner_id'] as String? ?? '',
          'runnerName': '',
        });
      case 'duel_invite':
      case 'duel_result':
        final duelId = data['duel_id'] as String?;
        if (duelId != null) router.push('/challenges/duels/$duelId');
      case 'group_challenge_invite':
      case 'group_challenge_completed':
        final challengeId = data['challenge_id'] as String?;
        if (challengeId != null) router.push('/challenges/group/$challengeId');
      default:
        router.go(Routes.home);
    }
  }
}
