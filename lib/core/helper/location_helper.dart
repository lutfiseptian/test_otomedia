import 'package:geocoding/geocoding.dart';

class LocationHelper {
  static Future<String> getAddress(
      double latitude,
      double longitude,
      ) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return "Alamat tidak ditemukan";
      }

      final place = placemarks.first;

      return "${place.subLocality}, ${place.locality}";
    } catch (e) {
      return "Tidak dapat mengambil alamat";
    }
  }
}