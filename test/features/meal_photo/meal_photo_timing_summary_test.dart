import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_timing_selection.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_timing_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  testWidgets(
    'now has no planning switch and dismissing time edit preserves it',
    (tester) async {
      var dateChanges = 0;
      await tester.pumpWidget(
        harness(
          MealPhotoTimingSummary(
            selection: const MealPhotoTimingSelection(),
            now: DateTime(2026, 11, 4, 12),
            onDateSelected: (_) => dateChanges++,
            onUseNow: () {},
            pickDate: (_, _) async => null,
          ),
        ),
      );
      expect(find.text('Now'), findsOneWidget);
      expect(find.byType(SegmentedButton<MealPhotoTimingMode>), findsNothing);
      await tester.tap(find.byTooltip('Edit meal time'));
      await tester.pumpAndSettle();
      expect(dateChanges, 0);
    },
  );

  testWidgets('edited date appears and can be reset to now', (tester) async {
    final date = DateTime(2026, 11, 4, 14);
    var reset = false;
    DateTime? edited;
    await tester.pumpWidget(
      harness(
        MealPhotoTimingSummary(
          selection: MealPhotoTimingSelection(
            mode: MealPhotoTimingMode.planned,
            plannedAt: date,
          ),
          now: DateTime(2026, 11, 4, 12),
          onDateSelected: (value) => edited = value,
          onUseNow: () => reset = true,
          pickDate: (_, _) async => date.add(const Duration(hours: 1)),
        ),
      ),
    );
    expect(find.textContaining('14:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit meal time'));
    await tester.pumpAndSettle();
    expect(edited, date.add(const Duration(hours: 1)));
    await tester.tap(find.text('Now'));
    expect(reset, isTrue);
  });
}
