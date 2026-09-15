import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_review_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'accept_day_summary_test.dart' show preview;

void main() {
  testWidgets(
    'accept requires acknowledging gaps and explicitly skipping unresolved entry',
    (tester) async {
      Set<int>? accepted;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DaySummaryReviewForm(
                snapshot: preview(gaps: true, pending: true),
                onAccept: (skipped, gaps) async {
                  expect(gaps, isTrue);
                  accepted = skipped;
                },
              ),
            ),
          ),
        ),
      );
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);
      await tester.tap(find.text('Zapisz podsumowanie ze wskazanymi brakami'));
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.tap(find.text('Pozostaw bez wyjaśnienia'));
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(accepted, {0});
    },
  );

  testWidgets('accepted document has no acceptance or correction controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DaySummaryReviewForm(
              snapshot: preview(gaps: true, pending: true),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Świadomie pozostawione bez wyjaśnienia'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
  });
}
