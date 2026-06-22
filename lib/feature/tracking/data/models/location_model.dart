import 'package:isar/isar.dart';
part 'location_model.g.dart';

@collection
class LocationModel {
  Id id = Isar.autoIncrement;

  double latitude;
  double longitude;
  DateTime timestamp;
  bool isSynced;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isSynced = false,
  });
}