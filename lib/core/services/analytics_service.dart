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
      parameters: {'experiment_key': experimentKey, 'variant': variant},
    );
  }

  Future<void> logFeatureClick({
    required String feature,
    String? variant,
    String? source,
    Map<String, Object>? extraParameters,
  }) async {
    final parameters = <String, Object>{'feature': feature};
    if (variant != null) parameters['variant'] = variant;
    if (source != null) parameters['source'] = source;
    if (extraParameters != null) {
      parameters.addAll(extraParameters);
    }

    await logEvent(name: 'feature_click', parameters: parameters);
  }

  Future<void> logFunnelStep({
    required String funnel,
    required String step,
    String? variant,
    String? source,
    Map<String, Object>? extraParameters,
  }) async {
    final parameters = <String, Object>{'funnel': funnel, 'step': step};
    if (variant != null) parameters['variant'] = variant;
    if (source != null) parameters['source'] = source;
    if (extraParameters != null) {
      parameters.addAll(extraParameters);
    }

    await logEvent(name: 'funnel_step', parameters: parameters);
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
