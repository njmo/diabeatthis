import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('creates low treatment meal and context from dashboard draft', () async {
    final relatedMeal = await db
        .into(db.meal)
        .insertReturning(MealCompanion.insert(name: 'Obiad', plannedAt: 1000));
    final deviceStatusDate = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    container
        .read(deviceStatusValueProvider.notifier)
        .update(
          testDeviceStatus(
            date: deviceStatusDate,
            iob: 0.4,
            cob: 2,
            tick: '-1',
            bg: 74,
            carbsReq: 8,
            carbsReqWithin: 10,
          ),
        );

    final mealDraft = MealDraft(
      name: 'Dosłodzenie',
      mealIngredients: const [],
      plannedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      status: 'draft',
    );
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );

    final draft = controller.composeDashboardDraft(
      meal: mealDraft,
      relatedMealId: relatedMeal.id,
    );
    final context = await controller.save(draft);
    final lowTreatment = await db.mealDao.getMealById(context.mealId);

    expect(lowTreatment?.purpose, 'lowTreatment');
    expect(lowTreatment?.status, 'confirmed');
    expect(context.relatedMealId, relatedMeal.id);
    expect(context.source, LowTreatmentContextSource.dashboardAction);
    expect(context.suggestedCarbs, 8);
    expect(context.suggestedWithinMinutes, 10);
    expect(context.deviceStatusDate, deviceStatusDate);
    expect(context.reason, LowTreatmentReason.carbsReq);
  });
}
