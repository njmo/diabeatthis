import 'dart:async';

import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/caregiver/application/caregiver_ui_refresh_provider.dart';
import 'package:diabeatthis/features/caregiver/application/refresh_caregiver_nightscout_use_case.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingCaregiverRefresh extends RefreshCaregiverNightscoutUseCase {
  PendingCaregiverRefresh(super.ref);
  final requests = <Completer<CaregiverNightscoutSnapshot>>[];
  @override
  Future<CaregiverNightscoutSnapshot> call() {
    final pending = Completer<CaregiverNightscoutSnapshot>();
    requests.add(pending);
    return pending.future;
  }
}

CaregiverNightscoutSnapshot caregiverReading(int value) =>
    CaregiverNightscoutSnapshot(
      glucose: [
        Glucose(
          externalId: '$value',
          source: GlucoseSource.cloud,
          date: DateTime.now(),
          sgv: value,
          direction: 'Flat',
        ),
      ],
      targetFetched: true,
      hasFailures: false,
    );
Future<void> settleCaregiver(ProviderContainer container) async {
  await container.pump();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

void main() {
  test(
    'refresh follows visibility, preserves failures, clears empty CGM and isolates new sources',
    () async {
      late PendingCaregiverRefresh refresh;
      var url = Future<String>.value('https://child-a.test');
      final container = ProviderContainer(
        overrides: [
          applicationDeviceModeProvider.overrideWith(
            (ref) async => ApplicationDeviceMode.caregiver,
          ),
          initialConfigurationDoneProvider.overrideWith((ref) async => true),
          nightscoutUrlProvider.overrideWith((ref) => url),
          nightscoutTokenProvider.overrideWith((ref) async => 'read-token'),
          refreshCaregiverNightscoutProvider.overrideWith(
            (ref) => refresh = PendingCaregiverRefresh(ref),
          ),
          appForegroundBridgeProvider.overrideWith(
            (ref) => throw StateError('UI refresh cannot use foreground'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        caregiverUiRefreshProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await settleCaregiver(container);
      expect(refresh.requests, hasLength(1));
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.paused);
      refresh.requests[0].complete(caregiverReading(100));
      await settleCaregiver(container);
      expect(container.read(caregiverVisibleStateProvider).snapshot, isNull);
      container
          .read(appLifecycleProvider.notifier)
          .setState(AppLifecycleState.resumed);
      await settleCaregiver(container);
      expect(refresh.requests, hasLength(2));
      refresh.requests[1].complete(caregiverReading(123));
      await settleCaregiver(container);
      expect(
        container
            .read(caregiverVisibleStateProvider)
            .snapshot!
            .glucose!
            .single
            .sgv,
        123,
      );
      final failed = container.read(caregiverUiRefreshProvider)!.refreshNow();
      refresh.requests[2].completeError(StateError('Offline'));
      await failed;
      expect(
        container
            .read(caregiverVisibleStateProvider)
            .snapshot!
            .glucose!
            .single
            .sgv,
        123,
      );
      expect(container.read(caregiverVisibleStateProvider).failed, isTrue);
      final empty = container.read(caregiverUiRefreshProvider)!.refreshNow();
      refresh.requests[3].complete(
        const CaregiverNightscoutSnapshot(
          glucose: [],
          targetFetched: true,
          hasFailures: false,
        ),
      );
      await empty;
      expect(
        container.read(caregiverVisibleStateProvider).snapshot!.glucose,
        isEmpty,
      );
      final old = container.read(caregiverUiRefreshProvider)!.refreshNow();
      final newUrl = Completer<String>();
      url = newUrl.future;
      container.invalidate(nightscoutUrlProvider);
      await settleCaregiver(container);
      expect(container.read(caregiverVisibleStateProvider).snapshot, isNull);
      refresh.requests[4].complete(caregiverReading(999));
      await old;
      expect(container.read(caregiverVisibleStateProvider).snapshot, isNull);
      newUrl.complete('https://child-b.test');
      await settleCaregiver(container);
      expect(refresh.requests, hasLength(6));
      refresh.requests[5].complete(caregiverReading(222));
      await settleCaregiver(container);
      expect(
        container
            .read(caregiverVisibleStateProvider)
            .snapshot!
            .glucose!
            .single
            .sgv,
        222,
      );
    },
  );
}
