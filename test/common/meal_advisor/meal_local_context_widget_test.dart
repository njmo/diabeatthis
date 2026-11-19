import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/caregiver_meal_local_context.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../history/nightscout_statistics_fixture.dart';
import '../presentation/family_collection_fixtures.dart';

void main() {
  for (final wrongChild in [false, true]) {
    testWidgets(
      'caregiver context reads its own mirror and history, rejecting a colliding meal ID in a different child: $wrongChild',
      (tester) async {
        LanguageStrings.setSelectedLocale(const Locale('en'));
        addTearDown(() => LanguageStrings.setSelectedLocale(null));
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final transport = AuthenticatedCallableTransport(
          client: MockClient(
            (_) async => throw StateError('No calls expected'),
          ),
          projectId: 'test',
          currentUid: () => 'parent',
          identity: () async =>
              const CallableIdentity('parent', 'token', 'check'),
        );
        addTearDown(transport.client.close);
        final family =
            FamilyPlanningController(
                transport,
                () => 'parent',
                FamilyPlanSubmissionStore(db),
              )
              ..uid = 'parent'
              ..owner = wrongChild ? 'child-b' : 'child-a'
              ..source = 'source-a'
              ..complete = true;
        addTearDown(family.dispose);
        for (final row in familyCollectionFixtures()) {
          family.rows['${row['kind']}/${row['id']}'] = row;
        }
        final nightscout = StatisticsNightscout();
        final container = ProviderContainer(
          overrides: [
            caregiverVisibleStateProvider.overrideWithValue(
              const CaregiverRefreshState(),
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No patient database reads'),
            ),
            nightscoutRepositoryProvider.overrideWith(
              (ref) async => nightscout,
            ),
          ],
        );
        addTearDown(container.dispose);
        final request = MealDecisionRemoteRequest({
          'id': 'request-a',
          'mealId': '2',
          'mealName': 'Untrusted request name',
          'ownerUid': 'child-a',
          'sourceId': 'source-a',
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListenableBuilder(
                  listenable: family,
                  builder: (_, _) {
                    final scope = caregiverMealDecisionContextScope(
                      family,
                      request,
                    );
                    return scope == null
                        ? const SizedBox.shrink()
                        : SingleChildScrollView(
                            child: CaregiverMealLocalContext(
                              scope: scope,
                              mealId: request.mealId,
                            ),
                          );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (wrongChild) {
          expect(find.byType(CaregiverMealLocalContext), findsNothing);
          expect(nightscout.glucoseWindows, isEmpty);
          expect(nightscout.deviceWindows, isEmpty);
          expect(nightscout.treatmentWindows, isEmpty);
        } else {
          expect(find.byType(CaregiverMealLocalContext), findsOneWidget);
          expect(find.widgetWithText(ListTile, 'Lunch'), findsOneWidget);
          expect(nightscout.glucoseWindows, hasLength(1));
          expect(nightscout.deviceWindows, hasLength(1));
          expect(nightscout.treatmentWindows, hasLength(1));
          expect(find.text('102'), findsNothing);
          family.source = 'source-b';
          family.notifyListeners();
          await tester.pumpAndSettle();
          expect(find.byType(CaregiverMealLocalContext), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
