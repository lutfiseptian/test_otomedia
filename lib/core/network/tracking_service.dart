import 'dart:async';

import 'package:geolocator/geolocator.dart';

class TrackingService {
  Timer? _timer;

  Future<void> start({
    required Function(Position position) onLocation,
  }) async {
    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception("GPS belum aktif");
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permission ditolak");
    }

    _timer = Timer.periodic(
      const Duration(seconds: 10),
          (_) async {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );

        onLocation(position);
      },
    );
  }

  void stop() {
    _timer?.cancel();
  }
}