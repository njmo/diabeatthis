import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'device_status_provider.dart';
import 'time_now_provider.dart';

part 'old_reading_provider.g.dart';

@riverpod
bool isReadingOld(Ref ref) {
  final deviceStatus = ref.watch(deviceStatusUiProvider);
  final timeNow = ref.watch(timeNowProvider).value;

  if (deviceStatus == null || timeNow == null) return false;

  final lastUpdate = timeNow.difference(deviceStatus.date);

  return lastUpdate.inMinutes > 10;
}