import 'dart:convert';

import 'package:diabeatthis/app/event/app/app_event_router.dart';
import 'package:diabeatthis/common/events/data/app_event_data.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_controller.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';

class ForegroundAppEventRouterStub extends AppEventRouter {
  final messages = <Map<String, dynamic>>[];
  ExternalEventHandler? handler;

  @override
  void send(AppEventData payload) {
    final wire =
        jsonDecode(jsonEncode(payload.toExternalAppEventJson()))
            as Map<String, dynamic>;
    messages.add(wire);
    handler!.handle(wire);
  }
}

class NoopDataReceiverController implements DataReceiverController {
  @override
  Future<void> setEnabled() async {}

  @override
  Future<void> setDisabled() async {}
}

class EmptyGlucoseHistoryRepository implements GlucoseHistoryRepository {
  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async => [];

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) async => [];
}

class EmptyTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async => [];

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}

class EmptyDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async => [];

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async =>
      null;
}
