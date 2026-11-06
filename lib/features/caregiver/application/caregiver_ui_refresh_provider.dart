import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../common/app_mode/application_device_mode.dart';
import '../../../common/refresh/visible_app_refresh_controller.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_fingerprint.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../data/caregiver_nightscout_snapshot.dart';
import '../data/caregiver_refresh_state.dart';
import 'refresh_caregiver_nightscout_use_case.dart';

final caregiverUiRefreshProvider =
    Provider.autoDispose<
      VisibleAppRefreshController<CaregiverNightscoutSnapshot>?
    >((ref) {
      final modeState = ref.watch(applicationDeviceModeProvider);
      final doneState = ref.watch(initialConfigurationDoneProvider);
      final urlState = ref.watch(nightscoutUrlProvider);
      final tokenState = ref.watch(nightscoutTokenProvider);
      if (modeState.isLoading ||
          modeState.hasError ||
          doneState.isLoading ||
          doneState.hasError ||
          urlState.isLoading ||
          urlState.hasError ||
          tokenState.isLoading ||
          tokenState.hasError) {
        return null;
      }
      final mode = modeState.asData?.value;
      final done = doneState.asData?.value == true;
      final url = urlState.asData?.value;
      final token = tokenState.asData?.value;
      if (mode != ApplicationDeviceMode.caregiver ||
          !done ||
          url == null ||
          url.isEmpty ||
          token == null) {
        return null;
      }
      final status = ref.read(caregiverRefreshStateProvider.notifier);
      final refresh = ref.read(refreshCaregiverNightscoutProvider);
      final runner = VisibleAppRefreshController<CaregiverNightscoutSnapshot>(
        fetch: refresh.call,
        onStarted: status.started,
        onError: (_) => status.finished(failed: true),
        onData: (snapshot) =>
            status.finished(snapshot: snapshot, failed: snapshot.hasFailures),
      );
      ref.onDispose(runner.dispose);
      ref.listen(appLifecycleProvider, (_, lifecycle) {
        if (lifecycle == AppLifecycleState.resumed) {
          runner.start();
        } else {
          runner.stop();
        }
      });
      scheduleMicrotask(() {
        if (!ref.mounted) return;
        status.beginConnection(nightscoutConnectionFingerprint(url, token));
        if (ref.read(appLifecycleProvider) == AppLifecycleState.resumed) {
          runner.start();
        }
      });
      return runner;
    });
