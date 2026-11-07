import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_collections_body.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_plan_status_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'meal history shows rejected status and retries the preserved proposal on the shared row',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final client = MockClient(
        (_) async => throw StateError('No network needed'),
      );
      addTearDown(client.close);
      final family = FamilyPlanningController(
        AuthenticatedCallableTransport(
          client: client,
          projectId: 'test',
          currentUid: () => 'parent',
          identity: () async =>
              const CallableIdentity('parent', 'token', 'appcheck'),
        ),
        () => 'parent',
        FamilyPlanSubmissionStore(db),
      );
      addTearDown(family.dispose);
      family.rows['meals/7'] = {
        'kind': 'meals',
        'id': '7',
        'payload': {
          'id': 7,
          'name': 'Original',
          'status': 'planned',
          'purpose': 'meal',
          'planned_at': DateTime.now().millisecondsSinceEpoch,
        },
      };
      family.plans = [
        {
          'type': 'updateMeal',
          'targetId': 7,
          'status': 'rejected',
          'createdAt': 1,
          'values': {
            'name': 'Proposed name',
            'plannedAt': 123,
            'ingredients': [],
          },
        },
      ];
      Map<String, dynamic>? retry;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyCollectionsBody(
                family: family,
                view: FamilyPlanningView.meals,
                enabled: true,
                edit: (type, {targetId, initial}) async {
                  retry = initial;
                  expect(type, 'updateMeal');
                  expect(targetId, 7);
                },
                mealValues: (_) => {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyCollectionsBody)),
      );
      expect(find.text(language.familyPlanRejected), findsOneWidget);
      await tester.tap(find.text(language.familyPlanRetry));
      await tester.pumpAndSettle();
      expect(retry, {
        'name': 'Proposed name',
        'plannedAt': 123,
        'ingredients': [],
      });
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'targeted activity retry preserves type target and requested start',
    () async {
      final plans = <Map<String, dynamic>>[
        {
          'type': 'moveActivity',
          'targetId': 9,
          'status': 'rejected',
          'createdAt': 1,
          'values': {'startedAt': 123},
        },
      ];
      Map<String, dynamic>? sent;
      final retry = familyPlanRetryForRecord(plans, 'activityOccurrences', 9, (
        type, {
        targetId,
        initial,
      }) async {
        expect(type, 'moveActivity');
        expect(targetId, 9);
        sent = initial;
      });
      retry!();
      await Future<void>.delayed(Duration.zero);
      expect(sent, {'startedAt': 123});
    },
  );
}
