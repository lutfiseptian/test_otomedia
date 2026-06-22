import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tracking_service.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository repository;
  final TrackingService trackingService;
  StreamSubscription? _locationSubscription;
  bool _isTrackingActive = false;

  TrackingBloc(
    this.repository,
    this.trackingService,
  ) : super(TrackingInitial()) {
    on<LoadTrackingHistory>(_loadHistory);
    on<AddNewLocation>(_saveLocation);
    on<StartTracking>(_startTracking);
    on<StopTracking>(_stopTracking);
    _locationSubscription = repository.watchLocations().listen((_) {
      add(LoadTrackingHistory());
    });
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }

  /// Load semua history dari Isar
  Future<void> _loadHistory(
    LoadTrackingHistory event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());

    try {
      final history = await repository.getLocalLocationHistory();
      emit(
        TrackingLoaded(history, isTracking: _isTrackingActive),
      );
    } catch (e) {
      emit(
        TrackingError(
          e.toString(),
        ),
      );
    }
  }

  /// Simpan lokasi baru ke Isar
  Future<void> _saveLocation(
    AddNewLocation event,
    Emitter<TrackingState> emit,
  ) async {
    await repository.saveLocation(
      event.location,
    );
    add(
      LoadTrackingHistory(),
    );
  }

  /// Mulai tracking GPS
  Future<void> _startTracking(
    StartTracking event,
    Emitter<TrackingState> emit,
  ) async {
    try {
      _isTrackingActive = true;
      if (state is TrackingLoaded) {
        final currentHistory = (state as TrackingLoaded).history;
        emit(TrackingLoaded(currentHistory, isTracking: _isTrackingActive));
      }
      
      await trackingService.start(
        onLocation: (position) {
          add(
            AddNewLocation(
              LocationEntity(
                latitude: position.latitude,
                longitude: position.longitude,
                timestamp: DateTime.now(),
                isSynced: false,
              ),
            ),
          );
        },
      );
    } catch (e) {
      _isTrackingActive = false;
      emit(TrackingError("Gagal memulai tracking: ${e.toString()}"));
    }
  }

  Future<void> _stopTracking(
    StopTracking event,
    Emitter<TrackingState> emit,
  ) async {
    _isTrackingActive = false;
    trackingService.stop();
    if (state is TrackingLoaded) {
      final currentHistory = (state as TrackingLoaded).history;
      emit(TrackingLoaded(currentHistory, isTracking: _isTrackingActive));
    } else {
      add(LoadTrackingHistory());
    }
  }
}