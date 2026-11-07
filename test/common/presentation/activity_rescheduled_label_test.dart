import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_occurrence_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  for (final language in ['en', 'pl']) {
    testWidgets(
      'shared session card explains the original date in $language without a skipped duplicate',
      (tester) async {
        final start = DateTime.now().add(const Duration(days: 4));
        final original = start.subtract(const Duration(hours: 1));
        final strings = lookupAppLocalizations(Locale(language));
        final label = strings.activityRescheduledFrom(
          DateFormat.yMd(language).add_Hm().format(original),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ActivityOccurrenceView(
                startedAt: start.millisecondsSinceEpoch,
                originalStartedAt: original.millisecondsSinceEpoch,
                durationMinutes: 43,
                status: 'planned',
                recurring: true,
                name: 'Training',
                onMove: () {},
                onSkip: () {},
              ),
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
        expect(find.text(strings.activityScheduleSkipped), findsNothing);
        expect(find.text(strings.activityScheduleMove), findsOneWidget);
        expect(find.text(strings.activityScheduleNo), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
