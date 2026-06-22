import '../../domain/entities/location_entity.dart';

abstract class TrackingState {}

class TrackingInitial extends TrackingState {}

class TrackingLoading extends TrackingState {}

class TrackingLoaded extends TrackingState {
  final List<LocationEntity> history;
  final bool isTracking;

  TrackingLoaded(this.history, {this.isTracking = false});
}

class TrackingError extends TrackingState {
  final String message;

  TrackingError(this.message);
}