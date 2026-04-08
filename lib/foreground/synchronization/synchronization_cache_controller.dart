import 'package:circular_buffer/circular_buffer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data/provider/nightscout_repository_provider.dart';
import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/glucose.dart';
import '../../core/domain/model/temporary_target.dart';

part 'synchronization_cache_controller.g.dart';

class SynchronizationCache {
  CircularBuffer<Glucose> glucoseReadingsCache;
  DeviceStatus? deviceStatusCache;
  TemporaryTarget? targetCache;

  SynchronizationCache({this.deviceStatusCache, this.targetCache})
    : glucoseReadingsCache = CircularBuffer<Glucose>(10);

  void cacheGlucose(Glucose glucose) {
    final lastReading = glucoseReadingsCache.firstOrNull;
    if (lastReading != null &&
        lastReading.date.isAtSameMomentAs(glucose.date)) {
      return;
    }
    glucoseReadingsCache.addHead(glucose);
  }

  void cacheTarget(TemporaryTarget target) {
    targetCache = target;
  }

  void cacheDeviceStatus(DeviceStatus deviceStatus) {
    deviceStatusCache = deviceStatus;
  }

  void invalidateTargetCache() {
    targetCache = null;
  }
}

@Riverpod(keepAlive: true)
SynchronizationCacheController synchronizationCacheController(Ref ref) {
  return SynchronizationCacheController();
}

class SynchronizationCacheController {
  final SynchronizationCache cache = SynchronizationCache(
    deviceStatusCache: null,
  );

  Future<void> init(ProviderContainer container) async {
    final glucoseReadings = await container.read(
      glucoseWithLimitProvider(10).future,
    );

    glucoseReadings.reversed.forEach(cacheGlucose);
  }

  void cacheGlucose(Glucose glucose) {
    cache.cacheGlucose(glucose);
  }

  void cacheDeviceStatus(DeviceStatus deviceStatus) {
    cache.cacheDeviceStatus(deviceStatus);
  }

  void cacheTarget(TemporaryTarget target) {
    cache.cacheTarget(target);
  }

  SynchronizationCache getCache() {
    return cache;
  }
}
