import 'package:circular_buffer/circular_buffer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/glucose.dart';
import '../../core/domain/model/temporary_target.dart';
import '../../core/logger/logger.dart';

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

  void replaceGlucoseReadings(Iterable<Glucose> readings) {
    glucoseReadingsCache = CircularBuffer<Glucose>(10);
    readings.forEach(cacheGlucose);
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

  void invalidateDeviceStatusCache() {
    deviceStatusCache = null;
  }
}

@Riverpod(keepAlive: true)
SynchronizationCacheController synchronizationCacheController(Ref ref) {
  return SynchronizationCacheController();
}

class SynchronizationCacheController with Logging {
  final SynchronizationCache cache = SynchronizationCache(
    deviceStatusCache: null,
  );

  Future<void>? _glucoseReadingsLoad;

  Future<void> init(ProviderContainer container) async {
    await _loadGlucoseReadings(
      container,
      fetchLabel: 'Initial glucose cache fetch',
      storedLabel: 'Initial glucose cache stored',
    );
  }

  Future<bool> ensureGlucoseReadingsReady(
    ProviderContainer container, {
    int minCount = 10,
  }) async {
    if (cache.glucoseReadingsCache.length >= minCount) return true;

    await _loadGlucoseReadings(
      container,
      fetchLabel: 'Requested glucose cache fetch',
      storedLabel: 'Requested glucose cache stored',
    );

    return cache.glucoseReadingsCache.isNotEmpty;
  }

  Future<void> _loadGlucoseReadings(
    ProviderContainer container, {
    required String fetchLabel,
    required String storedLabel,
  }) {
    final currentLoad = _glucoseReadingsLoad;
    if (currentLoad != null) return currentLoad;

    final load =
        _loadGlucoseReadingsOnce(
          container,
          fetchLabel: fetchLabel,
          storedLabel: storedLabel,
        ).whenComplete(() {
          _glucoseReadingsLoad = null;
        });
    _glucoseReadingsLoad = load;

    return load;
  }

  Future<void> _loadGlucoseReadingsOnce(
    ProviderContainer container, {
    required String fetchLabel,
    required String storedLabel,
  }) async {
    try {
      final repository = await container.read(
        glucoseHistoryRepositoryProvider.future,
      );
      final glucoseReadings = await repository.fetchRecentGlucose(10);
      final latestReadings = [...glucoseReadings]
        ..sort((a, b) => b.date.compareTo(a.date));
      final limitedReadings = latestReadings.take(10).toList();

      logI(_describeGlucoseReadings(fetchLabel, limitedReadings));
      cache.replaceGlucoseReadings(limitedReadings.reversed);
      logI(
        _describeGlucoseReadings(
          storedLabel,
          cache.glucoseReadingsCache.toList(),
        ),
      );
    } catch (e, st) {
      logW('Synchronization cache load failed: $e\n$st');
    }
  }

  void cacheGlucose(Glucose glucose) {
    cache.cacheGlucose(glucose);
  }

  void replaceGlucoseReadings(Iterable<Glucose> readings) {
    cache.replaceGlucoseReadings(readings);
  }

  void cacheDeviceStatus(DeviceStatus deviceStatus) {
    cache.cacheDeviceStatus(deviceStatus);
  }

  void cacheTarget(TemporaryTarget target) {
    cache.cacheTarget(target);
  }

  void invalidateLiveData() {
    cache.replaceGlucoseReadings(const []);
    cache.invalidateDeviceStatusCache();
    cache.invalidateTargetCache();
  }

  SynchronizationCache getCache() {
    return cache;
  }

  String _describeGlucoseReadings(String label, Iterable<Glucose> readings) {
    final list = readings.toList()..sort((a, b) => a.date.compareTo(b.date));
    final values = list
        .map((reading) => '${reading.sgv}@${reading.date.toIso8601String()}')
        .join(', ');

    return '$label count=${list.length} values=[$values]';
  }
}
