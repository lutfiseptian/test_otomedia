import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/network/sync_service.dart';
import 'feature/tracking/data/models/location_model.dart';
import 'feature/tracking/domain/repositories/tracking_repository_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();

  final isar = await Isar.open(
    [LocationModelSchema],
    directory: dir.path,
  );

  final repository = TrackingRepositoryImpl(isar);

  SyncService(repository);

  runApp(
    MyApp(
      repository: repository,
    ),
  );
}