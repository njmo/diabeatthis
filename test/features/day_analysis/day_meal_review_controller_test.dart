import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_meal_review_controller.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/models/meal_review_timing.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'controller saves and removes remote-only links, preserving state on conflict',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final day = DateTime(2026, 9, 11);
      final provider = dayMealReviewControllerProvider(day);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final first = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'First', plannedAt: 1000));
      final second = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Second', plannedAt: 2000));
      final wizard = domain.BolusWizard(
        nightscoutObjectId: 'ns',
        remoteSource: 'https://example.com',
        createdAt: day,
        date: day,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      await controller.link(
        wizard,
        first,
        MealWizardRelationType.continuation,
        timing: MealReviewTiming(
          startedAt: day,
          timing: const RetrospectiveMealTiming(eatingMinutes: 10),
        ),
      );
      final links = MealWizardLinkRepository(db);
      final link = (await links.forMeal(first)).single;
      expect(link.relationType, 'continuation');
      expect(container.read(provider).hasError, isFalse);
      await expectLater(
        controller.link(wizard, second, MealWizardRelationType.initial),
        throwsStateError,
      );
      expect((await links.forMeal(first)).single.id, link.id);
      expect(await links.forMeal(second), isEmpty);
      expect(container.read(provider).hasError, isTrue);
      await controller.unlink(link.id);
      expect(await links.forMeal(first), isEmpty);
      expect(container.read(provider).hasError, isFalse);
    },
  );
}
