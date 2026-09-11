import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_date_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'calendar selects historical dates, rejects future dates and cancellation keeps selection',
    (tester) async {
      final selected = <DateTime?>[];
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: DayDateSelector(
              date: DateTime(2026, 9, 11),
              today: DateTime(2026, 9, 11),
              onSelected: selected.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('11.09.2026'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateTime(2026, 9, 11));
      await tester.tap(find.text('9'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(selected, [DateTime(2026, 9, 9)]);
      await tester.tap(find.text('11.09.2026'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();
      expect(selected, hasLength(1));
    },
  );

  testWidgets('selector fits a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: DayDateSelector(
              date: DateTime(2026, 9, 9),
              today: DateTime(2026, 9, 11),
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('09.09.2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
