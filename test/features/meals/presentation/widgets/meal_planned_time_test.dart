import 'package:clock/clock.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/add_meal_basic_info_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final example in [
    (label: 'Teraz', minutes: 0),
    (label: 'Za 15 min', minutes: 15),
    (label: 'Za 45 min', minutes: 45),
  ]) {
    testWidgets(
      '${example.label} sets a fixed draft time, including midnight rollover',
      (tester) async {
        var now = DateTime(2026, 9, 7, 23, 50);
        await withClock(Clock(() => now), () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final formKey = GlobalKey<FormState>();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: localizedMaterialApp(
                home: Scaffold(
                  body: Form(
                    key: formKey,
                    child: AddMealBasicInfoSection(
                      onNameSaved: container
                          .read(mealDraftProvider.notifier)
                          .setName,
                      onPlannedAtChanged: container
                          .read(mealDraftProvider.notifier)
                          .setPlannedAt,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final timeField = tester.state<FormFieldState<DateTime>>(
            find.byType(MealPlannedTimeField),
          );
          expect(timeField.validate(), isFalse);
          await tester.pump();

          final expected = now.add(Duration(minutes: example.minutes));
          await tester.tap(find.text(example.label));
          await tester.pumpAndSettle();
          expect(container.read(mealDraftProvider).plannedAt, expected);
          expect(timeField.value, expected);
          expect(timeField.validate(), isTrue);
          final context = tester.element(find.byType(MealPlannedTimeField));
          expect(
            find.textContaining(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay.fromDateTime(expected),
                alwaysUse24HourFormat: true,
              ),
            ),
            findsOneWidget,
          );

          now = now.add(const Duration(minutes: 10));
          await tester.enterText(find.byType(TextFormField), 'Kolacja domowa');
          await tester.pumpAndSettle();
          formKey.currentState!.save();
          expect(container.read(mealDraftProvider).plannedAt, expected);
          expect(timeField.value, expected);
          await tester.tap(find.text(example.label));
          await tester.pumpAndSettle();
          expect(
            container.read(mealDraftProvider).plannedAt,
            now.add(Duration(minutes: example.minutes)),
          );
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'custom picker opens at the selected time and cancellation keeps it',
    (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 9, 7, 12)), () async {
        DateTime? selected;
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: Form(
                child: MealPlannedTimeField(
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Za 45 min'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InputDecorator));
        await tester.pumpAndSettle();
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.initialDate, DateTime(2026, 9, 7));
        final context = tester.element(find.byType(DatePickerDialog));
        await tester.tap(
          find.text(MaterialLocalizations.of(context).cancelButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, 9, 7, 12, 45));
        expect(find.textContaining('12:45'), findsOneWidget);
        await tester.tap(find.byType(InputDecorator));
        await tester.pumpAndSettle();
        final dateContext = tester.element(find.byType(DatePickerDialog));
        await tester.tap(
          find.text(MaterialLocalizations.of(dateContext).okButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TimePickerDialog>(find.byType(TimePickerDialog))
              .initialTime,
          const TimeOfDay(hour: 12, minute: 45),
        );
        final timeContext = tester.element(find.byType(TimePickerDialog));
        await tester.tap(
          find.text(MaterialLocalizations.of(timeContext).okButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, 9, 7, 12, 45));
        expect(tester.takeException(), isNull);
      });
    },
  );
}
