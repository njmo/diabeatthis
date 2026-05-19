import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataReceiverActivationController', () {
    test('enables configured push receivers', () async {
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final controller = DataReceiverActivationController(
        xdripReceiverController: xdrip,
        aapsReceiverController: aaps,
      );

      await controller.enableConfiguredReceivers(
        _config(
          bgSource: BgSource.xdrip,
          pumpStatusSource: PumpStatusSource.aaps,
        ),
      );

      expect(xdrip.calls, [DataReceiverCall.enabled]);
      expect(aaps.calls, [DataReceiverCall.enabled]);
    });

    test('enables AAPS receiver for AAPS glucose source', () async {
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final controller = DataReceiverActivationController(
        xdripReceiverController: xdrip,
        aapsReceiverController: aaps,
      );

      await controller.enableConfiguredReceivers(
        _config(bgSource: BgSource.aaps),
      );

      expect(xdrip.calls, isEmpty);
      expect(aaps.calls, [DataReceiverCall.enabled]);
    });

    test('does not touch inactive receivers during initial enable', () async {
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final controller = DataReceiverActivationController(
        xdripReceiverController: xdrip,
        aapsReceiverController: aaps,
      );

      await controller.enableConfiguredReceivers(_config());

      expect(xdrip.calls, isEmpty);
      expect(aaps.calls, isEmpty);
    });

    test('enables and disables receivers after config change', () async {
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final controller = DataReceiverActivationController(
        xdripReceiverController: xdrip,
        aapsReceiverController: aaps,
      );

      await controller.applyConfigChange(
        previous: _config(
          bgSource: BgSource.xdrip,
          pumpStatusSource: PumpStatusSource.cloud,
        ),
        next: _config(
          bgSource: BgSource.cloud,
          pumpStatusSource: PumpStatusSource.aaps,
        ),
      );

      expect(xdrip.calls, [DataReceiverCall.disabled]);
      expect(aaps.calls, [DataReceiverCall.enabled]);
    });

    test('skips unchanged receiver state', () async {
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final controller = DataReceiverActivationController(
        xdripReceiverController: xdrip,
        aapsReceiverController: aaps,
      );

      await controller.applyConfigChange(
        previous: _config(bgSource: BgSource.xdrip),
        next: _config(
          bgSource: BgSource.xdrip,
          historySource: HistorySource.local,
        ),
      );

      expect(xdrip.calls, isEmpty);
      expect(aaps.calls, isEmpty);
    });

    test(
      'keeps AAPS receiver enabled when switching between AAPS sources',
      () async {
        final xdrip = RecordingDataReceiverController();
        final aaps = RecordingDataReceiverController();
        final controller = DataReceiverActivationController(
          xdripReceiverController: xdrip,
          aapsReceiverController: aaps,
        );

        await controller.applyConfigChange(
          previous: _config(bgSource: BgSource.aaps),
          next: _config(pumpStatusSource: PumpStatusSource.aaps),
        );

        expect(xdrip.calls, isEmpty);
        expect(aaps.calls, isEmpty);
      },
    );
  });
}

DataSourceConfig _config({
  BgSource bgSource = BgSource.cloud,
  TreatmentsSource treatmentsSource = TreatmentsSource.cloud,
  PumpStatusSource pumpStatusSource = PumpStatusSource.cloud,
  HistorySource historySource = HistorySource.cloud,
}) {
  return DataSourceConfig(
    bgSource: bgSource,
    treatmentsSource: treatmentsSource,
    pumpStatusSource: pumpStatusSource,
    historySource: historySource,
    mirrorToLocal: false,
  );
}

enum DataReceiverCall { enabled, disabled }

class RecordingDataReceiverController implements DataReceiverController {
  final List<DataReceiverCall> calls = [];

  @override
  Future<void> setEnabled() async {
    calls.add(DataReceiverCall.enabled);
  }

  @override
  Future<void> setDisabled() async {
    calls.add(DataReceiverCall.disabled);
  }
}
