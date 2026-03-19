import 'dart:async';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../core/domain/model/device_status.dart';

part 'device_status_provider.g.dart';

/*
  Provides a stream of DeviceStatus updates from Nightscout.
  Initially yields the last known DeviceStatus, then periodically checks for updates.
  If a new DeviceStatus is found (based on the date), it yields the new status.
  The checking frequency adjusts based on whether a new status was found recently.
*/

@Riverpod(keepAlive: false)
Stream<DeviceStatus> deviceStatusStream(Ref ref) async* {
  final appLifecycleState = ref.watch(appLifecycleProvider);
  if (appLifecycleState != AppLifecycleState.resumed) {
    return;
  }

  var last = await ref.read(deviceStatusProvider.future);
  yield last;

  var frequent = false;
  while (ref.read(appLifecycleProvider) == AppLifecycleState.resumed) {
    if (!frequent) {
      const longWaitDifference = Duration(minutes: 4, seconds: 50);
      final lastReadDifference = DateTime.now().difference(last.date);
      if (lastReadDifference < longWaitDifference) {
        final timeUntilFrequentReads = longWaitDifference - lastReadDifference;
        await Future.delayed(timeUntilFrequentReads);
      }
      frequent = true;
    }

    try {
      final current = await ref.read(deviceStatusProvider.future);
      // TODO: temporary fix for duplicates
      final timeDifference = current.date.difference(last.date);
      if (timeDifference.inMinutes > 1) {
        last = current;
        ref.invalidate(glucoseWithLimitProvider);
        yield current;
        frequent = false;
        continue;
      }
    } catch (_) {
      await Future.delayed(const Duration(seconds: 5));
    }

    await Future.delayed(const Duration(seconds: 5));
  }
}
