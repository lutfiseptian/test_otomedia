import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../bloc/tracking_state.dart';

class MapTab extends StatefulWidget {
  final List<LocationEntity> history;
  final TrackingRepository repository;

  const MapTab({
    super.key,
    required this.history,
    required this.repository,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  LocationEntity? _selectedLocation;
  String _selectedAddress = "Mencari alamat...";
  bool _hasCenteredInitially = false;

  @override
  void didUpdateWidget(covariant MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.isNotEmpty && !_hasCenteredInitially) {
      _centerOnLatest();
      _hasCenteredInitially = true;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.history.isNotEmpty) {
      _hasCenteredInitially = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnLatest();
      });
    }
  }

  void _centerOnLatest() {
    if (widget.history.isNotEmpty) {
      final latest = widget.history.first;
      _mapController.move(LatLng(latest.latitude, latest.longitude), 16.0);
    } else {
      _centerOnDeviceLocation();
    }
  }

  Future<void> _centerOnDeviceLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
      }
    } catch (_) {
      _mapController.move(const LatLng(-6.2088, 106.8456), 12.0);
    }
  }

  Future<void> _fetchSelectedAddress(LocationEntity location) async {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = "Mencari alamat...";
    });

    try {
      final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((e) => e != null && e.trim().isNotEmpty).join(", ");
        
        setState(() {
          _selectedAddress = address.isEmpty ? "Alamat tidak dikenal" : address;
        });
      } else {
        setState(() {
          _selectedAddress = "Alamat tidak ditemukan";
        });
      }
    } catch (_) {
      setState(() {
        _selectedAddress = "Gagal memuat alamat";
      });
    }
  }

  Future<void> _saveManualLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("GPS handphone belum aktif")),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Akses izin lokasi ditolak")),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mendapatkan lokasi saat ini..."), duration: Duration(seconds: 1)),
      );

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (!mounted) return;
      final newLoc = LocationEntity(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        isSynced: false,
      );

      await widget.repository.saveLocation(newLoc);
      if (!mounted) return;

      context.read<TrackingBloc>().add(LoadTrackingHistory());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lokasi berhasil disimpan ke riwayat")),
      );

      _mapController.move(LatLng(position.latitude, position.longitude), 16.5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan lokasi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrackingBloc>().state;
    final isTracking = state is TrackingLoaded ? state.isTracking : false;

    final pathPoints = widget.history.reversed
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();

    final currentPoint = widget.history.isNotEmpty
        ? LatLng(widget.history.first.latitude, widget.history.first.longitude)
        : const LatLng(-6.2088, 106.8456); // Fallback ke titik statis jakarta

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentPoint,
            initialZoom: 15.0,
            maxZoom: 18.0,
            minZoom: 3.0,
          ),
          children: [
            TileLayer(
              //untuk tampilan ui map agar menjadi potongan2 wilayah
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.otomedia.testtracker',
              retinaMode: RetinaMode.isHighDensity(context),
            ),

            if (pathPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: pathPoints,
                    color: Colors.blue.shade600,
                    strokeWidth: 4.5,
                    isDotted: false,
                    borderColor: Colors.blue.shade900.withOpacity(0.3),
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

            MarkerLayer(
              markers: [
                ...widget.history.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final loc = entry.value;
                  final isLatest = idx == 0;
                  final isStart = idx == widget.history.length - 1;

                  if (isLatest) return Marker(point: const LatLng(0, 0), child: const SizedBox.shrink()); // Handled below separately
                  
                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 26,
                    height: 26,
                    child: GestureDetector(
                      onTap: () => _fetchSelectedAddress(loc),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isStart ? Colors.green.shade500 : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isStart ? Colors.white : Colors.red.shade500,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isStart ? Icons.flag : Icons.circle,
                            size: isStart ? 12 : 6,
                            color: isStart ? Colors.white : Colors.red.shade500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                if (widget.history.isNotEmpty)
                  Marker(
                    point: currentPoint,
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _fetchSelectedAddress(widget.history.first),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ripple animation circle effect
                          if (isTracking)
                            _RippleCircleAnimation(),
                          
                          // Inner blue core
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade800.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.navigation,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: _selectedLocation != null ? 220 : 24,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Center Map on Latest Position
              _buildFloatActionButton(
                icon: Icons.my_location,
                color: Colors.white,
                iconColor: Colors.blue.shade700,
                onPressed: _centerOnLatest,
                tooltip: "Pusatkan Peta",
              ),
              const SizedBox(height: 12),

              // 2. Save Current Location manually
              _buildFloatActionButton(
                icon: Icons.add_location_alt,
                color: Colors.blue.shade600,
                iconColor: Colors.white,
                onPressed: _saveManualLocation,
                tooltip: "Simpan Koordinat Sekarang",
              ),
              const SizedBox(height: 12),

              // 3. Play / Pause GPS Service tracking
              _buildFloatActionButton(
                icon: isTracking ? Icons.stop : Icons.play_arrow,
                color: isTracking ? Colors.red.shade500 : Colors.green.shade500,
                iconColor: Colors.white,
                onPressed: () {
                  if (isTracking) {
                    context.read<TrackingBloc>().add(StopTracking());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pelacakan GPS dihentikan")),
                    );
                  } else {
                    context.read<TrackingBloc>().add(StartTracking());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pelacakan GPS dimulai")),
                    );
                  }
                },
                tooltip: isTracking ? "Stop Pelacakan" : "Mulai Pelacakan",
              ),
            ],
          ),
        ),

        if (_selectedLocation != null)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Card Header: Address with Close button
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Informasi Detail Titik",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedLocation = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  
                  // Geocoded Address
                  Text(
                    _selectedAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Coordinates info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Latitude: ${_selectedLocation!.latitude.toStringAsFixed(7)}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            Text(
                              "Longitude: ${_selectedLocation!.longitude.toStringAsFixed(7)}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                      // Timestamp inside right-aligned box
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDateTime(_selectedLocation!.timestamp),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          // Sync Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedLocation!.isSynced
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedLocation!.isSynced ? "Synced" : "Pending Sync",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _selectedLocation!.isSynced
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade100),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Hapus Titik Lokasi?"),
                            content: const Text("Apakah Anda yakin ingin menghapus titik koordinat ini dari riwayat?"),
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

                        if (confirmed == true && mounted) {
                          await widget.repository.deleteLocation(_selectedLocation!.id!);
                          if (!mounted) return;
                          context.read<TrackingBloc>().add(LoadTrackingHistory());
                          setState(() {
                            _selectedLocation = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Titik berhasil dihapus dari riwayat")),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Hapus Titik Koordinat"),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatActionButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return FloatingActionButton(
      heroTag: tooltip, // unique tag to prevent hero errors
      onPressed: onPressed,
      backgroundColor: color,
      foregroundColor: iconColor,
      mini: true,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: tooltip,
      child: Icon(icon, size: 20),
    );
  }

  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return "$year-$month-$day $hour:$minute:$second";
  }
}

class _RippleCircleAnimation extends StatefulWidget {
  @override
  State<_RippleCircleAnimation> createState() => _RippleCircleAnimationState();
}

class _RippleCircleAnimationState extends State<_RippleCircleAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 14.0, end: 42.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: _animation.value,
          height: _animation.value,
          decoration: BoxDecoration(
            color: Colors.blue.shade400.withOpacity((1 - _animController.value).clamp(0.0, 0.4)),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.shade600.withOpacity((1 - _animController.value).clamp(0.0, 0.6)),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}
