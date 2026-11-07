import 'dart:async';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/details/nightscout_record_history.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nightscout_statistics_fixture.dart';

void main() {
  testWidgets(
    'keeps record details accessible while loading and on sanitized failure, supports retry',
    (tester) async {
      final first = Completer<String?>();
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nightscoutRepositoryProvider.overrideWith(
              (ref) async => StatisticsNightscout(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: NightscoutRecordHistory<String>(
                recordKey: 'family/record',
                fallback: const Text('Recorded activity details'),
                load: (ref, history) =>
                    ++calls == 1 ? first.future : Future.value('Statistics'),
                builder: (data) => Text(data),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Recorded activity details'), findsOneWidget);
      first.completeError(StateError('secret-token@example.test'));
      await tester.pumpAndSettle();
      expect(find.text('Recorded activity details'), findsOneWidget);
      expect(find.textContaining('secret-token'), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Statistics'), findsOneWidget);
      expect(calls, 2);
    },
  );

  testWidgets(
    'changing record scope discards both completed and late previous results',
    (tester) async {
      final old = Completer<String?>();
      final latest = Completer<String?>();
      var scope = 'first';
      late StateSetter update;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nightscoutRepositoryProvider.overrideWith(
              (ref) async => StatisticsNightscout(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final current = scope;
                  return NightscoutRecordHistory<String>(
                    recordKey: current,
                    load: (ref, history) =>
                        current == 'first' ? old.future : latest.future,
                    builder: (data) => Text(data),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      update(() => scope = 'second');
      await tester.pump();
      old.complete('Other child statistics');
      await tester.pump();
      expect(find.text('Other child statistics'), findsNothing);
      latest.complete('Current child statistics');
      await tester.pumpAndSettle();
      expect(find.text('Current child statistics'), findsOneWidget);
    },
  );
}
