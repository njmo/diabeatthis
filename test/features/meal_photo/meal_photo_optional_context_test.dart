import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'plate alone generates while optional composition stays collapsed',
    (tester) async {
      MealPhotoInput? generated;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealPhotoCaptureStep(
                capturePhoto: (_, menu) async =>
                    menu ? 'menu.jpg' : 'plate.jpg',
                onGenerate: (input) => generated = input,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Take a plate photo'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Prepare proposal'));
      expect(generated!.description, isEmpty);
      expect(generated!.menuPhotoPath, isNull);
      expect(generated!.validate, returnsNormally);
      await tester.tap(find.text('Meal composition (optional)'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(
          'Ingredients or a menu photo help estimate macros more accurately.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Meal composition (optional)'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    },
  );
}
