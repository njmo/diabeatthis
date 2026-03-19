import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/domain/model/device_status.dart';

part 'device_status_value_provider.g.dart';

@Riverpod(keepAlive: true)
class DeviceStatusValueNotifier extends _$DeviceStatusValueNotifier {
  Timer? _expiryTimer;

  @override
  DeviceStatus? build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
    });

    return null;
  }

  void update(DeviceStatus value) {
    final now = DateTime.now();
    final readingAge = now.difference(value.date);

    if (readingAge.inMinutes >= 6) {
      state = null;
      return;
    }

    state = value;

    _expiryTimer?.cancel();

    final remaining = const Duration(minutes: 6) - readingAge;

    _expiryTimer = Timer(remaining, () {
      state = null;
    });
  }
}