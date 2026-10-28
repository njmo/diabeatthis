import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_time_edit_dialog.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime(2026, 10, 28, 17),
    end = DateTime(2026, 10, 28, 21),
    now = DateTime(2026, 10, 28, 22);
Future<void> openEditor(
  WidgetTester tester, {
  required Future<void> Function(DateTime, DateTime) onSave,
  Locale locale = const Locale('pl'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ActivityLogTimeEditDialog(
                startedAt: start,
                endedAt: end,
                onSave: onSave,
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
}

void main() {
  for (final language in ['pl', 'en']) {
    testWidgets(
      'edits a completed end and saves once with $language localization',
      (tester) async {
        await withClock(Clock.fixed(now), () async {
          final l10n = lookupAppLocalizations(Locale(language));
          final gate = Completer<void>();
          final saved = <(DateTime, DateTime)>[];
          await openEditor(
            tester,
            locale: Locale(language),
            onSave: (start, end) async {
              saved.add((start, end));
              await gate.future;
            },
          );
          final field = tester.widget<ActivityLogTimeField>(
            find.byKey(const ValueKey('activity_log_end')),
          );
          final corrected = start.add(const Duration(hours: 1));
          field.onChanged(corrected);
          await tester.pump();
          await tester.tap(find.text(l10n.settingsSave));
          await tester.pump();
          expect(saved, [(start, corrected)]);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          gate.complete();
          await tester.pumpAndSettle();
          expect(find.byType(ActivityLogTimeEditDialog), findsNothing);
        });
      },
    );
  }
  testWidgets('invalid and future ranges stay open without writing', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final l10n = lookupAppLocalizations(const Locale('pl'));
      var calls = 0;
      await openEditor(
        tester,
        onSave: (_, _) async {
          calls++;
        },
      );
      for (final value in [start, now.add(const Duration(minutes: 1))]) {
        tester
            .widget<ActivityLogTimeField>(
              find.byKey(const ValueKey('activity_log_end')),
            )
            .onChanged(value);
        await tester.pump();
        await tester.tap(find.text(l10n.settingsSave));
        await tester.pumpAndSettle();
        expect(find.text(l10n.activityLogTimeInvalid), findsOneWidget);
        expect(calls, 0);
      }
    });
  });
  testWidgets(
    'save failure preserves edits and allows retry; cancel performs no write',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final l10n = lookupAppLocalizations(const Locale('pl'));
        var calls = 0;
        final corrected = start.add(const Duration(hours: 1));
        await openEditor(
          tester,
          onSave: (_, selectedEnd) async {
            calls++;
            expect(selectedEnd, corrected);
            if (calls == 1) throw StateError('Conflict');
          },
        );
        tester
            .widget<ActivityLogTimeField>(
              find.byKey(const ValueKey('activity_log_end')),
            )
            .onChanged(corrected);
        await tester.pump();
        await tester.tap(find.text(l10n.settingsSave));
        await tester.pumpAndSettle();
        expect(find.text(l10n.activityLogTimeSaveFailed), findsOneWidget);
        expect(
          tester
              .widget<ActivityLogTimeField>(
                find.byKey(const ValueKey('activity_log_end')),
              )
              .value,
          corrected,
        );
        await tester.tap(find.text(l10n.settingsSave));
        await tester.pumpAndSettle();
        expect(calls, 2);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settingsCancel));
        await tester.pumpAndSettle();
        expect(calls, 2);
      });
    },
  );
}
