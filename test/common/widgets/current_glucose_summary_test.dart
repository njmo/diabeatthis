import 'package:diabeatthis/common/widgets/current_glucose_summary.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 2, 12);

  testWidgets('updates the reading and trend when live glucose changes', (
    tester,
  ) async {
    final container = await pumpGlucoseSummary(
      tester,
      now: now,
      glucose: summaryGlucose(
        date: now.subtract(const Duration(minutes: 2)),
        value: 108,
        direction: 'SingleUp',
      ),
    );

    expect(find.text('108 mg/dl'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.text('2 min temu'), findsOneWidget);

    final notifier =
        container.read(bloodSugarValueProvider.notifier)
            as GlucoseSummaryTestNotifier;
    notifier.setReading(
      summaryGlucose(
        date: now.subtract(const Duration(minutes: 1)),
        value: 114,
        direction: 'SingleDown',
      ),
    );
    await tester.pump();

    expect(find.text('114 mg/dl'), findsOneWidget);
    expect(find.text('108 mg/dl'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.text('1 min temu'), findsOneWidget);
  });

  testWidgets('uses newer CGM glucose and its trend over older device data', (
    tester,
  ) async {
    await pumpGlucoseSummary(
      tester,
      now: now,
      glucose: summaryGlucose(
        date: now.subtract(const Duration(minutes: 1)),
        value: 126,
        direction: 'FortyFiveUp',
      ),
      device: testDeviceStatus(
        date: now.subtract(const Duration(minutes: 4)),
        bg: 192,
        tick: '-20',
        iob: 0,
        cob: 0,
      ),
    );

    expect(find.text('126 mg/dl'), findsOneWidget);
    expect(find.text('192 mg/dl'), findsNothing);
    expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_double_arrow_down_rounded), findsNothing);
    expect(find.text('1 min temu'), findsOneWidget);
  });

  testWidgets('uses newer device data over an older CGM reading', (
    tester,
  ) async {
    await pumpGlucoseSummary(
      tester,
      now: now,
      glucose: summaryGlucose(
        date: now.subtract(const Duration(minutes: 4)),
        value: 99,
        direction: 'Flat',
      ),
      device: testDeviceStatus(
        date: now.subtract(const Duration(minutes: 1)),
        bg: 105,
        tick: '-12',
        iob: 0,
        cob: 0,
      ),
    );

    expect(find.text('105 mg/dl'), findsOneWidget);
    expect(find.text('99 mg/dl'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
  });

  testWidgets('falls back to a device reading and its available trend', (
    tester,
  ) async {
    await pumpGlucoseSummary(
      tester,
      now: now,
      device: testDeviceStatus(
        date: now.subtract(const Duration(minutes: 3)),
        bg: 145,
        tick: '+12',
        iob: 0,
        cob: 0,
      ),
    );

    expect(find.text('145 mg/dl'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.text('3 min temu'), findsOneWidget);
  });

  for (final tick in ['', 'unavailable']) {
    testWidgets('shows an unknown trend for device tick "$tick"', (
      tester,
    ) async {
      await pumpGlucoseSummary(
        tester,
        now: now,
        device: testDeviceStatus(
          date: now,
          bg: 145,
          tick: tick,
          iob: 0,
          cob: 0,
        ),
      );

      expect(find.text('145 mg/dl'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });
  }

  testWidgets('labels a reading as stale at the ten minute boundary', (
    tester,
  ) async {
    await pumpGlucoseSummary(
      tester,
      now: now,
      device: testDeviceStatus(
        date: now.subtract(const Duration(minutes: 10)),
        bg: 132,
        tick: '0',
        iob: 0,
        cob: 0,
      ),
    );

    expect(find.text('132 mg/dl'), findsOneWidget);
    expect(find.textContaining('10 min temu'), findsOneWidget);
    expect(find.textContaining('odczyt nieaktualny'), findsOneWidget);
  });

  testWidgets('shows missing readings when neither source has data', (
    tester,
  ) async {
    await pumpGlucoseSummary(tester, now: now);

    expect(find.text('Brak odczytów'), findsOneWidget);
    expect(find.textContaining('mg/dl'), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a narrow screen with enlarged text and a stale label', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    await pumpGlucoseSummary(
      tester,
      now: now,
      textScale: 2,
      device: testDeviceStatus(
        date: now.subtract(const Duration(minutes: 15)),
        bg: 168,
        tick: '-5',
        iob: 0,
        cob: 0,
      ),
    );

    expect(find.text('168 mg/dl'), findsOneWidget);
    expect(find.byIcon(Icons.south_east_rounded), findsOneWidget);
    expect(find.textContaining('odczyt nieaktualny'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> pumpGlucoseSummary(
  WidgetTester tester, {
  required DateTime now,
  Glucose? glucose,
  DeviceStatus? device,
  double textScale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      bloodSugarValueProvider.overrideWith(
        () => GlucoseSummaryTestNotifier(glucose),
      ),
      deviceStatusUiProvider.overrideWithValue(device),
      timeNowProvider.overrideWithValue(AsyncData(now)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedMaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CurrentGlucoseSummary(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Glucose summaryGlucose({
  required DateTime date,
  required int value,
  required String direction,
}) => Glucose(
  externalId: null,
  source: GlucoseSource.xdrip,
  date: date,
  sgv: value,
  direction: direction,
);

class GlucoseSummaryTestNotifier extends BloodSugarValueNotifier {
  GlucoseSummaryTestNotifier(this.initialReading);

  final Glucose? initialReading;

  @override
  Glucose? build() => initialReading;

  void setReading(Glucose? reading) => state = reading;
}
