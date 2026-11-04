import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/detail_metric_section.dart';
import 'package:diabeatthis/common/widgets/detail_metric_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'paired metrics align borders, icons, labels and values with optional info',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 410,
                child: DetailMetricSection(
                  title: 'Activity',
                  icon: Icons.insights,
                  metrics: [
                    const DetailMetricTile(
                      key: ValueKey('start'),
                      icon: Icons.play_arrow,
                      label: 'Start',
                      value: '162',
                      detail: 'Reading at 17:30',
                      minimumLabelLines: 2,
                    ),
                    const DetailMetricTile(
                      key: ValueKey('end'),
                      icon: Icons.stop,
                      label: 'Glucose at finish',
                      value: '107',
                      detail: 'Recorded after activity at 18:30',
                      explanation: 'Actual later reading',
                      minimumLabelLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('start'));
      final second = find.byKey(const ValueKey('end'));
      expect(tester.getSize(first).height, tester.getSize(second).height);
      expect(
        tester.getTopLeft(find.byIcon(Icons.play_arrow)).dy,
        tester.getTopLeft(find.byIcon(Icons.stop)).dy,
      );
      expect(
        tester.getTopLeft(find.text('Start')).dy,
        tester.getTopLeft(find.text('Glucose at finish')).dy,
      );
      expect(
        tester.getTopLeft(find.text('162')).dy,
        tester.getTopLeft(find.text('107')).dy,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
