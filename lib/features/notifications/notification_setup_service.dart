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
        // Il faut parfois attendre que l'OS fournisse le token APNs
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(seconds: 8));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apnsToken == null) {
          debugPrint(
            '[Notifications] APNS token toujours null après attente — abandon.',
          );
          return;
        }
        debugPrint('[Notifications] APNS token OK: $apnsToken');
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('[Notifications] FCM TOKEN: $token'); // ← ajoute ça
        await _upsertToken(token);
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
