import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final analytics = ref.watch(firebaseAnalyticsProvider);
  return AnalyticsService(analytics);
});

class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;
  final Set<String> _loggedExposureKeys = <String>{};

  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  Future<void> logExperimentExposure({
    required String experimentKey,
    required String variant,
  }) async {
    final dedupeKey = '$experimentKey::$variant';
    if (_loggedExposureKeys.contains(dedupeKey)) return;
    _loggedExposureKeys.add(dedupeKey);

    await _analytics.logEvent(
      name: 'ab_exposure',
      parameters: {
        'experiment_key': experimentKey,
        'variant': variant,
      },
    );
  }

  Future<void> logFeatureClick({
    required String feature,
    String? variant,
    String? source,
  }) async {
    final parameters = <String, Object>{'feature': feature};
    if (variant != null) parameters['variant'] = variant;
    if (source != null) parameters['source'] = source;

    await _analytics.logEvent(
      name: 'feature_click',
      parameters: parameters,
    );
  }
}
