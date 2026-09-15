import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_basal_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'complete zero basal remains visible on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: DayBasalRows(
                  summary: InsulinBasalSummary(
                    units: 0,
                    profileUnits: 0.4,
                    addedUnits: 0,
                    reducedUnits: 0.4,
                    coveredDuration: const Duration(hours: 1),
                    duration: const Duration(hours: 1),
                    gaps: [],
                  ),
                  boluses: const InsulinBolusSummary(
                    manualCount: 1,
                    manualUnits: 1,
                    otherCount: 0,
                    otherUnits: 0,
                  ),
                  isNight: true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('100,0%'), findsOneWidget);
      expect(find.text('0,00 U'), findsNWidgets(2));
      expect(find.text('1,00 U'), findsOneWidget);
      expect(find.text('Suma bazy i zapisanych bolusów'), findsOneWidget);
      expect(find.text('Baza w nocy (22:00–06:00)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('labels partial totals and shows unknown instead of zero', (
    tester,
  ) async {
    const boluses = InsulinBolusSummary(
      manualCount: 1,
      manualUnits: 1,
      otherCount: 0,
      otherUnits: 0,
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: DayBasalRows(
            summary: InsulinBasalSummary(
              units: 0.3,
              profileUnits: 0.4,
              addedUnits: 0,
              reducedUnits: 0.1,
              coveredDuration: Duration(minutes: 30),
              duration: Duration(hours: 1),
              gaps: [],
            ),
            boluses: boluses,
          ),
        ),
      ),
    );
    expect(find.text('50,0%'), findsOneWidget);
    expect(find.text('1,30 U'), findsOneWidget);
    expect(
      find.text('Suma częściowa bazy i zapisanych bolusów'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: DayBasalRows(summary: null, boluses: boluses),
        ),
      ),
    );
    expect(find.text('0,00 U'), findsNothing);
    expect(find.text('1,00 U'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
