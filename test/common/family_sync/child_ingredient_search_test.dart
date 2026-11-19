import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/child_ingredient_search_repository.dart';
import 'package:diabeatthis/common/family_sync/presentation/show_family_ingredient_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/localized_material_app.dart';
import 'family_meal_plan_form_test.dart' show FamilyPlanTestCatalog;

const childResult = {
  'kind': 'ingredients',
  'id': '12',
  'payload': {
    'name': 'Fantasia Maltesers',
    'brand': 'Danone',
    'carbs_per_100g': 14,
    'fat_per_100g': 3,
    'protein_per_100g': 2,
    'fiber_per_100g': 1,
  },
};

ChildIngredientSearchRepository repository(http.Client client) =>
    ChildIngredientSearchRepository(
      transport: AuthenticatedCallableTransport(
        client: client,
        projectId: 'test',
        identity: () async =>
            const CallableIdentity('parent', 'token', 'check'),
        currentUid: () => 'parent',
      ),
      caregiverUid: 'parent',
      childUid: 'child',
      isCurrent: () => true,
    );

http.Response mirrorResponse(String ownerUid) => http.Response(
  jsonEncode({
    'result': {
      'ownerUid': ownerUid,
      'records': [childResult],
    },
  }),
  200,
);

void main() {
  testWidgets('chat picker searches the child mirror after a typing pause', (
    tester,
  ) async {
    final queries = <Object?>[];
    final local = repository(
      MockClient((request) async {
        expect(request.url.path, '/searchFamilyMirrorIngredients');
        queries.add((jsonDecode(request.body)['data'] as Map)['query']);
        return mirrorResponse('child');
      }),
    );
    ChildIngredientSearchItem? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  final item = await showFamilyIngredientSearchPicker(
                    context,
                    local: local,
                    catalog: FamilyPlanTestCatalog(),
                    queryDebounce: const Duration(milliseconds: 500),
                  );
                  selected = item as ChildIngredientSearchItem?;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fan');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'fantasia');
    await tester.pump(const Duration(milliseconds: 499));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(queries, ['fantasia']);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fantasia Maltesers'));
    await tester.pumpAndSettle();
    expect(selected?.ingredient.carbsPer100g, 14);
  });

  test('search rejects results from a different child', () async {
    final local = repository(MockClient((_) async => mirrorResponse('other')));
    await expectLater(local.search('fantasia'), throwsStateError);
  });

  test(
    'shortcut edit rows reject a response scoped to another child',
    () async {
      final local = repository(
        MockClient((request) async {
          expect(jsonDecode(request.body)['data'], {'quickFoodsEditor': true});
          return mirrorResponse('other');
        }),
      );
      await expectLater(local.quickTreatmentEditorRows(), throwsStateError);
    },
  );
}
