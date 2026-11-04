import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_evidence_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'plate alone can generate; editing composition remains expanded after its first character',
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
      expect(find.byType(MealPhotoEvidenceInput), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Prepare proposal'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Meal composition (optional)'));
      await tester.pump();
      expect(find.byType(MealPhotoEvidenceInput), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.labelText, 'Dish and ingredients');
      expect(
        field.decoration!.hintText,
        'E.g. chicken in sauce, potatoes and beets',
      );
      expect(find.text('Dish and ingredients'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'P');
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Potatoes with hidden cheese',
      );
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Prepare proposal'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Prepare proposal'));
      await tester.pump();
      expect(generated!.description, 'Potatoes with hidden cheese');
      expect(generated!.menuPhotoPath, isNull);
      expect(generated!.mealPhotoPath, 'plate.jpg');
      expect(generated!.validate, returnsNormally);
    },
  );
  for (final withText in [false, true]) {
    testWidgets(
      'optional menu evidence supports generation and preserves text when supplied: $withText',
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
        await tester.tap(find.text('Meal composition (optional)'));
        await tester.pump();
        if (withText) {
          await tester.enterText(find.byType(TextField), 'Bigos with sausage');
          await tester.pump();
        }
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Add menu photo'),
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'Add menu photo'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Prepare proposal'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Prepare proposal'));
        await tester.pump();
        expect(generated!.menuPhotoPath, 'menu.jpg');
        expect(generated!.description, withText ? 'Bigos with sausage' : '');
        expect(generated!.validate, returnsNormally);
      },
    );
  }
}
