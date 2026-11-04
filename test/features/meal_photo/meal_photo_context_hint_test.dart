import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/context_hint_card.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'context hint appears after photo and opens optional composition',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealPhotoCaptureStep(
                capturePhoto: (_, menu) async =>
                    menu ? 'menu.jpg' : 'plate.jpg',
                onGenerate: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ContextHintCard), findsNothing);
      await tester.tap(find.text('Zrób zdjęcie talerza'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextHintCard), findsOneWidget);
      expect(
        find.textContaining('wskaż numer albo nazwę dania'),
        findsOneWidget,
      );
      final generate = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(generate.onPressed, isNotNull);
      await tester.ensureVisible(find.text('Dodaj skład lub menu'));
      await tester.tap(find.text('Dodaj skład lub menu'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ContextHintCard), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        'Bigos z kiełbasą i ziemniakami',
      );
      await tester.tap(find.text('Skład posiłku (opcjonalnie)'));
      await tester.pumpAndSettle();
      expect(find.byType(ContextHintCard), findsNothing);
    },
  );

  testWidgets(
    'hint never makes composition required for generating a proposal',
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
                capturePhoto: (_, menu) async => 'plate.jpg',
                onGenerate: (input) => generated = input,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Take a plate photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Prepare proposal'));
      await tester.tap(find.text('Prepare proposal'));
      expect(generated?.mealPhotoPath, 'plate.jpg');
      expect(generated?.description, isEmpty);
    },
  );
}
