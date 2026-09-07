import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/add_meal_basic_info_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'updates the draft without resetting focus, selection or composition',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await mountMealNameForm(tester, container);
      await tester.enterText(find.byType(TextFormField), 'Obiad domowy');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      const editingValue = TextEditingValue(
        text: 'Obiad nowy domowy',
        selection: TextSelection.collapsed(offset: 10),
        composing: TextRange(start: 6, end: 10),
      );

      tester.testTextInput.updateEditingValue(editingValue);
      await tester.pump();

      expect(container.read(mealDraftProvider).name, editingValue.text);
      final updated = tester.widget<EditableText>(find.byType(EditableText));
      expect(updated.controller, same(editable.controller));
      expect(updated.controller.value, editingValue);
      expect(updated.focusNode.hasFocus, isTrue);
    },
  );

  for (final useTemplate in [false, true]) {
    testWidgets('synchronizes copied source name (template: $useTemplate)', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = await mountMealNameForm(tester, container);
      await tester.enterText(find.byType(TextFormField), 'Własny obiad');
      await tester.pump();
      final source = useTemplate
          ? CopiedMealFromTemplate(
              id: 1,
              name: 'Obiad z szablonu',
              date: DateTime(2026),
              copiedFromMealId: null,
            )
          : CopiedMealFromMeal(
              id: 1,
              name: 'Poprzedni obiad',
              date: DateTime(2026),
              copiedFromMealId: null,
              copiedFromTemplateId: null,
            );

      container.read(mealDraftProvider.notifier).applySource(source, []);
      await tester.pump();

      final expected = useTemplate ? source.name : 'Własny obiad';
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, expected);
      key.currentState!.save();
      expect(container.read(mealDraftProvider).name, expected);
    });
  }

  testWidgets('keeps spaces while editing and trims them when saving', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = await mountMealNameForm(tester, container);
    await tester.enterText(find.byType(TextFormField), '  Obiad domowy  ');
    await tester.pump();
    expect(container.read(mealDraftProvider).name, '  Obiad domowy  ');

    key.currentState!.save();
    await tester.pump();

    expect(container.read(mealDraftProvider).name, 'Obiad domowy');
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Obiad domowy',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retains the five-character validation and length limit', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await mountMealNameForm(tester, container);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.validator!('  abcd  '), isNotNull);
    expect(field.validator!('  abcde  '), isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 120);
  });
}

Future<GlobalKey<FormState>> mountMealNameForm(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final key = GlobalKey<FormState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedMaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: AddMealBasicInfoSection(
              onNameSaved: container.read(mealDraftProvider.notifier).setName,
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
  return key;
}
