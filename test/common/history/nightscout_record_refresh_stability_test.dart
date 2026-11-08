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
    'refresh retains content without a spinner and scope changes discard it',
    (tester) async {
      var scope = 'child-one';
      var revision = 0;
      final next = Completer<String?>();
      final other = Completer<String?>();
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
                  return NightscoutRecordHistory<String>(
                    recordKey: scope,
                    refreshKey: revision,
                    keepPreviousDuringRefresh: true,
                    load: (ref, history) => scope == 'child-two'
                        ? other.future
                        : revision == 0
                        ? Future.value('First context')
                        : next.future,
                    builder: (data) => Text(data),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First context'), findsOneWidget);
      final position = tester.getTopLeft(find.text('First context'));
      update(() => revision++);
      await tester.pump();
      expect(find.text('First context'), findsOneWidget);
      expect(tester.getTopLeft(find.text('First context')), position);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      next.complete('Updated context');
      await tester.pumpAndSettle();
      expect(find.text('Updated context'), findsOneWidget);
      update(() => scope = 'child-two');
      await tester.pump();
      expect(find.text('Updated context'), findsNothing);
      other.complete('Other child context');
      await tester.pumpAndSettle();
      expect(find.text('Other child context'), findsOneWidget);
    },
  );
}
