import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/form_timeline_marker.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'capture timeline requires photo and accepts optional composition and preserves both evidence forms in the exact proposal input',
    (tester) async {
      var category = false;
      var plateCaptures = 0;
      var menuCaptures = 0;
      MealPhotoInput? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => MealPhotoCaptureStep(
                  categorySelected: category,
                  categorySummary: category ? 'Lunch' : null,
                  categoryField: TextButton(
                    onPressed: () => setState(() => category = true),
                    child: const Text('Choose category'),
                  ),
                  capturePhoto: (_, menu) async {
                    if (menu) {
                      menuCaptures++;
                      return '/menu.jpg';
                    }
                    plateCaptures++;
                    return '/plate.jpg';
                  },
                  onGenerate: (input) => result = input,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Choose category'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Take a plate photo'),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Prepare proposal'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Meal category'));
      await tester.pump();
      expect(find.text('Choose category'), findsOneWidget);
      await tester.tap(find.text('Choose category'));
      await tester.pump();
      expect(find.text('Lunch'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Take a plate photo'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Take a plate photo'),
      );
      await tester.pumpAndSettle();
      expect(plateCaptures, 1);
      expect(
        find.widgetWithText(OutlinedButton, 'Take a plate photo'),
        findsNothing,
      );
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
      await tester.enterText(
        find.byType(TextField),
        'Potatoes with hidden cheese',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Prepare proposal'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Add menu photo'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add menu photo'));
      await tester.pumpAndSettle();
      expect(menuCaptures, 1);
      await tester.tap(find.text('Meal composition (optional)'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Potatoes with hidden cheese',
      );
      await tester.tap(find.text('Meal composition (optional)'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widgetList<FormTimelineMarker>(find.byType(FormTimelineMarker))
            .where((marker) => marker.status == FormTimelineStatus.completed)
            .length,
        3,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Prepare proposal'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Prepare proposal'));
      await tester.pump();
      expect(result!.mealPhotoPath, '/plate.jpg');
      expect(result!.menuPhotoPath, '/menu.jpg');
      expect(result!.description, 'Potatoes with hidden cheese');
    },
  );
}
