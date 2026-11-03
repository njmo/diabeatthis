import 'dart:async';

import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/source_settings_test_doubles.dart'
    show EmptyDeviceStatusHistoryRepository, EmptyTreatmentsHistoryRepository;
import '../../helpers/regression/callback_glucose_history_repository.dart';

void main() {
  test(
    'safety audit: a settings reload replaces an in-flight history repository',
    () async {
      final oldReading = _glucose('old-source', DateTime(2026, 11, 3, 12));
      final newReading = _glucose('new-source', DateTime(2026, 11, 3, 12, 5));
      final requestStarted = Completer<void>();
      final oldResponse = Completer<List<Glucose>>();
      var repositoryGeneration = 0;
      final container = ProviderContainer(
        overrides: [
          glucoseHistoryRepositoryProvider.overrideWith((ref) async {
            repositoryGeneration++;
            if (repositoryGeneration == 1) {
              return CallbackGlucoseHistoryRepository((_) {
                requestStarted.complete();
                return oldResponse.future;
              });
            }
            return CallbackGlucoseHistoryRepository(
              (limit) async => [newReading],
            );
          }),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async => EmptyDeviceStatusHistoryRepository(),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => EmptyTreatmentsHistoryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = SynchronizationCacheController();
      final initialLoad = controller.ensureGlucoseReadingsReady(container);
      await requestStarted.future;

      // This mirrors the settings handler: invalidate source providers and
      // clear the cache before asking the controller to reload from history.
      container.invalidate(glucoseHistoryRepositoryProvider);
      controller.invalidateLiveData();
      final reload = controller.init(container);
      oldResponse.complete([oldReading]);

      await Future.wait([initialLoad, reload]);

      expect(
        {
          'repositoryGeneration': repositoryGeneration,
          'glucoseIds': controller
              .getCache()
              .glucoseReadingsCache
              .map((reading) => reading.externalId)
              .toList(),
        },
        {
          'repositoryGeneration': 2,
          'glucoseIds': ['new-source'],
        },
      );
    },
  );

  test(
    'history reload uses the replacement repository when no load is pending',
    () async {
      final oldReading = _glucose('old-source', DateTime(2026, 11, 3, 12));
      final newReading = _glucose('new-source', DateTime(2026, 11, 3, 12, 5));
      var repositoryGeneration = 0;
      final container = ProviderContainer(
        overrides: [
          glucoseHistoryRepositoryProvider.overrideWith((ref) async {
            repositoryGeneration++;
            final reading = repositoryGeneration == 1 ? oldReading : newReading;
            return CallbackGlucoseHistoryRepository((limit) async => [reading]);
          }),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async => EmptyDeviceStatusHistoryRepository(),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => EmptyTreatmentsHistoryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = SynchronizationCacheController();
      await controller.init(container);
      container.invalidate(glucoseHistoryRepositoryProvider);
      controller.invalidateLiveData();
      await controller.init(container);

      expect(repositoryGeneration, 2);
      expect(controller.getCache().glucoseReadingsCache.toList(), [newReading]);
    },
  );
}

Glucose _glucose(String id, DateTime date) => Glucose(
  externalId: id,
  source: GlucoseSource.cloud,
  date: date,
  sgv: id == 'old-source' ? 90 : 140,
  direction: 'Flat',
);
