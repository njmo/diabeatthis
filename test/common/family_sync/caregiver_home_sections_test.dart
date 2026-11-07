import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planning_page.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('caregiver home has no technical section headings', (
    tester,
  ) async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          googleAccountProvider.overrideWith((_) => Stream.value(null)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: FamilyPlanningPage(
              embedded: true,
              view: FamilyPlanningView.home,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lang = AppLocalizations.of(
      tester.element(find.byType(FamilyPlanningPage)),
    );
    expect(find.text(lang.familySyncMeals), findsNothing);
    expect(find.text(lang.familySyncActivityOccurrences), findsNothing);
    expect(find.text(lang.familyPlanRequests), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
