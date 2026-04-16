import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialise Firebase Messaging, demande la permission iOS, enregistre le token
/// dans device_tokens, et configure l'affichage foreground.
class NotificationSetupService {
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static int _notifId = 0;

  static Future<void> initialize() async {
    await _initLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const authorized = {AuthorizationStatus.authorized, AuthorizationStatus.provisional};
    if (!authorized.contains(settings.authorizationStatus)) return;

    await _registerToken();

    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_upsertToken);
    _messageSub = FirebaseMessaging.onMessage.listen(_showForegroundNotification);
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
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _upsertToken(token);
  }

  static Future<void> _upsertToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {'user_id': userId, 'fcm_token': token, 'platform': 'ios'},
        onConflict: 'user_id,fcm_token',
      );
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
