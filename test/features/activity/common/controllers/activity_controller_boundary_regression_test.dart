import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/scripted_activity_dao.dart';
import '../../../../helpers/regression/scripted_activity_database.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  for (final failure in [false, true]) {
    test(
      'activity update sends exact draft values to the database; failure=$failure',
      () async {
        final updates = ScriptedRead<ActivityData>('activity update', [
          (
            arguments: [7, 'Walk', 80, 90, 45],
            respond: () {
              if (failure) throw StateError('Mocked activity update failed');
              return const ActivityData(
                id: 7,
                name: 'Walk',
                percentagePre: 80,
                percentagePost: 90,
                durationMinutes: 45,
                isSynced: false,
                createdAt: 1000,
              );
            },
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(
              ScriptedActivityDatabase(ScriptedActivityDao(updates)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final operation = container
            .read(activityControllerProvider.notifier)
            .updateActivity(
              const ActivityDraft.existing(
                id: 7,
                name: 'Walk',
                percentagePre: 80,
                percentagePost: 90,
                durationMinutes: 45,
              ),
            );
        if (failure) {
          await expectLater(operation, throwsStateError);
        } else {
          final saved = await operation;
          expect(saved.id, 7);
          expect(saved.name, 'Walk');
          expect(saved.durationMinutes, 45);
          expect(saved.percentagePost, 90);
        }
        updates.verifyComplete();
      },
    );
  }

  test('picker transitions stay local and cannot read the database', () {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('Unexpected database read'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      activityDialogControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      activityDialogControllerProvider.notifier,
    );
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.initial,
    );
    controller.toOppositeState();
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.search,
    );
    controller.toOppositeState();
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.add,
    );
    controller.toOppositeState();
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.search,
    );
    controller.initialState();
    controller.addState();
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.add,
    );
    controller.searchState();
    expect(
      container.read(activityDialogControllerProvider),
      ActivityPickerStep.search,
    );
  });
}
