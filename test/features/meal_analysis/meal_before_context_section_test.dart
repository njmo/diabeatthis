import 'package:diabeatthis/features/meal_analysis/data/providers/build_before_meal_context_use_case_provider.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_facts.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_before_context_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_before_context_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

import '../meals/presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;
import 'build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;

void main() {
  test(
    'history adapter passes the reference time and preserves missing macros',
    () async {
      final details = mealDetailsWithLowTreatment();
      final container = ProviderContainer(
        overrides: [
          buildBeforeMealContextUseCaseProvider(
            false,
          ).overrideWithValue(builder()),
        ],
      );
      addTearDown(container.dispose);
      final data = await container.read(
        mealBeforeContextProvider((details: details, forceCloud: false)).future,
      );
      expect(data.asOf, details.analysisTime);
      expect(data.mealId, details.meal.id);
      expect(data.macros, isNull);
    },
  );
  testWidgets(
    'loads only when expanded, retries errors and explicitly switches to cloud',
    (tester) async {
      final details = mealDetailsWithLowTreatment();
      final data = await builder()(asOf: cutoff, macros: macros);
      var localCalls = 0;
      var cloudCalls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealBeforeContextProvider((
              details: details,
              forceCloud: false,
            )).overrideWith((ref) async {
              localCalls++;
              if (localCalls == 1) throw StateError('offline');
              return data;
            }),
            mealBeforeContextProvider((
              details: details,
              forceCloud: true,
            )).overrideWith((ref) async {
              cloudCalls++;
              return data;
            }),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealBeforeContextSection(details: details),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(localCalls, 0);
      await tester.tap(find.text('Historia przed posiłkiem'));
      await tester.pumpAndSettle();
      expect(localCalls, 1);
      expect(
        find.text('Nie udało się zbudować kontekstu. Spróbuj ponownie.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Odśwież'));
      await tester.pumpAndSettle();
      expect(localCalls, 2);
      expect(find.byType(BeforeMealFacts), findsOneWidget);
      await tester.ensureVisible(find.text('Pobierz kontekst z Nightscout'));
      await tester.tap(find.text('Pobierz kontekst z Nightscout'));
      await tester.pumpAndSettle();
      expect(cloudCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('partial context fits narrow layout and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = await builder(
      glucose: (_, _) async => throw StateError('offline'),
    )(asOf: cutoff, macros: macros);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BeforeMealFacts(data: data, hasRecordedStart: false),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Brak danych:'), findsOneWidget);
    expect(find.text('Trwające harmonogramy eCarbs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
