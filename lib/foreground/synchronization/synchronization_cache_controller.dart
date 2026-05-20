import 'package:circular_buffer/circular_buffer.dart';
import 'package:clock/clock.dart';
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
  static const _initialLoad = 'Initial';
  static const _requestedLoad = 'Requested';

  final SynchronizationCache cache = SynchronizationCache(
    deviceStatusCache: null,
  );

  Future<void>? _glucoseReadingsLoad;
  Future<void>? _deviceStatusLoad;

  Future<void> init(ProviderContainer container) async {
    await Future.wait([
      _loadGlucoseReadings(container, reason: _initialLoad),
      _loadDeviceStatus(container, reason: _initialLoad),
      _loadTemporaryTarget(container, reason: _initialLoad),
    ]);
  }

  Future<bool> ensureGlucoseReadingsReady(
    ProviderContainer container, {
    int minCount = 10,
  }) async {
    if (cache.glucoseReadingsCache.length >= minCount) return true;

    await _loadGlucoseReadings(container, reason: _requestedLoad);

    return cache.glucoseReadingsCache.isNotEmpty;
  }

  Future<bool> ensureDeviceStatusReady(ProviderContainer container) async {
    if (cache.deviceStatusCache != null) return true;

    await _loadDeviceStatus(container, reason: _requestedLoad);

    return cache.deviceStatusCache != null;
  }

  Future<bool> ensureTemporaryTargetReady(ProviderContainer container) async {
    if (cache.targetCache != null) return true;

    await _loadTemporaryTarget(container, reason: _requestedLoad);

    return cache.targetCache != null;
  }

  Future<void> _loadGlucoseReadings(
    ProviderContainer container, {
    required String reason,
  }) {
    final currentLoad = _glucoseReadingsLoad;
    if (currentLoad != null) return currentLoad;

    final load = _loadGlucoseReadingsOnce(container, reason: reason)
        .whenComplete(() {
          _glucoseReadingsLoad = null;
        });
    _glucoseReadingsLoad = load;

    return load;
  }

  Future<void> _loadGlucoseReadingsOnce(
    ProviderContainer container, {
    required String reason,
  }) async {
    try {
      final repository = await container.read(
        glucoseHistoryRepositoryProvider.future,
      );
      final glucoseReadings = await repository.fetchRecentGlucose(10);
      final latestReadings = [...glucoseReadings, ...cache.glucoseReadingsCache]
        ..sort((a, b) => b.date.compareTo(a.date));
      final limitedReadings = latestReadings.take(10).toList();

      logI(
        _describeGlucoseReadings(
          _cacheFetchLabel(reason, 'glucose'),
          limitedReadings,
        ),
      );
      cache.replaceGlucoseReadings(limitedReadings.reversed);
      logI(
        _describeGlucoseReadings(
          _cacheStoredLabel(reason, 'glucose'),
          cache.glucoseReadingsCache.toList(),
        ),
      );
    } catch (e, st) {
      logW('Synchronization cache load failed: $e\n$st');
    }
  }

  Future<void> _loadDeviceStatus(
    ProviderContainer container, {
    required String reason,
  }) {
    final currentLoad = _deviceStatusLoad;
    if (currentLoad != null) return currentLoad;

    final load = _loadDeviceStatusOnce(container, reason: reason).whenComplete(
      () {
        _deviceStatusLoad = null;
      },
    );
    _deviceStatusLoad = load;

    return load;
  }

  Future<void> _loadDeviceStatusOnce(
    ProviderContainer container, {
    required String reason,
  }) async {
    try {
      final repository = await container.read(
        deviceStatusHistoryRepositoryProvider.future,
      );
      final deviceStatus = await repository.fetchLastDeviceStatusBefore(
        clock.now(),
      );

      logI(
        _describeDeviceStatus(
          _cacheFetchLabel(reason, 'device status'),
          deviceStatus,
        ),
      );
      if (deviceStatus == null) return;

      cache.cacheDeviceStatus(deviceStatus);
      logI(
        _describeDeviceStatus(
          _cacheStoredLabel(reason, 'device status'),
          cache.deviceStatusCache,
        ),
      );
    } catch (e, st) {
      logW('Synchronization device status cache load failed: $e\n$st');
    }
  }

  Future<void> _loadTemporaryTarget(
    ProviderContainer container, {
    required String reason,
  }) async {
    try {
      final repository = await container.read(
        treatmentsHistoryRepositoryProvider.future,
      );
      final lastTarget = await repository.fetchLastTemporaryTarget();
      final activeTarget = lastTarget?.isActive() == true ? lastTarget : null;

      logI(
        _describeTemporaryTarget(
          _cacheFetchLabel(reason, 'temporary target'),
          activeTarget,
        ),
      );
      if (activeTarget == null) return;

      cache.cacheTarget(activeTarget);
      logI(
        _describeTemporaryTarget(
          _cacheStoredLabel(reason, 'temporary target'),
          cache.targetCache,
        ),
      );
    } catch (e, st) {
      logW('Synchronization temporary target cache load failed: $e\n$st');
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

  String _cacheFetchLabel(String reason, String cacheName) {
    return '$reason $cacheName cache fetch';
  }

  String _cacheStoredLabel(String reason, String cacheName) {
    return '$reason $cacheName cache stored';
  }

  String _describeGlucoseReadings(String label, Iterable<Glucose> readings) {
    final list = readings.toList()..sort((a, b) => a.date.compareTo(b.date));
    final first = list.isEmpty ? null : list.first;
    final last = list.isEmpty ? null : list.last;

    return '$label count=${list.length}'
        '${first == null ? '' : ' from=${first.date.toIso8601String()}'}'
        '${last == null ? '' : ' to=${last.date.toIso8601String()}'}';
  }

  String _describeDeviceStatus(String label, DeviceStatus? deviceStatus) {
    return '$label'
        '${deviceStatus == null ? ' empty' : ' at=${deviceStatus.date.toIso8601String()} bg=${deviceStatus.bg} tick=${deviceStatus.tick}'}';
  }

  String _describeTemporaryTarget(String label, TemporaryTarget? target) {
    return '$label'
        '${target == null ? ' empty' : ' at=${target.createdAt.toIso8601String()} duration=${target.duration}'}';
  }
}
