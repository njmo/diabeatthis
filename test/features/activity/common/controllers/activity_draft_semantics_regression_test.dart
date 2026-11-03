import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final existing in [false, true]) {
    test(
      'editing activity retains identity and percentages when planned duration is toggled: existing=$existing',
      () {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(
              (ref) =>
                  throw StateError('Draft editing must not read the database'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(activityDraftProvider, (_, _) {});
        addTearDown(subscription.close);
        final controller = container.read(activityDraftProvider.notifier);
        if (existing) {
          controller.overrideDraft(
            const ActivityDraft.existing(
              id: 7,
              name: 'Walk',
              percentagePre: 80,
              percentagePost: 90,
              durationMinutes: 45,
            ),
          );
        } else {
          controller.setName('Walk');
          controller.setPercentagePre('80');
          controller.setPercentagePost('90');
          controller.setDurationMinutes('45');
        }
        controller.setHasPlannedDuration(true);
        expect(controller.getDurationMinutes(), 45);
        controller.setHasPlannedDuration(false);
        expect(controller.getDurationMinutes(), isNull);
        expect(controller.hasPlannedDuration(), false);
        expect(controller.getPercentagePre(), 80);
        expect(controller.getPercentagePost(), 90);
        controller.setHasPlannedDuration(true);
        expect(
          controller.getDurationMinutes(),
          defaultPlannedActivityDurationMinutes,
        );
        controller.setName('Cycle');
        controller.setPercentagePre('70');
        controller.setPercentagePost('85');
        controller.setDurationMinutes(' 25 ');
        expect(controller.getName(), 'Cycle');
        expect(controller.getPercentagePre(), 70);
        expect(controller.getPercentagePost(), 85);
        expect(controller.getDurationMinutes(), 25);
        expect(
          container
              .read(activityDraftProvider)!
              .map(existing: (v) => v.id, draft: (_) => null),
          existing ? 7 : null,
        );
        controller.setDurationMinutes(' ');
        expect(controller.hasPlannedDuration(), false);
        controller.setPercentagePre('invalid');
        controller.setPercentagePost('');
        expect(controller.getPercentagePre(), 0);
        expect(controller.getPercentagePost(), 0);
        controller.reset();
        expect(container.read(activityDraftProvider), isNull);
        expect(controller.getName(), '');
        expect(controller.getPercentagePre(), 0);
        expect(controller.getPercentagePost(), 0);
        expect(controller.getDurationMinutes(), isNull);
      },
    );
  }

  for (final initialField in [
    'pre',
    'post',
    'duration',
    'planned',
    'unplanned',
  ]) {
    test(
      'starting a draft from $initialField keeps the other fields explicit',
      () {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected database read'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(activityDraftProvider, (_, _) {});
        addTearDown(subscription.close);
        final controller = container.read(activityDraftProvider.notifier);
        switch (initialField) {
          case 'pre':
            controller.setPercentagePre('80');
          case 'post':
            controller.setPercentagePost('90');
          case 'duration':
            controller.setDurationMinutes('25');
          case 'planned':
            controller.setHasPlannedDuration(true);
          case 'unplanned':
            controller.setHasPlannedDuration(false);
        }
        expect(controller.getName(), '');
        expect(controller.getPercentagePre(), initialField == 'pre' ? 80 : 0);
        expect(controller.getPercentagePost(), initialField == 'post' ? 90 : 0);
        expect(controller.getDurationMinutes(), switch (initialField) {
          'duration' => 25,
          'planned' => defaultPlannedActivityDurationMinutes,
          _ => null,
        });
        expect(
          container
              .read(activityDraftProvider)!
              .map(existing: (_) => false, draft: (_) => true),
          true,
        );
      },
    );
  }
}
