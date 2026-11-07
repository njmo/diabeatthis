import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_record_page.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  for (final change in ['account', 'source', 'removed', 'incomplete']) {
    testWidgets('open family preview clears immediately on $change change', (
      tester,
    ) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      String? uid = 'parent';
      final transport = AuthenticatedCallableTransport(
        client: MockClient((_) async => throw StateError('No calls expected')),
        projectId: 'test',
        currentUid: () => uid,
        identity: () async =>
            const CallableIdentity('parent', 'token', 'check'),
      );
      final family =
          FamilyPlanningController(
              transport,
              () => uid,
              FamilyPlanSubmissionStore(db),
            )
            ..uid = uid
            ..owner = 'child'
            ..source = 'source-a'
            ..complete = true;
      for (final row in familyCollectionFixtures()) {
        family.rows['${row['kind']}/${row['id']}'] = row;
      }
      family.rows['mealIngredients/77'] = {
        'kind': 'mealIngredients',
        'id': '77',
        'deleted': true,
        'payload': null,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (_) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            databaseProvider.overrideWith(
              (_) => throw StateError('Read-only page accessed database'),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyRecordPage(family: family, kind: 'meals', id: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
      if (change == 'account') uid = null;
      if (change == 'source') family.source = 'source-b';
      if (change == 'removed') family.clear();
      if (change == 'incomplete') family.complete = false;
      family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      family.dispose();
      transport.client.close();
    });
  }
}
