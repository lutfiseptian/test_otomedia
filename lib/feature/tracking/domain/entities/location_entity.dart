class LocationEntity {
  final int? id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isSynced;

  LocationEntity({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isSynced,
  });
}