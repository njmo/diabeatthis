import 'package:diabeatthis/features/low_treatment/presentation/widgets/delete_recorded_low_treatment_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('deletion requires confirmation and respects cancellation', (
    tester,
  ) async {
    var deletions = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: DeleteRecordedLowTreatmentButton(
            busy: false,
            onDelete: () async {
              deletions++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    expect(deletions, 0);
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(deletions, 0);
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Usuń'));
    await tester.pumpAndSettle();
    expect(deletions, 1);
  });
}
