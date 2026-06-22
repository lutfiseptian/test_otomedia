import '../entities/location_entity.dart';

abstract class TrackingRepository {
  Future<void> saveLocation(LocationEntity location);

  Future<List<LocationEntity>> getLocalLocationHistory();

  Future<List<LocationEntity>> getUnsyncedLocations();

  Future<void> markAsSynced(int id);

  Future<void> deleteAllLocations();

  Future<void> deleteLocation(int id);

  Stream<void> watchLocations();
}