import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../domain/entities/location_entity.dart';

class HistoryCard extends StatefulWidget {
  final LocationEntity location;
  final Function(LocationEntity) onDelete; // Callback untuk aksi hapus

  const HistoryCard({
    super.key,
    required this.location,
    required this.onDelete,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  late Future<String> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = _getAddress(widget.location.latitude, widget.location.longitude);
  }

  @override
  void didUpdateWidget(covariant HistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _addressFuture = _getAddress(widget.location.latitude, widget.location.longitude);
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Riwayat Ini?"),
        content: const Text("Apakah kamu yakin ingin menghapus lokasi terpilih ini dari riwayat?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete(widget.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // Padding internal card
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: widget.location.isSynced
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              child: Icon(
                widget.location.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                color: widget.location.isSynced ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Alamat Geocoding
                  FutureBuilder<String>(
                    future: _addressFuture,
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? "Mencari alamat...",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  // Koordinat Lat & Lon
                  Text(
                    "Lat: ${widget.location.latitude.toStringAsFixed(6)}, Lon: ${widget.location.longitude.toStringAsFixed(6)}",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp
                  Text(
                    widget.location.timestamp.toString(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _showDeleteConfirmDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getAddress(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return "Alamat tidak ditemukan";

      final place = placemarks.first;
      final address = [
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).join(", ");

      return address.isEmpty ? "Alamat tidak dikenal" : address;
    } catch (_) {
      return "Alamat tidak diketahui";
    }
  }
}