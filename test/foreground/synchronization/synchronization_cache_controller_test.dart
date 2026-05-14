import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_source_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('init does not fail when glucose source is unavailable', () async {
    final container = ProviderContainer(
      overrides: [
        glucoseSourceRepositoryProvider.overrideWith(
          (ref) async => _FakeGlucoseSourceRepository(),
        ),
        glucoseHistoryRepositoryProvider.overrideWith(
          (ref) async => _ThrowingGlucoseHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = SynchronizationCacheController();

    await expectLater(controller.init(container), completes);
    expect(controller.getCache().glucoseReadingsCache, isEmpty);
  });
}

class _FakeGlucoseSourceRepository implements GlucoseSourceRepository {
  @override
  Future<Glucose?> pollGlucose() async => null;
}

class _ThrowingGlucoseHistoryRepository implements GlucoseHistoryRepository {
  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    throw StateError('history unavailable');
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    throw StateError('history unavailable');
  }
}
