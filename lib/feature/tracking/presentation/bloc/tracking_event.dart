import '../../domain/entities/location_entity.dart';

abstract class TrackingEvent {}

/// Load semua history dari Isar
class LoadTrackingHistory extends TrackingEvent {}

/// Tambah lokasi baru
class AddNewLocation extends TrackingEvent {
  final LocationEntity location;

  AddNewLocation(this.location);
}

/// Mulai tracking GPS
class StartTracking extends TrackingEvent {}

/// Berhenti tracking GPS
class StopTracking extends TrackingEvent {}