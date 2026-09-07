import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final networkConnectionProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  final connectivity = Connectivity();
  final controller = StreamController<List<ConnectivityResult>>();
  var revision = 0;

  Future<void> refresh() async {
    final currentRevision = ++revision;
    try {
      final connections = await connectivity.checkConnectivity();
      if (!controller.isClosed && currentRevision == revision) {
        controller.add(connections);
      }
    } catch (error, stackTrace) {
      if (!controller.isClosed && currentRevision == revision) {
        controller.addError(error, stackTrace);
      }
    }
  }

  final subscription = connectivity.onConnectivityChanged.listen((connections) {
    revision++;
    controller.add(connections);
  }, onError: controller.addError);
  final lifecycle = AppLifecycleListener(onResume: refresh);
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  unawaited(refresh());
  return controller.stream;
});
