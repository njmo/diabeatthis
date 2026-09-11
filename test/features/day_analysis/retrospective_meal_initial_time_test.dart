import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'suggested eating time is visible, valid and saved without opening the picker',
    (tester) async {
      final time = DateTime(2026, 9, 10, 20, 15);
      final form = GlobalKey<FormState>();
      DateTime? saved;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: MealPlannedTimeField(
                retrospective: true,
                initialDate: time,
                onChanged: (value) => saved = value,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('20:15'), findsOneWidget);
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(saved, time);
    },
  );
}
