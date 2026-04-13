class GpsPointEntity {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime recordedAt;
  final int sequence;

  const GpsPointEntity({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.recordedAt,
    required this.sequence,
  });
}
