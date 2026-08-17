import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  test('finish summary is blocked while meal still requires bolus', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final notifications = FakeNotificationsController();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);

    final useCase = container.read(finalizeMealSummaryUseCaseProvider);

    await expectLater(
      useCase.call(
        const MealSummaryDraft(
          mealId: 1,
          mealStatus: 'eating-then-bolus',
          itemIds: [],
          itemsById: {},
          extraItems: [],
        ),
      ),
      throwsA(isA<MealSummaryCannotFinishException>()),
    );

    expect(notifications.cancelAllCalled, isFalse);
  });

  test('finish summary is allowed only for eaten statuses', () async {
    expect(mealSummaryCanFinish('eaten'), isTrue);
    expect(mealSummaryCanFinish('eaten-extra'), isTrue);
    expect(mealSummaryCanFinish('eaten-bolused'), isTrue);
    expect(mealSummaryCanFinish('eating'), isFalse);
    expect(mealSummaryCanFinish('eating-then-bolus'), isFalse);
    expect(mealSummaryCanFinish('waiting-for-bolus'), isFalse);
    expect(mealSummaryCanFinish('bolused-eating'), isFalse);
    expect(mealSummaryCanFinish('bolused-waiting'), isFalse);
  });
}
