import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../feature/tracking/domain/repositories/tracking_repository.dart';

class SyncService {
  final TrackingRepository repository;

  late IO.Socket socket;

  bool _isSyncing = false;
  bool _syncAgain = false;
  StreamSubscription? _dbSubscription;
  StreamSubscription? _connectivitySubscription;

  SyncService(this.repository) {
    _initSocket();
    _listenToConnectionChanges();
    _listenToDatabaseChanges();
  }

  void _initSocket() {
    socket = IO.io(
        'http://172.20.10.13:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print(' Flutter: Socket Connected');

      // Ketika berhasil connect langsung kirim data offline
      triggerSyncWithRetry();
    });

    socket.onDisconnect((_) {
      print(' Flutter: Socket Disconnected');
    });

    socket.onConnectError((error) {
      print(' Socket Connect Error: $error');
    });

    socket.onError((error) {
      print('Socket Error: $error');
    });
  }

  void _listenToConnectionChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final connected =
            results.any((e) => e != ConnectivityResult.none);

        if (connected) {
          print(' Internet tersedia. Menghubungkan socket dan memulai sinkronisasi...');
          if (!socket.connected) {
            socket.connect();
          }
          triggerSyncWithRetry();
        } else {
          print(' Tidak ada koneksi internet.');
        }
      },
    );
  }

  void _listenToDatabaseChanges() {
    _dbSubscription = repository.watchLocations().listen((_) {
      print(' Database lokal berubah. Memulai sinkronisasi otomatis...');
      triggerSyncWithRetry();
    });
  }

  Future<void> triggerSyncWithRetry() async {
    if (!socket.connected) {
      print(' Socket tidak terhubung. Menunda sinkronisasi...');
      return;
    }

    if (_isSyncing) {
      _syncAgain = true;
      return;
    }

    _isSyncing = true;
    _syncAgain = false;

    try {
      int attempt = 0;
      const maxAttempts = 5;

      while (attempt < maxAttempts) {
        if (!socket.connected) {
          print(" Socket terputus saat sinkronisasi. Menunda...");
          break;
        }

        try {
          final unsyncedLocations = await repository.getUnsyncedLocations();

          if (unsyncedLocations.isEmpty) {
            print(' Tidak ada data yang perlu disinkronkan.');
            break;
          }

          print(' Menemukan ${unsyncedLocations.length} data yang belum sinkron.');

          for (final loc in unsyncedLocations) {
            // Cek status koneksi socket sebelum mengirim setiap data
            if (!socket.connected) {
              throw Exception("Socket terputus saat mengirim data");
            }

            final success = await _sendToServer(loc);

            if (success) {
              await repository.markAsSynced(loc.id!);
              print(" Data ${loc.id} berhasil disinkronkan");
            } else {
              throw Exception("Gagal mengirim data ke server");
            }
          }

          // Reset attempts jika berhasil menyelesaikan sinkronisasi batch
          attempt = 0;

          if (!_syncAgain) {
            break;
          }
          _syncAgain = false;
        } catch (e) {
          attempt++;

          print(" Sinkronisasi gagal ($attempt/$maxAttempts)");
          print(e);

          if (attempt >= maxAttempts) {
            break;
          }

          final delay = pow(2, attempt).toInt();

          print(" Retry dalam $delay detik");

          await Future.delayed(Duration(seconds: delay));
        }
      }
    } finally {
      _isSyncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        triggerSyncWithRetry();
      }
    }
  }

  Future<bool> _sendToServer(dynamic loc) async {
    if (!socket.connected) {
      print("Socket belum terhubung");

      return false;
    }

    final completer = Completer<bool>();

    socket.emitWithAck(
      'track_location',
      {
        'id_lokal': loc.id,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'timestamp': loc.timestamp.toIso8601String(),
      },
      ack: (response) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {

          if (!completer.isCompleted) {
            completer.complete(false);
          }

          return false;
        },
      );
    } catch (e) {
      print(" Error saat mengirim data: $e");
      return false;
    }
  }

  /// 6. Dispose
  void dispose() {
    _dbSubscription?.cancel();
    _connectivitySubscription?.cancel();
    socket.dispose();
  }
}