import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'timeline_recorded_values_test.dart' show statusAt;

void main() {
  testWidgets(
    'small insulin values retain nonzero localized axis labels without changing recorded data',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      final start = DateTime(2026, 11, 8, 12);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TimelineDeviceMetricChart(
                chartStart: start,
                chartEnd: start.add(const Duration(minutes: 5)),
                deviceStatuses: [
                  statusAt(start, .082),
                  statusAt(start.add(const Duration(minutes: 5)), .04),
                ],
                metric: TimelineDeviceMetric.iob,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0,09'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.first.y, .082);
      expect(chart.data.lineBarsData.first.spots.last.y, .04);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
