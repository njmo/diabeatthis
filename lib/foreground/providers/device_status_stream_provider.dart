/*
  Provides a stream of DeviceStatus updates from Nightscout.
  Initially yields the last known DeviceStatus, then periodically checks for updates.
  If a new DeviceStatus is found (based on the date), it yields the new status.
  The checking frequency adjusts based on whether a new status was found recently.
*/

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/device_status.dart';

part 'device_status_stream_provider.g.dart';

@Riverpod(keepAlive: false)
Stream<DeviceStatus> deviceStatusStream(Ref ref) async* {
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
  });

  final repository = await ref.read(
    deviceStatusSourceRepositoryProvider.future,
  );
  var last = await repository.fetchLastDeviceStatus();
  yield last;

  while (!disposed) {
    try {
      final current = await repository.fetchLastDeviceStatus();
      // TODO: temporary fix for duplicates
      final timeDifference = current.date.difference(last.date);
      if (timeDifference > Duration(minutes: 1)) {
        last = current;
        yield current;
        continue;
      }
    } catch (_) {
      await Future.delayed(const Duration(seconds: 30));
    }

    await Future.delayed(const Duration(seconds: 30));
  }
}
