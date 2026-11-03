import 'dart:async';

import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_low_treatment_review_controller.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_review_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_low_treatment_review_repository.dart';
import '../../helpers/regression/scripted_read.dart';

void main() {
  final day = DateTime(2026, 9, 1);
  final event = Treat(
    externalId: 'remote-7',
    createdAt: day.add(const Duration(hours: 12)),
    carbs: 12,
  );
  for (final action in ['link', 'dismiss', 'reset']) {
    for (final failure in [false, true]) {
      test(
        'day review $action serializes writes and preserves source errors: failure=$failure',
        () async {
          final args = switch (action) {
            'link' => <Object?>['save', event, 17, false],
            'dismiss' => <Object?>['save', event, null, true],
            _ => <Object?>['reset', event.createdAt],
          };
          final pending = Completer<void>();
          final writes = ScriptedRead<void>('review', [
            (arguments: args, respond: () => pending.future),
            if (failure) (arguments: args, respond: () {}),
          ]);
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWith(
                (ref) => throw StateError('Unexpected direct database read'),
              ),
              lowTreatmentReviewRepositoryProvider.overrideWithValue(
                ScriptedLowTreatmentReviewRepository(writes),
              ),
            ],
          );
          addTearDown(container.dispose);
          final provider = dayLowTreatmentReviewControllerProvider(day);
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          await container.read(provider.future);
          final controller = container.read(provider.notifier);
          Future<void> save() => switch (action) {
            'link' => controller.resolve(event, mealId: 17, created: true),
            'dismiss' => controller.resolve(event, dismissed: true),
            _ => controller.reset(event.createdAt),
          };
          final operation = save();
          expect(container.read(provider).isLoading, true);
          await expectLater(save(), throwsStateError);
          expect(writes.calls.length, 1);
          if (failure) {
            final error = StateError('Review unavailable');
            final expectation = expectLater(operation, throwsA(same(error)));
            pending.completeError(error);
            await expectation;
            expect(container.read(provider).error, same(error));
            await save();
          } else {
            pending.complete();
            await operation;
          }
          expect(container.read(provider), const AsyncData<void>(null));
          writes.verifyComplete();
        },
      );
    }
  }
}
