import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../core/constants/route_constants.dart';

/// Gère la navigation lorsque l'utilisateur tape sur une notification.
class NotificationHandler {
  NotificationHandler._();

  static void initialize(WidgetRef ref) {
    // App en arrière-plan → tap sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _route(ref, message.data.cast<String, String>());
    });

    // App terminée → tap sur la notif au démarrage
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _route(ref, message.data.cast<String, String>());
    }).catchError((Object e) {
      debugPrint('[NotificationHandler] getInitialMessage error: $e');
    });
  }

  static void _route(WidgetRef ref, Map<String, String> data) {
    final router = ref.read(routerProvider);
    final type = data['type'];

    switch (type) {
      case 'run_started':
        router.push(Routes.friendLiveRun, extra: {
          'sessionId': data['session_id'] ?? '',
          'runnerId': data['runner_id'] ?? '',
          'runnerName': '',
        });
      case 'duel_invite':
      case 'duel_result':
        final duelId = data['duel_id'];
        if (duelId != null) {
          router.push('/challenges/duels/$duelId');
        } else {
          router.go(Routes.home);
        }
      case 'group_challenge_invite':
      case 'group_challenge_completed':
        final challengeId = data['challenge_id'];
        if (challengeId != null) {
          router.push('/challenges/group/$challengeId');
        } else {
          router.go(Routes.home);
        }
      default:
        router.go(Routes.home);
    }
  }
}
