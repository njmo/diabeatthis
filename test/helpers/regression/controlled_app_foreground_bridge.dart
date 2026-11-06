import 'dart:async';

import 'package:diabeatthis/app/lifecycle/app_foreground_bridge.dart';
import 'package:diabeatthis/foreground/service/foreground_service_controller.dart';

/// Controls only the service boundary; startup acknowledgement remains real.
class ControlledAppForegroundBridge implements AppForegroundBridge {
  bool running = false;
  Object? startError;
  final calls = <String>[];
  final started = Completer<void>();

  @override
  ForegroundServiceController get controller =>
      throw StateError('Unexpected direct controller access');

  @override
  Future<bool> isServiceRunning() async {
    calls.add('isRunning');
    return running;
  }

  @override
  Future<void> startMonitoring() async {
    calls.add('start');
    if (!started.isCompleted) started.complete();
    if (startError case final error?) throw error;
    running = true;
  }

  @override
  Future<void> init() async => throw StateError('Unexpected bridge init');

  @override
  void attach(void Function(Object data) onData) =>
      throw StateError('Unexpected callback attachment');

  @override
  void detach(void Function(Object data) onData) =>
      throw StateError('Unexpected callback detachment');

  @override
  void reInitCommunicationPort() =>
      throw StateError('Unexpected communication port initialization');

  @override
  Future<void> restartService() async {
    calls.add('restart');
    if (!started.isCompleted) started.complete();
    if (startError case final error?) throw error;
    running = true;
  }
}
