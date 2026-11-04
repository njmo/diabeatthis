import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_timing_selection.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_timing_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_timing_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);
  test(
    'eat-now uses confirmation time and planned date must remain in the future',
    () {
      final controller = MealPhotoTimingController();
      addTearDown(controller.dispose);
      expect(controller.selection.resolveAt(now), now);
      controller.chooseMode(MealPhotoTimingMode.planned);
      expect(controller.selection.isValidAt(now), isFalse);
      expect(() => controller.selection.resolveAt(now), throwsStateError);
      final future = now.add(const Duration(hours: 1));
      controller.chooseDate(future);
      expect(controller.selection.resolveAt(now), future);
      expect(controller.selection.isValidAt(future), isFalse);
      controller.chooseMode(MealPhotoTimingMode.eatNow);
      expect(controller.selection.resolveAt(future), future);
    },
  );
  testWidgets(
    'planning requires a future date; returning to eat now resolves current time',
    (tester) async {
      final controller = MealPhotoTimingController();
      addTearDown(controller.dispose);
      final future = now.add(const Duration(hours: 2));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => MealPhotoTimingOptions(
                selection: controller.selection,
                now: now,
                onModeChanged: controller.chooseMode,
                onDateSelected: controller.chooseDate,
                pickDate: (_, initial) async => future,
              ),
            ),
          ),
        ),
      );
      expect(controller.selection.mode, MealPhotoTimingMode.eatNow);
      expect(find.text('Choose a future date and time.'), findsNothing);
      await tester.tap(find.text('Plan meal'));
      await tester.pump();
      expect(controller.selection.isValidAt(now), isFalse);
      expect(find.text('Choose a future date and time.'), findsOneWidget);
      await tester.tap(find.text('Choose date and time'));
      await tester.pumpAndSettle();
      expect(controller.selection.plannedAt, future);
      expect(controller.selection.isValidAt(now), isTrue);
      expect(find.text('Choose a future date and time.'), findsNothing);
      await tester.tap(find.text('Eat now'));
      await tester.pump();
      expect(controller.selection.mode, MealPhotoTimingMode.eatNow);
      expect(controller.selection.resolveAt(now), now);
    },
  );
  for (final selected in [null, now.subtract(const Duration(minutes: 1))]) {
    testWidgets(
      'cancelled or past planning choice never becomes a valid future time: $selected',
      (tester) async {
        final controller = MealPhotoTimingController()
          ..chooseMode(MealPhotoTimingMode.planned);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => MealPhotoTimingOptions(
                  selection: controller.selection,
                  now: now,
                  onModeChanged: controller.chooseMode,
                  onDateSelected: controller.chooseDate,
                  pickDate: (_, initial) async => selected,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose date and time'));
        await tester.pumpAndSettle();
        expect(controller.selection.isValidAt(now), isFalse);
        expect(find.text('Choose a future date and time.'), findsOneWidget);
      },
    );
  }
  testWidgets('timing controls cannot change while persistence is busy', (
    tester,
  ) async {
    final controller = MealPhotoTimingController()
      ..chooseMode(MealPhotoTimingMode.planned);
    addTearDown(controller.dispose);
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MealPhotoTimingOptions(
            selection: controller.selection,
            now: now,
            enabled: false,
            onModeChanged: controller.chooseMode,
            onDateSelected: controller.chooseDate,
            pickDate: (_, initial) async {
              picks++;
              return now.add(const Duration(hours: 1));
            },
          ),
        ),
      ),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<SegmentedButton<MealPhotoTimingMode>>(
            find.byType(SegmentedButton<MealPhotoTimingMode>),
          )
          .onSelectionChanged,
      isNull,
    );
    expect(picks, 0);
    expect(controller.selection.plannedAt, isNull);
  });
}
