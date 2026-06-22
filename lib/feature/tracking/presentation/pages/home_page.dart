import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tracking_service.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../bloc/tracking_state.dart';
import 'map_tab.dart';
import 'history_tab.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  final TrackingRepository repository;

  const HomePage({
    super.key,
    required this.repository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TrackingService trackingService = TrackingService();
  late TrackingBloc bloc;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    bloc = TrackingBloc(widget.repository, trackingService);
    // Jalankan tracking dan load history saat halaman dibuka
    bloc.add(StartTracking());
    bloc.add(LoadTrackingHistory());
  }

  @override
  void dispose() {
    bloc.add(StopTracking());
    bloc.close();
    super.dispose();
  }

  Future<void> _showLogoutConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Keluar Aplikasi"),
          ],
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar? Pelacakan lokasi akan dihentikan secara otomatis.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Hentikan tracking pelacakan
      bloc.add(StopTracking());
      
      // Navigasi kembali ke LoginPage dan hapus semua tumpukan history navigasi
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginPage(repository: widget.repository),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: BlocBuilder<TrackingBloc, TrackingState>(
        builder: (context, state) {
          Widget bodyWidget;
          
          if (state is TrackingLoading) {
            bodyWidget = const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is TrackingLoaded) {
            bodyWidget = IndexedStack(
              index: _currentIndex,
              children: [
                MapTab(
                  history: state.history,
                  repository: widget.repository,
                ),
                HistoryTab(
                  history: state.history,
                  repository: widget.repository,
                ),
              ],
            );
          } else if (state is TrackingError) {
            bodyWidget = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    "Terjadi Kesalahan:\n${state.message}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      bloc.add(LoadTrackingHistory());
                    },
                    child: const Text("Coba Lagi"),
                  ),
                ],
              ),
            );
          } else {
            bodyWidget = const Center(
              child: Text("Tidak ada data"),
            );
          }

          final isTracking = state is TrackingLoaded ? state.isTracking : false;

          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FB),
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(
                    _currentIndex == 0 ? Icons.map : Icons.history,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentIndex == 0 ? "Peta Tracker" : "Riwayat Lokasi",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (_currentIndex == 0 && isTracking) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  tooltip: "Keluar",
                  onPressed: () => _showLogoutConfirmDialog(context),
                ),
                const SizedBox(width: 8),
              ],
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.grey.shade200,
                  height: 1.0,
                ),
              ),
            ),
            body: bodyWidget,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: Colors.white,
                selectedItemColor: Colors.blue.shade700,
                unselectedItemColor: Colors.grey.shade400,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map),
                    label: 'Peta',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history_outlined),
                    activeIcon: Icon(Icons.history),
                    label: 'Riwayat',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}