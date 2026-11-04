import 'package:diabeatthis/common/widgets/form_step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'context progress stays horizontal with single-line labels at scale $scale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const SizedBox(
                  width: 379,
                  child: FormStepHeader(
                    labelsBelowMarkers: true,
                    currentStep: 0,
                    labels: [
                      'Kontekst',
                      'Produkty',
                      'Gramatura',
                      'Podsumowanie',
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final points = [
          'Kontekst',
          'Produkty',
          'Gramatura',
          'Podsumowanie',
        ].map((label) => tester.getCenter(find.text(label))).toList();
        for (var i = 1; i < points.length; i++) {
          expect(points[i].dx, greaterThan(points[i - 1].dx));
          expect((points[i].dy - points[0].dy).abs(), lessThan(5));
        }
        final summary = tester.widget<Text>(find.text('Podsumowanie'));
        expect(summary.softWrap, isFalse);
        expect(summary.maxLines, 1);
        expect(
          tester.widget<Text>(find.text('Kontekst')).style!.fontSize,
          greaterThan(
            tester.widget<Text>(find.text('Produkty')).style!.fontSize!,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
