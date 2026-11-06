import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'family_plan_apply_test.dart' show localPlan, seedPlanIngredient;

void main() {
  test(
    'journal created during registration prevents later batch from exposing unbound result',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final plan = await localPlan(db, 'createMeal');
      final entered = Completer<void>();
      final release = Completer<void>();
      var publishes = 0;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          if (request.url.path.endsWith('registerFamilyMirror')) {
            entered.complete();
            await release.future;
            return http.Response(
              jsonEncode({
                'result': {'sourceId': plan['sourceId']},
              }),
              200,
            );
          }
          publishes++;
          throw StateError('New result was exposed before reservation');
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );
      final upload = PublishFamilyMirrorUseCase(
        outbox: FamilyMirrorOutbox(db),
        transport: transport,
        currentUid: () => 'child',
      )();
      await entered.future;
      await ApplyFamilyPlanUseCase(db)('child', plan);
      release.complete();
      expect(await upload, 0);
      expect(publishes, 0);
      expect(
        (await FamilyMirrorOutbox(db).pending()).any((r) => r.kind == 'meals'),
        true,
      );
    },
  );
}
