import '../../domain/entities/gps_point_entity.dart';

class GpsPointModel extends GpsPointEntity {
  const GpsPointModel({
    required super.latitude,
    required super.longitude,
    super.altitude,
    required super.recordedAt,
    required super.sequence,
  });

  factory GpsPointModel.fromJson(Map<String, dynamic> json) {
    return GpsPointModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      sequence: json['sequence'] as int,
    );
  }

  Map<String, dynamic> toJson(String activityId) {
    return {
      'activity_id': activityId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'recorded_at': recordedAt.toIso8601String(),
      'sequence': sequence,
    };
  }
}
