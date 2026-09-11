import 'dart:async';

import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Treat;
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_low_treatment_review_controller.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_review_repository_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DeferredReviewRepository extends LowTreatmentReviewRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  final Object? failure;

  DeferredReviewRepository(super.db, {this.failure});

  @override
  Future<void> save(Treat event, {int? mealId, bool dismissed = false}) async {
    started.complete();
    await release.future;
    if (failure != null) throw failure!;
    await super.save(event, mealId: mealId, dismissed: dismissed);
  }
}

void main() {
  for (final fails in [false, true]) {
    test(
      'disposing the scope during a review save preserves its result (failure: $fails)',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final failure = fails ? StateError('Storage unavailable') : null;
        final repository = DeferredReviewRepository(db, failure: failure);
        final container = ProviderContainer(
          overrides: [
            lowTreatmentReviewRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final date = DateTime(2026, 9, 10);
        final provider = dayLowTreatmentReviewControllerProvider(date);
        final subscription = container.listen(provider, (_, _) {});
        await container.read(provider.future);
        final operation = container
            .read(provider.notifier)
            .resolve(
              Treat(externalId: 'source', createdAt: date, carbs: 10),
              dismissed: true,
            );
        final expectation = expectLater(
          operation,
          fails ? throwsA(same(failure)) : completes,
        );
        await repository.started.future;
        subscription.close();
        container.dispose();
        repository.release.complete();
        await expectation;
        final decisions = await repository.fetch(date, date);
        expect(decisions.length, fails ? 0 : 1);
      },
    );
  }
}
