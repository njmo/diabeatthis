import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/add_meal_basic_info_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/retrospective_meal_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('eating duration is required', (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Form(
            key: form,
            child: RetrospectiveMealFields(
              value: const RetrospectiveMealTiming(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '20');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets(
    'retains selected date when focusing and editing meal timing off screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const AddMealPage(retrospective: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selected = DateTime(2026, 3, 7, 13, 25);
      final dateField = find.byType(MealPlannedTimeField);
      tester.state<FormFieldState<DateTime>>(dateField).didChange(selected);
      tester
          .widget<AddMealBasicInfoSection>(find.byType(AddMealBasicInfoSection))
          .onPlannedAtChanged(selected);
      await tester.pump();

      final duration = find.widgetWithText(
        TextFormField,
        'Jak długo trwało jedzenie? (min)',
      );
      await tester.scrollUntilVisible(
        duration,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(duration);
      await tester.pumpAndSettle();
      await tester.tap(duration);
      await tester.pumpAndSettle();
      await tester.enterText(duration, '25');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        dateField,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.state<FormFieldState<DateTime>>(dateField).value, selected);
      expect(container.read(mealDraftProvider).plannedAt, selected);
      expect(find.textContaining('13:25'), findsOneWidget);
      await tester.scrollUntilVisible(
        duration,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
