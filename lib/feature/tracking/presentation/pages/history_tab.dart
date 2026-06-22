import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../bloc/tracking_bloc.dart';
import '../bloc/tracking_event.dart';
import '../widget/history_card.dart';

class HistoryTab extends StatefulWidget {
  final List<LocationEntity> history;
  final TrackingRepository repository;

  const HistoryTab({
    super.key,
    required this.history,
    required this.repository,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Future<void> _showDeleteAllConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Hapus Semua Riwayat?"),
          ],
        ),
        content: const Text(
          "Apakah Anda yakin ingin menghapus seluruh riwayat lokasi? Tindakan ini tidak dapat dibatalkan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus Semua", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await widget.repository.deleteAllLocations();
        if (context.mounted) {
          context.read<TrackingBloc>().add(LoadTrackingHistory());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Seluruh riwayat lokasi berhasil dihapus")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal menghapus riwayat: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter history based on search query (by coords or index)
    final filteredHistory = widget.history.where((loc) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final latStr = loc.latitude.toString().toLowerCase();
      final lonStr = loc.longitude.toString().toLowerCase();
      final dateStr = loc.timestamp.toString().toLowerCase();
      return latStr.contains(query) || lonStr.contains(query) || dateStr.contains(query);
    }).toList();

    // Stats calculations
    final totalCount = widget.history.length;
    final syncedCount = widget.history.where((e) => e.isSynced).length;
    final pendingCount = totalCount - syncedCount;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TrackingBloc>().add(LoadTrackingHistory());
      },
      child: Column(
        children: [
          // 📊 STATS PANEL CARD
          _buildStatsCard(
            total: totalCount,
            synced: syncedCount,
            pending: pendingCount,
          ),

          // 🔍 SEARCH BAR & CLEAN UP ACTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = "";
                                  });
                                },
                              )
                            : null,
                        hintText: "Cari berdasarkan koordinat/tanggal...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Delete All Button
                Tooltip(
                  message: "Hapus Semua Riwayat",
                  child: Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: totalCount > 0 ? () => _showDeleteAllConfirmDialog(context) : null,
                      child: Container(
                        height: 48,
                        width: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.delete_sweep_outlined,
                          color: totalCount > 0 ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📜 LIST OF LOCATIONS
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      return HistoryCard(
                        location: item,
                        onDelete: (locationToDelete) async {
                          await widget.repository.deleteLocation(locationToDelete.id!);
                          if (context.mounted) {
                            context.read<TrackingBloc>().add(LoadTrackingHistory());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Riwayat lokasi berhasil dihapus")),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard({required int total, required int synced, required int pending}) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCol(
            title: "Total Riwayat",
            value: total.toString(),
            color: Colors.blue.shade700,
            icon: Icons.list_alt,
          ),
          Container(height: 36, width: 1, color: Colors.grey.shade200),
          _statCol(
            title: "Tersinkron",
            value: synced.toString(),
            color: Colors.green.shade700,
            icon: Icons.cloud_done_outlined,
          ),
          Container(height: 36, width: 1, color: Colors.grey.shade200),
          _statCol(
            title: "Tertunda",
            value: pending.toString(),
            color: Colors.orange.shade700,
            icon: Icons.cloud_upload_outlined,
          ),
        ],
      ),
    );
  }

  Widget _statCol({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? "Tidak Ada Hasil Pencarian" : "Belum Ada Riwayat Lokasi",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? "Cobalah mencari dengan format koordinat atau kata kunci yang berbeda."
                    : "Aktifkan pelacakan GPS di tab peta atau simpan lokasi secara manual untuk memulai.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
