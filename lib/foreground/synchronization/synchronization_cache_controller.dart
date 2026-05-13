import 'package:circular_buffer/circular_buffer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data_sources/providers/source_repository_providers.dart';
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

  void invalidateGlucoseReadings() {
    glucoseReadingsCache.clear();
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

  Future<void>? _glucoseReadingsLoad;

  Future<void> init(ProviderContainer container) async {
    await ensureGlucoseReadingsReady(container);
  }

  Future<void> ensureGlucoseReadingsReady(
    ProviderContainer container, {
    int minCount = 10,
  }) async {
    if (cache.glucoseReadingsCache.length >= minCount) {
      return;
    }

    final currentLoad = _glucoseReadingsLoad;
    if (currentLoad != null) {
      await currentLoad;
      return;
    }

    final load = _loadGlucoseReadings(container).whenComplete(() {
      _glucoseReadingsLoad = null;
    });
    _glucoseReadingsLoad = load;
    await load;
  }

  Future<void> _loadGlucoseReadings(ProviderContainer container) async {
    final repository = await container.read(
      glucoseSourceRepositoryProvider.future,
    );
    final glucoseReadings = await repository.fetchLastGlucoseWithLimit(10);

    glucoseReadings.reversed.forEach(cacheGlucose);
  }

  void cacheGlucose(Glucose glucose) {
    cache.cacheGlucose(glucose);
  }

  void invalidateGlucoseReadings() {
    cache.invalidateGlucoseReadings();
  }

  void cacheDeviceStatus(DeviceStatus deviceStatus) {
    cache.cacheDeviceStatus(deviceStatus);
  }

  void cacheTarget(TemporaryTarget target) {
    cache.cacheTarget(target);
  }

  void invalidateTargetCache() {
    cache.invalidateTargetCache();
  }

  SynchronizationCache getCache() {
    return cache;
  }
}
