import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../experiments/app_experiments.dart';
import 'analytics_service.dart';

final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  final remoteConfig = ref.watch(remoteConfigProvider);
  return RemoteConfigService(remoteConfig);
});

final experimentsBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(remoteConfigServiceProvider).initialize();
});

final experimentVariantProvider = Provider.family<String, String>((ref, key) {
  final bootstrap = ref.watch(experimentsBootstrapProvider);
  // Return empty string until Remote Config fetch completes so that exposure
  // is never logged against a stale 'control' default that could later change.
  if (!bootstrap.hasValue) return '';
  return ref.watch(remoteConfigServiceProvider).getString(key);
});

final trackedExperimentVariantProvider = Provider.family<String, String>((
  ref,
  key,
) {
  final variant = ref.watch(experimentVariantProvider(key));
  if (variant.isEmpty) return 'control';
  unawaited(
    ref
        .read(analyticsServiceProvider)
        .logExperimentExposure(experimentKey: key, variant: variant),
  );
  return variant;
});

class RemoteConfigService {
  RemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(seconds: 1)
            : const Duration(hours: 12),
      ),
    );

    final defaults = <String, Object>{
      for (final key in AppExperimentKeys.all) key: 'control',
    };
    await _remoteConfig.setDefaults(defaults);

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Network failure or quota exceeded — continue with cached/default values
    }
  }

  String getString(String key) {
    final value = _remoteConfig.getString(key).trim();
    if (value.isEmpty) return 'control';
    return value;
  }
}
