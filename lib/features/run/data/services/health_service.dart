import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

/// Service d'intégration avec Apple Health (iOS) et Health Connect (Android).
///
/// ⚠️ iOS : Requiert la capability HealthKit activée dans Xcode :
///   Runner target → Signing & Capabilities → + Capability → HealthKit
class HealthService {
  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  /// Demande les permissions HealthKit / Health Connect.
  Future<bool> requestPermissions() async {
    try {
      final types = [..._readTypes, HealthDataType.WORKOUT];
      final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList()
        ..add(HealthDataAccess.READ_WRITE);
      return await Health().requestAuthorization(types, permissions: permissions);
    } catch (_) {
      return false;
    }
  }

  /// Lit le nombre de pas entre [start] et [end].
  Future<int> getSteps(DateTime start, DateTime end) async {
    try {
      return await Health().getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Lit les calories actives brûlées entre [start] et [end].
  Future<double> getActiveCalories(DateTime start, DateTime end) async {
    try {
      final data = await Health().getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double total = 0;
      for (final point in data) {
        final value = point.value;
        if (value is NumericHealthValue) {
          total += value.numericValue.toDouble();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Écrit la course dans Apple Health / Health Connect.
  Future<bool> writeWorkout({
    required DateTime start,
    required DateTime end,
    required double distanceMeters,
    required double calories,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      return await Health().writeWorkoutData(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: start,
        end: end,
        totalDistance: distanceMeters.round(),
        totalDistanceUnit: HealthDataUnit.METER,
        totalEnergyBurned: calories > 0 ? calories.round() : null,
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (_) {
      return false;
    }
  }

  /// Récupère les courses enregistrées dans Health depuis [since].
  Future<List<HealthDataPoint>> getExternalWorkouts(DateTime since) async {
    try {
      final data = await Health().getHealthDataFromTypes(
        startTime: since,
        endTime: DateTime.now(),
        types: [HealthDataType.WORKOUT],
      );
      return data.where((p) {
        final val = p.value;
        if (val is WorkoutHealthValue) {
          return val.workoutActivityType == HealthWorkoutActivityType.RUNNING ||
              val.workoutActivityType == HealthWorkoutActivityType.WALKING;
        }
        return false;
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());
