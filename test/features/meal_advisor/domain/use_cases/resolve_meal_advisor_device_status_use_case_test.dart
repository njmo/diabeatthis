import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/resolve_meal_advisor_device_status_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/resolve_meal_advisor_device_status_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);
  final fresh = testDeviceStatus(
    date: now,
    iob: 0.5,
    cob: 12,
    tick: '+5',
    bg: 140,
  );
  late DeviceStatus? current;
  late ResolverStatusHistory repository;
  late int repositoryLoads;
  late ResolveMealAdvisorDeviceStatusUseCase resolve;

  setUp(() {
    current = null;
    repository = ResolverStatusHistory();
    repositoryLoads = 0;
    resolve = ResolveMealAdvisorDeviceStatusUseCase(
      readCurrentStatus: () => current,
      loadRepository: () async {
        repositoryLoads++;
        return repository;
      },
    );
  });

  test(
    'valid live status avoids history and retains its actual values',
    () async {
      await withClock(Clock.fixed(now), () async {
        current = fresh;
        final result = await resolve();
        expect(result.status, same(fresh));
        expect(result.eligibility, MealAdviceEligibility.available);
        expect(repositoryLoads, 0);
        expect(repository.requests, isEmpty);
      });
    },
  );

  for (final problem in ['missing', 'stale', 'incomplete']) {
    test(
      '$problem live status falls back to fresh configured history',
      () async {
        await withClock(Clock.fixed(now), () async {
          current = switch (problem) {
            'missing' => null,
            'stale' => fresh.copyWith(
              date: now.subtract(const Duration(minutes: 6)),
            ),
            _ => fresh.copyWith(hasIob: false),
          };
          repository.result = fresh;
          final result = await resolve();
          expect(result.status, same(fresh));
          expect(result.eligibility, MealAdviceEligibility.available);
          expect(repositoryLoads, 1);
          expect(repository.requests, [now]);
        });
      },
    );
  }

  for (final sample in [
    (
      name: 'stale',
      status: fresh.copyWith(date: now.subtract(const Duration(minutes: 6))),
      reason: MealAdviceEligibility.staleDeviceStatus,
    ),
    (
      name: 'future',
      status: fresh.copyWith(date: now.add(const Duration(seconds: 1))),
      reason: MealAdviceEligibility.staleDeviceStatus,
    ),
    (
      name: 'missing IOB',
      status: fresh.copyWith(hasIob: false),
      reason: MealAdviceEligibility.incompleteDeviceStatus,
    ),
    (
      name: 'missing COB',
      status: fresh.copyWith(hasCob: false),
      reason: MealAdviceEligibility.incompleteDeviceStatus,
    ),
    (
      name: 'invalid BG',
      status: fresh.copyWith(bg: 0),
      reason: MealAdviceEligibility.invalidDeviceStatus,
    ),
    (
      name: 'invalid IOB',
      status: fresh.copyWith(iob: double.nan),
      reason: MealAdviceEligibility.invalidDeviceStatus,
    ),
    (
      name: 'invalid COB',
      status: fresh.copyWith(cob: -1),
      reason: MealAdviceEligibility.invalidDeviceStatus,
    ),
  ]) {
    test('${sample.name} history cannot supply a usable snapshot', () async {
      await withClock(Clock.fixed(now), () async {
        repository.result = sample.status;
        final result = await resolve();
        expect(result.status, isNull);
        expect(result.eligibility, sample.reason);
      });
    });
  }

  test('empty history retains the current status rejection reason', () async {
    await withClock(Clock.fixed(now), () async {
      for (final sample in [
        (status: null, reason: MealAdviceEligibility.missingDeviceStatus),
        (
          status: fresh.copyWith(hasCob: false),
          reason: MealAdviceEligibility.incompleteDeviceStatus,
        ),
        (
          status: fresh.copyWith(
            date: now.subtract(const Duration(minutes: 6)),
          ),
          reason: MealAdviceEligibility.staleDeviceStatus,
        ),
      ]) {
        current = sample.status;
        final result = await resolve();
        expect(result.status, isNull);
        expect(result.eligibility, sample.reason);
      }
    });
  });

  test(
    'history failure makes the resolver unavailable without throwing',
    () async {
      final failure = ResolveMealAdvisorDeviceStatusUseCase(
        readCurrentStatus: () => null,
        loadRepository: () async => throw StateError('History unavailable'),
      );
      final result = await failure();
      expect(result.status, isNull);
      expect(result.eligibility, MealAdviceEligibility.historyUnavailable);
    },
  );

  test('repository timeout makes the resolver unavailable', () async {
    final gate = Completer<DeviceStatusHistoryRepository>();
    final slow = ResolveMealAdvisorDeviceStatusUseCase(
      readCurrentStatus: () => null,
      loadRepository: () => gate.future,
      timeout: const Duration(milliseconds: 1),
    );
    final result = await slow();
    gate.complete(repository);
    expect(result.status, isNull);
    expect(result.eligibility, MealAdviceEligibility.historyUnavailable);
  });

  test('history fetch timeout is included in the same deadline', () async {
    final gate = Completer<DeviceStatus?>();
    repository.pending = gate.future;
    final slow = ResolveMealAdvisorDeviceStatusUseCase(
      readCurrentStatus: () => null,
      loadRepository: () async => repository,
      timeout: const Duration(milliseconds: 1),
    );
    final result = await slow();
    gate.complete(null);
    expect(result.status, isNull);
    expect(result.eligibility, MealAdviceEligibility.historyUnavailable);
  });

  test(
    'newer valid live status wins when it arrives during history loading',
    () async {
      await withClock(Clock.fixed(now), () async {
        final gate = Completer<DeviceStatus?>();
        repository.pending = gate.future;
        final pending = resolve();
        await Future<void>.delayed(Duration.zero);
        current = fresh;
        gate.complete(
          fresh.copyWith(date: now.subtract(const Duration(minutes: 1))),
        );
        final result = await pending;
        expect(result.status, same(fresh));
        expect(result.eligibility, MealAdviceEligibility.available);
      });
    },
  );

  test('newer history wins over a valid live arrival', () async {
    await withClock(Clock.fixed(now), () async {
      final gate = Completer<DeviceStatus?>();
      repository.pending = gate.future;
      final pending = resolve();
      await Future<void>.delayed(Duration.zero);
      current = fresh.copyWith(date: now.subtract(const Duration(minutes: 1)));
      gate.complete(fresh);
      expect((await pending).status, same(fresh));
    });
  });

  test('fresh live arrival remains usable when history fails', () async {
    await withClock(Clock.fixed(now), () async {
      final gate = Completer<DeviceStatus?>();
      repository.pending = gate.future;
      final pending = resolve();
      await Future<void>.delayed(Duration.zero);
      current = fresh;
      gate.completeError(Exception('History unavailable'));
      final result = await pending;
      expect(result.status, same(fresh));
      expect(result.eligibility, MealAdviceEligibility.available);
    });
  });

  test('freshness is checked after loading completes', () async {
    var clockTime = now;
    await withClock(Clock(() => clockTime), () async {
      final gate = Completer<DeviceStatus?>();
      repository.pending = gate.future;
      final pending = resolve();
      await Future<void>.delayed(Duration.zero);
      clockTime = now.add(const Duration(minutes: 6));
      gate.complete(fresh);
      final result = await pending;
      expect(result.status, isNull);
      expect(result.eligibility, MealAdviceEligibility.staleDeviceStatus);
    });
  });

  test(
    'provider reads configured history without overwriting live UI state',
    () async {
      final container = ProviderContainer(
        overrides: [
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      await withClock(Clock.fixed(now), () async {
        repository.result = fresh;
        final service = container.read(
          resolveMealAdvisorDeviceStatusUseCaseProvider,
        );
        expect((await service()).status, same(fresh));
        expect(container.read(deviceStatusUiProvider), isNull);
        expect(repository.requests, [now]);
      });
    },
  );

  test('provider can finish a history request after it is disposed', () async {
    final gate = Completer<DeviceStatus?>();
    repository.pending = gate.future;
    final container = ProviderContainer(
      overrides: [
        deviceStatusHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    await withClock(Clock.fixed(now), () async {
      final pending = container.read(
        resolveMealAdvisorDeviceStatusUseCaseProvider,
      )();
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      gate.complete(fresh);
      expect((await pending).status, same(fresh));
    });
  });
}

class ResolverStatusHistory implements DeviceStatusHistoryRepository {
  DeviceStatus? result;
  Future<DeviceStatus?>? pending;
  final requests = <DateTime>[];

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async {
    requests.add(before);
    return pending == null ? result : await pending;
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) => throw UnimplementedError();
}
