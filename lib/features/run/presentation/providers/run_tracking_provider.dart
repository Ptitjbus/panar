import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_activities/live_activities.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../live_interactions/presentation/providers/live_interactions_provider.dart';
import '../../../live_interactions/presentation/providers/run_session_provider.dart';
import '../../data/datasources/petons_datasource.dart';
import '../../data/repositories/run_repository_impl.dart';
import '../../data/services/background_tracking_service.dart';
import '../../data/services/health_service.dart';
import '../../domain/entities/gps_point_entity.dart';

enum RunStatus { idle, running, paused, completed }

class RunTrackingState {
  final RunStatus status;
  final double distanceMeters;
  final int elapsedSeconds;
  final int? currentPaceSecondsPerKm;
  final List<GpsPointEntity> points;
  final String? savedActivityId;
  final String? errorMessage;
  final int petonEarned;
  final int? newPetonsBalance;
  final String? liveSessionId;

  const RunTrackingState({
    this.status = RunStatus.idle,
    this.distanceMeters = 0,
    this.elapsedSeconds = 0,
    this.currentPaceSecondsPerKm,
    this.points = const [],
    this.savedActivityId,
    this.errorMessage,
    this.petonEarned = 0,
    this.newPetonsBalance,
    this.liveSessionId,
  });

  RunTrackingState copyWith({
    RunStatus? status,
    double? distanceMeters,
    int? elapsedSeconds,
    int? currentPaceSecondsPerKm,
    List<GpsPointEntity>? points,
    String? savedActivityId,
    String? errorMessage,
    int? petonEarned,
    int? newPetonsBalance,
    String? liveSessionId,
  }) {
    return RunTrackingState(
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentPaceSecondsPerKm:
          currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      points: points ?? this.points,
      savedActivityId: savedActivityId ?? this.savedActivityId,
      errorMessage: errorMessage,
      petonEarned: petonEarned ?? this.petonEarned,
      newPetonsBalance: newPetonsBalance ?? this.newPetonsBalance,
      liveSessionId: liveSessionId ?? this.liveSessionId,
    );
  }

  String get formattedDistance {
    final km = distanceMeters / 1000;
    return km.toStringAsFixed(2);
  }

