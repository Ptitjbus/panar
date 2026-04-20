import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
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
  ref.watch(experimentsBootstrapProvider);
  return ref.watch(remoteConfigServiceProvider).getString(key);
});

final trackedExperimentVariantProvider = Provider.family<String, String>((
  ref,
  key,
) {
  final variant = ref.watch(experimentVariantProvider(key));
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
        minimumFetchInterval: const Duration(seconds: 1),
      ),
    );

    final defaults = <String, Object>{
      for (final key in AppExperimentKeys.all) key: 'control',
    };
    await _remoteConfig.setDefaults(defaults);

    await _remoteConfig.fetchAndActivate();
  }

  String getString(String key) {
    final value = _remoteConfig.getString(key).trim();
    if (value.isEmpty) return 'control';
    return value;
  }
}
