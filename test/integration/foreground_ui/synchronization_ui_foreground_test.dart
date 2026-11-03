import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/app/execute_command_event.dart';
import 'package:diabeatthis/common/events/data/app/sync_data_key.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import 'package:diabeatthis/foreground/event/external/app/app_event.dart';
import 'package:diabeatthis/foreground/event/external/app/app_event_handler.dart';
import 'package:diabeatthis/foreground/event/external/local_glucose/local_glucose_event.dart';
import 'package:diabeatthis/foreground/event/external/local_glucose/local_glucose_handler.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_glucose_test_view.dart';
import '../../helpers/foreground_ui/foreground_to_ui_test_router.dart';
import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/localized_material_app.dart';
import '../../helpers/regression/callback_glucose_history_repository.dart';

void main() {
  const config = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );
  final now = DateTime(2026, 11, 3, 12);
  Glucose reading(
    int value, {
    int minutesAgo = 0,
    GlucoseSource source = GlucoseSource.aaps,
  }) => Glucose(
    externalId: '$value-$minutesAgo',
    source: source,
    date: now.subtract(Duration(minutes: minutesAgo)),
    sgv: value,
    direction: 'Flat',
  );

  Future<ForegroundUiHarness> create(
    WidgetTester tester,
    ForegroundToUiTestRouter transport,
  ) async => (await tester.runAsync(
    () => ForegroundUiHarness.create(
      meals: false,
      foregroundOverrides: [
        dataSourceConfigProvider.overrideWith((ref) async => config),
        taskEventRouterProvider.overrideWithValue(transport),
        glucoseHistoryRepositoryProvider.overrideWith(
          (ref) async => CallbackGlucoseHistoryRepository((limit) async {
            expectSync(limit, 10);
            return [];
          }),
        ),
      ],
    ),
  ))!;

  Future<void> mount(
    WidgetTester tester,
    ForegroundUiHarness harness,
    ForegroundToUiTestRouter transport,
  ) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.uiContainer,
      child: localizedMaterialApp(
        home: ForegroundGlucoseTestView(transport: transport),
      ),
    ),
  );

  Future<void> send(
    WidgetTester tester,
    ForegroundUiHarness harness,
    Glucose value,
  ) async {
    await LocalGlucoseHandler().handle(
      LocalGlucoseEvent(data: value),
      harness.runtimeContext,
    );
    await tester.pump();
  }

  for (final scenario in ['fresh', 'wrong-source', 'duplicate', 'expiry']) {
    testWidgets(
      'foreground glucose and real dashboard stay consistent: $scenario',
      (tester) => withClock(Clock.fixed(now), () async {
        final transport = ForegroundToUiTestRouter();
        final harness = await create(tester, transport);
        addTearDown(harness.close);
        await mount(tester, harness, transport);
        expect(find.text('??'), findsOneWidget);
        await send(tester, harness, reading(140));
        expect(find.text('140'), findsOneWidget);
        expect(
          harness.foregroundContainer.read(bloodSugarValueProvider)?.sgv,
          140,
        );
        if (scenario == 'wrong-source') {
          await send(tester, harness, reading(90, source: GlucoseSource.xdrip));
          expect(find.text('140'), findsOneWidget);
          expect(
            harness.foregroundContainer.read(bloodSugarValueProvider)?.sgv,
            140,
          );
          expect(transport.messages, hasLength(1));
        } else if (scenario == 'duplicate') {
          await send(tester, harness, reading(140));
          expect(find.text('140'), findsOneWidget);
          expect(
            harness.foregroundContainer.read(bloodSugarValueProvider)?.sgv,
            140,
          );
        } else if (scenario == 'expiry') {
          await tester.pump(const Duration(minutes: 6));
          expect(find.text('??'), findsOneWidget);
          expect(
            harness.foregroundContainer.read(bloodSugarValueProvider),
            isNull,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(harness.close);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'returning UI requests the foreground cache and shows its newest reading',
    (tester) => withClock(Clock.fixed(now), () async {
      final transport = ForegroundToUiTestRouter();
      final harness = await create(tester, transport);
      addTearDown(harness.close);
      await mount(tester, harness, transport);
      await send(tester, harness, reading(100, minutesAgo: 3));
      expect(find.text('100'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await send(tester, harness, reading(120, minutesAgo: 2));
      await send(tester, harness, reading(140));
      expect(
        harness.foregroundContainer.read(bloodSugarValueProvider)?.sgv,
        140,
      );
      await mount(tester, harness, transport);
      expect(find.text('100'), findsOneWidget);
      AppEventHandler().handle(
        const AppEvent.executeCommand(
          data: ExecuteCommandEvent.syncData(data: [SyncDataKey.glucoseList]),
        ),
        harness.runtimeContext,
      );
      await tester.pumpAndSettle();
      expect(find.text('140'), findsWidgets);
      final history = harness.uiContainer
          .read(bloodSugarReadingsListProvider)
          .requireValue;
      expect(history.map((g) => g.sgv), [140, 120, 100]);
      expect(history.map((g) => g.date).toSet(), hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(harness.close);
      expect(tester.takeException(), isNull);
    }),
  );

  for (final age in [2, 7]) {
    testWidgets(
      'late $age minute old glucose cannot replace a newer dashboard value',
      (tester) => withClock(Clock.fixed(now), () async {
        final transport = ForegroundToUiTestRouter();
        final harness = await create(tester, transport);
        addTearDown(harness.close);
        await mount(tester, harness, transport);
        await send(tester, harness, reading(140));
        expect(find.text('140'), findsOneWidget);
        try {
          await send(tester, harness, reading(90, minutesAgo: age));
          expect(
            (
              harness.foregroundContainer.read(bloodSugarValueProvider)?.sgv,
              tester
                  .widget<DashboardGlucoseReading>(
                    find.byType(DashboardGlucoseReading),
                  )
                  .value,
            ),
            (140, 140),
          );
          expect(find.text('140'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(harness.close);
        }
      }),
    ); // Regression: a delayed old sample replaces/clears the current sample in foreground and UI.
  }
}