  String get formattedDuration {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (currentPaceSecondsPerKm == null || currentPaceSecondsPerKm! <= 0) {
      return '--:--';
    }
    final minutes = currentPaceSecondsPerKm! ~/ 60;
    final seconds = currentPaceSecondsPerKm! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedAveragePace {
    if (distanceMeters < 100 || elapsedSeconds <= 0) return '--:--';
    final secondsPerKm = (elapsedSeconds / (distanceMeters / 1000)).round();
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 1 peton par 100m, minimum 1 si la course est terminée
  static int computePetons(double distanceMeters) {
    return max(1, (distanceMeters / 100).floor());
  }
}

class RunTrackingNotifier extends StateNotifier<RunTrackingState> {
  final Ref _ref;

  static const _appGroupId = 'group.com.panar.run';
  final _liveActivities = LiveActivities();
  String? _liveActivityId;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _elapsedTimer;
  Position? _lastPosition;
  DateTime? _startTime;
  int _pointSequence = 0;
  DateTime? _lastLiveActivityUpdate;
  DateTime? _lastSessionUpdate;

  RunTrackingNotifier(this._ref) : super(const RunTrackingState());

  Future<void> startRun() async {
    final permission = await _requestLocationPermission();
    if (!permission) return;

    _startTime = DateTime.now();
    _pointSequence = 0;
    _lastPosition = null;

    state = state.copyWith(
      status: RunStatus.running,
      distanceMeters: 0,
      elapsedSeconds: 0,
      points: [],
      savedActivityId: null,
      errorMessage: null,
      petonEarned: 0,
      newPetonsBalance: null,
    );

    _startTimer();
    _startLocationStream();
    BackgroundTrackingService.start();
    unawaited(_startLiveActivity());
    unawaited(_startLiveSession());
  }

  void pauseRun() {
    if (state.status != RunStatus.running) return;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    state = state.copyWith(status: RunStatus.paused);
    BackgroundTrackingService.stop();
  }

  void resumeRun() {
    if (state.status != RunStatus.paused) return;
    state = state.copyWith(status: RunStatus.running);
    _startTimer();
    _startLocationStream();
    BackgroundTrackingService.start();
  }

  Future<String?> stopRun() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    BackgroundTrackingService.stop();
    unawaited(_endLiveActivity());
    unawaited(_endLiveSession());

    // Activité trop courte — on nettoie mais on ne sauvegarde pas
    if (state.elapsedSeconds < 60) {
      state = state.copyWith(status: RunStatus.completed);
      return null;
    }

    final endedAt = DateTime.now();
    final startedAt = _startTime ?? endedAt;
    final petons = RunTrackingState.computePetons(state.distanceMeters);

    state = state.copyWith(status: RunStatus.completed, petonEarned: petons);

    final userAsync = _ref.read(authStateProvider);
    final userId = userAsync.value?.id;
    if (userId == null) return null;

    try {
      final activity = await _ref
          .read(runRepositoryProvider)
          .saveActivity(
            userId: userId,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: state.elapsedSeconds,
            distanceMeters: state.distanceMeters,
            avgPaceSecondsPerKm: state.currentPaceSecondsPerKm,
            points: state.points,
          );

      // Attribution des petons (opération atomique via RPC)
      int? newBalance;
      try {
        newBalance = await _ref
            .read(petonsDatasourceProvider)
            .awardPetons(userId, petons);
      } catch (_) {
        // Échec non bloquant
      }

      // Synchronisation avec Apple Health / Health Connect
      try {
        final health = _ref.read(healthServiceProvider);
        final calories = await health.getActiveCalories(startedAt, endedAt);
        await health.writeWorkout(
          start: startedAt,
          end: endedAt,
          distanceMeters: state.distanceMeters,
          calories: calories,
        );
      } catch (_) {
        // Échec non bloquant — Health peut ne pas être disponible
      }

      if (mounted) {
        state = state.copyWith(
          savedActivityId: activity.id,
          newPetonsBalance: newBalance,
        );
      }
      return activity.id;
    } on DatabaseFailure catch (e) {
      if (mounted) {
        state = state.copyWith(errorMessage: e.message);
      }
      return null;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: 'Erreur lors de la sauvegarde de la course.',
        );
      }
      return null;
    }
  }

  void resetRun() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _startTime = null;
    _pointSequence = 0;
    _lastPosition = null;
    state = const RunTrackingState();
  }

  void _startTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _startLocationStream() {
    _locationSubscription?.cancel();

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
      );
    }

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) {
          if (!mounted) return;
          _onNewPosition(position);
        });
  }

  void _onNewPosition(Position position) {
    double addedDistance = 0;
    if (_lastPosition != null) {
      addedDistance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    _lastPosition = position;
    final newDistance = state.distanceMeters + addedDistance;
    final newPoint = GpsPointEntity(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      recordedAt: DateTime.now(),
      sequence: _pointSequence++,
    );

    int? pace;
    if (newDistance > 0 && state.elapsedSeconds > 0) {
      pace = (state.elapsedSeconds / (newDistance / 1000)).round();
    }

    state = state.copyWith(
      distanceMeters: newDistance,
      currentPaceSecondsPerKm: pace,
      points: [...state.points, newPoint],
    );

    // Mise à jour session live (throttle 10s)
    _updateLiveSession();

    // Mise à jour de la notification Android background
    BackgroundTrackingService.update(
      distance: (newDistance / 1000).toStringAsFixed(2),
      duration: state.formattedDuration,
    );

    // Mise à jour Live Activity (throttle 5s)
    final now = DateTime.now();
    if (_lastLiveActivityUpdate == null ||
        now.difference(_lastLiveActivityUpdate!).inSeconds >= 5) {
      _lastLiveActivityUpdate = now;
      _updateLiveActivity(
        distance: (newDistance / 1000).toStringAsFixed(2),
        duration: state.formattedDuration,
        pace: state.formattedPace,
      );
    }
  }

  Future<void> _startLiveActivity() async {
    try {
      await _liveActivities.init(appGroupId: _appGroupId);
      final id = 'panar_run_${DateTime.now().millisecondsSinceEpoch}';
      await _liveActivities.createActivity(id, {
        'distance': '0.00',
        'duration': '00:00',
        'pace': '--:--',
      });
      _liveActivityId = id;
    } catch (_) {
      // Non-bloquant — Live Activities non disponibles (simulateur, iOS < 16.1)
    }
  }

  void _updateLiveActivity({
    required String distance,
    required String duration,
    required String pace,
  }) {
    final id = _liveActivityId;
    if (id == null) return;
    _liveActivities
        .updateActivity(id, {
          'distance': distance,
          'duration': duration,
          'pace': pace,
        })
        .catchError((_) {});
  }

  Future<void> _endLiveActivity() async {
    final id = _liveActivityId;
    if (id == null) return;
    try {
      await _liveActivities.endActivity(id);
    } catch (_) {}
    _liveActivityId = null;
  }

  Future<void> _startLiveSession() async {
    try {
      final sessionId = await _ref
          .read(runSessionNotifierProvider.notifier)
          .startSession();
      if (sessionId != null && mounted) {
        state = state.copyWith(liveSessionId: sessionId);
        _ref
            .read(incomingInteractionsProvider.notifier)
            .startListening(sessionId);
      }
    } catch (_) {
      // Non-bloquant — le live peut échouer sans bloquer la course
    }
  }

  Future<void> _endLiveSession() async {
    try {
      await _ref.read(runSessionNotifierProvider.notifier).endSession();
      _ref.read(incomingInteractionsProvider.notifier).stopListening();
    } catch (_) {}
  }

  void _updateLiveSession() {
    final now = DateTime.now();
    if (_lastSessionUpdate != null &&
        now.difference(_lastSessionUpdate!).inSeconds < 10) {
      return;
    }
    _lastSessionUpdate = now;
    _ref.read(runSessionNotifierProvider.notifier).updateSession(
      distanceMeters: state.distanceMeters,
      elapsedSeconds: state.elapsedSeconds,
      currentPaceSecondsPerKm: state.currentPaceSecondsPerKm?.toDouble(),
    );
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          state = state.copyWith(
            errorMessage: 'Permission de localisation refusée.',
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        state = state.copyWith(
          errorMessage:
              'Permission refusée définitivement. Activez-la dans les réglages.',
        );
      }
      return false;
    }

    // Sur iOS : si l'utilisateur n'a accordé que "En utilisant l'app",
    // demander l'upgrade vers "Toujours" pour le tracking background.
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
      // On continue même si refusé — le tracking fonctionne en foreground.
    }

    return true;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }
}

final runTrackingProvider =
    StateNotifierProvider<RunTrackingNotifier, RunTrackingState>((ref) {
      return RunTrackingNotifier(ref);
    });
