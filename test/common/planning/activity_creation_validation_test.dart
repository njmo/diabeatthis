import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final draftOnly in [false, true]) {
    testWidgets(
      'creation waits for submit before showing errors: draftOnly=$draftOnly',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activityDraftProvider.overrideWith(ActivityDraftNotifier.new),
              databaseProvider.overrideWith(
                (_) => throw StateError('No write for invalid form'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ActivityDefinitionSheet(draftOnly: draftOnly),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final language = AppLocalizations.of(
          tester.element(find.byType(ActivityDefinitionSheet)),
        );
        expect(find.text(language.activityNameRequired), findsNothing);
        expect(find.text(language.activityPercentageRequired), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('activity-name-field')),
          'W',
        );
        await tester.pumpAndSettle();
        expect(find.text(language.activityNameRequired), findsNothing);
        await tester.ensureVisible(find.text(language.commonCreate));
        await tester.tap(find.text(language.commonCreate));
        await tester.pumpAndSettle();
        expect(find.text(language.activityNameRequired), findsOneWidget);
        expect(
          find.text(language.activityPercentageRequired),
          findsNWidgets(2),
        );
        await tester.enterText(
          find.byKey(const ValueKey('activity-name-field')),
          'Walk',
        );
        await tester.pumpAndSettle();
        expect(find.text(language.activityNameRequired), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
