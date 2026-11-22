import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class HeldRefreshFamilyController extends FamilyPlanningController {
  HeldRefreshFamilyController(
    super.transport,
    super.currentUid,
    super.submissions,
  );
  final held = Completer<void>();
  bool refreshed = false;
  @override
  Future<void> refresh({void Function(String, int)? timing}) {
    refreshed = true;
    return held.future;
  }
}

void main() {
  test(
    'server receipt releases submit without waiting for a full family refresh',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final client = MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        return http.Response(
          jsonEncode({
            'result': {'id': data['id'], 'status': 'pending'},
          }),
          200,
        );
      });
      addTearDown(client.close);
      final family = HeldRefreshFamilyController(
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
      addTearDown(() {
        family.held.complete();
        family.dispose();
      });
      family.uid = 'parent';
      family.owner = 'child';
      family.source = 'a' * 32;
      family.complete = true;
      await family
          .submit(
            type: 'startActivity',
            targetId: null,
            values: {
              'activityId': 1,
              'startedAt': DateTime.now().millisecondsSinceEpoch,
            },
            baseRows: [
              {
                'kind': 'activities',
                'id': '1',
                'revision': 1,
                'payload': {'id': 1, 'name': 'Walk'},
              },
            ],
            expectedSource: 'a' * 32,
            expectedUid: 'parent',
          )
          .timeout(const Duration(seconds: 2));
      expect(family.refreshed, isTrue);
      expect(family.held.isCompleted, isFalse);
      expect(family.plans.single['status'], 'pending');
    },
  );
  testWidgets(
    'activity save immediately shows sending indicator while transport is pending',
    (tester) async {
      final held = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DashboardActivitySheet(
                initialActivity: const ActivityDraft.existing(
                  id: 1,
                  name: 'Walk',
                  percentagePre: 20,
                  percentagePost: 30,
                  durationMinutes: 30,
                ),
                submittingLabel: 'Sending to child…',
                onSubmit: (_) => held.future,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = AppLocalizations.of(
        tester.element(find.byType(DashboardActivitySheet)),
      );
      await tester.tap(find.text(language.activityStartNow));
      await tester.pump();
      expect(find.text('Sending to child…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      held.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
