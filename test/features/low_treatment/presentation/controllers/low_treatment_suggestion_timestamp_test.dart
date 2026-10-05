import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  test(
    'draft keeps the AAPS suggestion time separate from its envelope',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final envelopeAt = DateTime(2026, 9, 15, 12);
      final suggestedAt = envelopeAt.subtract(const Duration(minutes: 2));
      container
          .read(deviceStatusUiProvider.notifier)
          .update(
            testDeviceStatus(
              date: envelopeAt,
              iob: 0,
              cob: 0,
              tick: '0',
              bg: 100,
              carbsReq: 8,
            ).copyWith(suggestedAt: suggestedAt),
          );
      container.listen(lowTreatmentContextControllerProvider, (_, _) {});
      await container.read(lowTreatmentContextControllerProvider.future);
      final controller = container.read(
        lowTreatmentContextControllerProvider.notifier,
      );

      final draft = controller.composeDashboardDraft(
        meal: MealDraft(
          name: 'Low treatment',
          mealIngredients: const [],
          plannedAt: envelopeAt,
          status: 'confirmed',
        ),
      );

      expect(draft.suggestionAt, suggestedAt);
      expect(draft.deviceStatusDate, envelopeAt);
    },
  );
}
