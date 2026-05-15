import 'package:foreground_power_lock/foreground_power_lock.dart';

import '../../core/logger/logger.dart';

class CollectTickWakeLock with Logging {
  const CollectTickWakeLock();

  static const _timeout = Duration(seconds: 5);

  Future<void> acquire() async {
    try {
      await ForegroundPowerLock.acquireCollectTick(timeout: _timeout);
    } catch (e, st) {
      logW('Failed to acquire native collect tick wake lock: $e\n$st');
    }
  }
}
