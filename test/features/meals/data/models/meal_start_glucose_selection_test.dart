import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_start_context_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_start_context_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;

void main() {
  final details = mealDetailsWithLowTreatment();
  final start = details.analysisTime;
  Glucose sample(
    int milliseconds, {
    String direction = 'FortyFiveDown',
    GlucoseType type = GlucoseType.cgm,
  }) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(milliseconds: milliseconds)),
    sgv: 132,
    direction: direction,
    type: type,
  );
  MealStartContextData context(List<Glucose> readings, {DateTime? end}) =>
      MealStartContextData(
        details: details,
        analysis: MealAnalysisData(
          chartStart: start.subtract(const Duration(hours: 1)),
          chartEnd: end ?? start.add(const Duration(minutes: 90)),
          expectedChartEnd: start.add(const Duration(minutes: 90)),
          eventStart: start,
          eventEnd: start.add(const Duration(minutes: 90)),
          mealTime: start,
          glucoseReadings: readings,
          treatments: const [],
          temporaryTargets: const [],
          deviceStatuses: const [],
          linkedActivities: const [],
          linkedMeals: const [],
          timelineEvents: const [],
        ),
      );

  test(
    'historical start keeps direction from the closest CGM despite millisecond offset',
    () {
      final closest = sample(409);
      final data = context([sample(-300278), closest]);
      expect(data.glucose, same(closest));
      expect(data.glucose!.direction, 'FortyFiveDown');
    },
  );

  test(
    'historical start excludes spot checks, distant samples and data after observation end',
    () {
      expect(
        context([
          sample(0, type: GlucoseType.finger),
          sample(-300001),
          sample(300001),
        ]).glucose,
        isNull,
      );
      expect(context([sample(409)], end: start).glucose, isNull);
    },
  );

  testWidgets(
    'starting section displays the recorded direction from the closest sample',
    (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealStartContextSection(data: context([sample(409)])),
            ),
          ),
        ),
      );
      expect(find.text('132'), findsOneWidget);
      expect(find.byIcon(Icons.south_east_rounded), findsOneWidget);
      expect(find.text('Brak zapisanego kierunku zmian'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing sample does not claim that only its direction is missing',
    (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealStartContextSection(data: context([])),
            ),
          ),
        ),
      );
      expect(find.text('Brak zapisanego kierunku zmian'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sample without recorded direction remains explicitly unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealStartContextSection(
              data: context([sample(409, direction: '')]),
            ),
          ),
        ),
      ),
    );
    expect(find.text('132'), findsOneWidget);
    expect(find.text('Brak zapisanego kierunku zmian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
