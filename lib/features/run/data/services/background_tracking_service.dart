import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Service de tracking GPS en arrière-plan.
/// Utilise flutter_foreground_task pour maintenir le processus actif
/// sur Android (notification persistante) et iOS (background location mode).
class BackgroundTrackingService {
  static void _init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'panar_run_tracking',
        channelName: 'Course en cours',
        channelDescription: 'Panar enregistre votre course en arrière-plan.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> start() async {
    _init();
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Course en cours',
      notificationText: 'Panar suit votre course...',
    );
  }

  static Future<void> update({
    required String distance,
    required String duration,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Course en cours — $distance km',
      notificationText: duration,
    );
  }

  static Future<void> stop() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
