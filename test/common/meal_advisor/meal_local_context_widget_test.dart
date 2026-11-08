import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/caregiver_meal_local_context.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
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
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
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
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        final accountSubscription = container.listen(
          googleAccountProvider,
          (_, _) {},
        );
        addTearDown(accountSubscription.close);
        await tester.pump();
        final controller = container.read(
          mealDecisionDemoControllerProvider.notifier,
        );
        await controller.send(
          'meal',
          'Untrusted request name',
          mealId: 2,
          childOwner: 'child-a',
          mirrorSource: 'source-a',
        );
        final id = container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .id;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showCaregiverMealDecisionDemo(
                      context,
                      requestKey: 'meal',
                      requestId: id,
                      caregiverName: 'Anna',
                      familyScope: FamilyAccessScope(family),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (wrongChild) {
          expect(find.byType(CaregiverMealLocalContext), findsNothing);
          expect(nightscout.glucoseWindows, isEmpty);
          expect(
            container
                .read(mealDecisionDemoControllerProvider)['meal']!
                .claimedById,
            isNull,
          );
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
        container.dispose();
        disposed = true;
      },
    );
  }
}
