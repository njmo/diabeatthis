import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../core/domain/model/device_status.dart';

part 'device_status_provider.g.dart';

/*
  Provides a stream of DeviceStatus updates from Nightscout.
  Initially yields the last known DeviceStatus, then periodically checks for updates.
  If a new DeviceStatus is found (based on the date), it yields the new status.
  The checking frequency adjusts based on whether a new status was found recently.
*/

@Riverpod(keepAlive: true)
class DeviceStatusUiNotifier extends _$DeviceStatusUiNotifier {
  @override
  DeviceStatus? build() {
    return null;
  }

  void update(DeviceStatus value) {
    state = value;
  }
}

@Riverpod(keepAlive: false)
Stream<DeviceStatus> deviceStatusStream(Ref ref) async* {
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
  });

  var last = await ref.read(deviceStatusProvider.future);
  yield last;

  var frequent = false;
  while (!disposed) {
    if (!frequent) {
      const longWaitDifference = Duration(minutes: 4, seconds: 50);
      final lastReadDifference = clock.now().difference(last.date);
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
      if (timeDifference > Duration(minutes: 1)) {
        last = current;
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
