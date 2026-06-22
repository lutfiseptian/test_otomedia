import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_otomedia/feature/tracking/presentation/pages/home_page.dart';

import 'core/network/tracking_service.dart';
import 'feature/tracking/domain/repositories/tracking_repository_impl.dart';
import 'feature/tracking/presentation/bloc/tracking_bloc.dart';
import 'feature/tracking/presentation/bloc/tracking_event.dart';
import 'feature/tracking/presentation/pages/login_page.dart';

class MyApp extends StatelessWidget {
  final TrackingRepositoryImpl repository;

  MyApp({
    super.key,
    required this.repository,
  });

  final TrackingService trackingService = TrackingService();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrackingBloc(
        repository,
        trackingService,
      )..add(LoadTrackingHistory()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Realtime Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
        ),
        home: LoginPage(repository: repository),
      ),
    );
  }
}