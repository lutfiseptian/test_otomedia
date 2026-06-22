import 'package:isar/isar.dart';
import '../../data/models/location_model.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/tracking_repository.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  final Isar isar;

  TrackingRepositoryImpl(this.isar);

  @override
  Future<void> saveLocation(LocationEntity location) async {
    final model = LocationModel(
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: location.timestamp,
      isSynced: location.isSynced,
    );
    await isar.writeTxn(() async {
      await isar.locationModels.put(model);
    });
  }

  @override
  Future<List<LocationEntity>> getLocalLocationHistory() async {
    // Mengambil semua data diurutkan berdasarkan waktu terbaru (Desc)
    final models = await isar.locationModels.where().sortByTimestampDesc().findAll();

    // Mengubah (mapping) dari Model database menjadi Entity domain
    return models.map((m) => LocationEntity(
      id: m.id,
      latitude: m.latitude,
      longitude: m.longitude,
      timestamp: m.timestamp,
      isSynced: m.isSynced,
    )).toList();
  }

  @override
  Future<List<LocationEntity>> getUnsyncedLocations() async {
    // Memfilter data yang status isSynced-nya masih false
    final models = await isar.locationModels.filter().isSyncedEqualTo(false).findAll();

    return models.map((m) => LocationEntity(
      id: m.id,
      latitude: m.latitude,
      longitude: m.longitude,
      timestamp: m.timestamp,
      isSynced: m.isSynced,
    )).toList();
  }

  @override
  Future<void> markAsSynced(int id) async {
    await isar.writeTxn(() async {
      final model = await isar.locationModels.get(id);
      if (model != null) {
        model.isSynced = true;
        await isar.locationModels.put(model);
      }
    });
  }

  @override
  Future<void> deleteAllLocations() async {
    await isar.writeTxn(() async {
      await isar.locationModels.clear();
    });
  }

  @override
  Future<void> deleteLocation(int id) async {
    await isar.writeTxn(() async {
      await isar.locationModels.delete(id);
    });
  }

  @override
  Stream<void> watchLocations() {
    return isar.locationModels.watchLazy();
  }
}