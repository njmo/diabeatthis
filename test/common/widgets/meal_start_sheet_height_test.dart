import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/meal_start/meal_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final keyboard in [0.0, 280.0]) {
    testWidgets(
      'caregiver sheet stays within three quarters with keyboard=$keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(430, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                      child: MealStartSheet(
                        maxHeightFactor: .75,
                        title: 'Context',
                        subtitle: 'Review',
                        body: Column(
                          children: List.generate(30, (i) => Text('Row $i')),
                        ),
                        actions: FilledButton(
                          onPressed: () {},
                          child: const Text('Send'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final material = find
            .descendant(
              of: find.byType(MealStartSheet),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getSize(material).height, lessThanOrEqualTo(600));
        await tester.scrollUntilVisible(
          find.text('Send'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(MealStartSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Send').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
