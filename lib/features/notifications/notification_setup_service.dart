import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialise Firebase Messaging, peut demander la permission iOS,
/// enregistre le token dans device_tokens, et configure l'affichage foreground.
class NotificationSetupService {
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static int _notifId = 0;
  static bool _initialized = false;

  static void dispose() {
    _initialized = false;
    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _tokenRefreshSub = null;
    _messageSub = null;
  }

  static Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;
    _initialized = true;
    await _initLocalNotifications();

    final settings = requestPermission
        ? await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await FirebaseMessaging.instance.getNotificationSettings();

    debugPrint('[Notifications] Auth status: ${settings.authorizationStatus}');
    const authorized = {
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    };
    if (!authorized.contains(settings.authorizationStatus)) return;

    await _registerToken();

    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      _upsertToken,
    );
    _messageSub = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
  }

  static Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(initSettings);
  }

  static Future<void> _registerToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // L'OS peut mettre plusieurs secondes à fournir le token APNs —
        // on tente jusqu'à 5 fois avec des délais croissants.
        String? apnsToken;
        for (int attempt = 1; attempt <= 5; attempt++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) break;
          final waitSeconds = attempt * 3; // 3, 6, 9, 12, 15 s
          debugPrint(
            '[Notifications] APNS token null — tentative $attempt, attente ${waitSeconds}s…',
          );
          await Future<void>.delayed(Duration(seconds: waitSeconds));
        }
        if (apnsToken == null) {
          debugPrint(
            '[Notifications] APNS token toujours null après 5 tentatives — abandon.',
          );
          return;
        }
        debugPrint('[Notifications] APNS token OK: $apnsToken');
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('[Notifications] FCM token: $token');
        await _upsertToken(token);
      } else {
        debugPrint('[Notifications] FCM token null — vérifier la configuration Firebase/APNs.');
      }
    } catch (e) {
      debugPrint('[Notifications] Erreur register token: $e');
    }
  }

  static Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': 'ios',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,platform');
      debugPrint('[Notifications] Token enregistré');
    } catch (e) {
      debugPrint('[Notifications] Erreur upsert token: $e');
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const notifDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      _notifId++,
      notification.title,
      notification.body,
      notifDetails,
    );
  }
}
