import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_scope_guard.dart';
import 'package:diabeatthis/common/family_sync/presentation/show_family_ingredient_picker.dart';
import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_picker_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../../helpers/localized_material_app.dart';
import '../family_sync/family_meal_plan_form_test.dart'
    show FamilyPlanTestCatalog;
import '../presentation/family_collection_fixtures.dart';

void main() {
  for (final change in ['account', 'owner', 'source', 'dispose']) {
    testWidgets('an open family form hides old data after $change', (
      tester,
    ) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      String? uid = 'parent';
      final transport = AuthenticatedCallableTransport(
        client: MockClient((_) async => throw StateError('No network')),
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
      final scope = FamilyAccessScope(family);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (_) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyScopeGuard(
              scope: scope,
              child: const Scaffold(body: Text('Child ingredient')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Child ingredient'), findsOneWidget);
      if (change == 'account') uid = null;
      if (change == 'owner') family.owner = 'other-child';
      if (change == 'source') family.source = 'source-b';
      if (change == 'dispose') {
        family.dispose();
      } else {
        family.notifyListeners();
      }
      await tester.pumpAndSettle();
      expect(find.text('Child ingredient'), findsNothing);
      expect(scope.requireCurrent, throwsStateError);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (!family.disposed) family.dispose();
      transport.client.close();
    });
  }
  for (final picker in ['ingredient', 'activity']) {
    for (final change in ['source', 'dispose']) {
      testWidgets(
        'open $picker picker hides old data after $change without using a disposed scope',
        (tester) async {
          final db = DatabaseImpl(NativeDatabase.memory());
          addTearDown(db.close);
          final transport = AuthenticatedCallableTransport(
            client: MockClient((_) async => throw StateError('No network')),
            projectId: 'test',
            currentUid: () => 'parent',
            identity: () async =>
                const CallableIdentity('parent', 'token', 'check'),
          );
          final family =
              FamilyPlanningController(
                  transport,
                  () => 'parent',
                  FamilyPlanSubmissionStore(db),
                )
                ..uid = 'parent'
                ..owner = 'child'
                ..source = 'a'
                ..complete = true;
          final scope = FamilyAccessScope(family);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                googleAccountProvider.overrideWith(
                  (_) => Stream.value(const GoogleAccount(uid: 'parent')),
                ),
              ],
              child: localizedMaterialApp(
                home: FamilyScopeGuard(
                  scope: scope,
                  child: ProviderScope(
                    overrides: [
                      activityDraftProvider.overrideWith(
                        ActivityDraftNotifier.new,
                      ),
                      activitiesByQueryProvider.overrideWith(
                        (_, _) async => const [
                          Activity(
                            id: 1,
                            name: 'Private activity',
                            percentagePre: 80,
                            percentagePost: 90,
                            durationMinutes: 30,
                          ),
                        ],
                      ),
                    ],
                    child: Builder(
                      builder: (context) => Scaffold(
                        body: FilledButton(
                          onPressed: () {
                            if (picker == 'ingredient') {
                              showFamilyIngredientPicker(
                                context,
                                rows: familyCollectionFixtures(),
                                catalog: FamilyPlanTestCatalog(),
                              );
                            } else {
                              showActivityPickerSheet(
                                context,
                                allowCreate: false,
                              );
                            }
                          },
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final privateName = picker == 'ingredient'
              ? 'Apple'
              : 'Private activity';
          if (picker == 'ingredient') {
            await tester.enterText(find.byType(TextField).first, 'App');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pumpAndSettle();
          }
          expect(find.text(privateName), findsOneWidget);
          if (change == 'dispose') {
            family.dispose();
          } else {
            family.source = 'b';
            family.notifyListeners();
          }
          await tester.pumpAndSettle();
          expect(find.text(privateName), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          if (!family.disposed) family.dispose();
          transport.client.close();
        },
      );
    }
  }
}
