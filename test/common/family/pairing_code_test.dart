import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/demo_family_pairing_repository.dart';
import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/firebase_family_repository.dart';
import 'package:diabeatthis/common/family/pairing_code.dart';
import 'package:diabeatthis/common/family/presentation/family_pairing_code_dialog.dart';
import 'package:diabeatthis/common/family/presentation/family_pairing_qr_card.dart';
import 'package:diabeatthis/common/family/presentation/secure_family_panel.dart';
import 'package:diabeatthis/common/family/secure_family_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/localized_material_app.dart';

class _ManualCodeRepository implements SecureFamilyRepository {
  String? submittedCode;
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Stream<FamilyStatus> watchStatus() => Stream.value(const FamilyStatus());
  @override
  Future<void> requestJoinByCode(String code) async {
    submittedCode = code;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invitation supports an optional short code', () {
    const legacy = FamilyPairingInvitation(id: 'id', code: 'qr');
    const invitation = FamilyPairingInvitation(
      id: 'id',
      code: 'qr',
      shortCode: 'ABCD-1234',
    );
    expect(legacy.shortCode, isNull);
    expect(legacy.expiresAt, isNull);
    final deadline = DateTime.fromMillisecondsSinceEpoch(1800000000000);
    expect(
      FamilyPairingInvitation(
        id: 'id',
        code: 'qr',
        expiresAt: deadline,
      ).expiresAt,
      deadline,
    );
    expect(invitation.shortCode, 'ABCD-1234');
  });

  test('Crockford validation accepts formatting and aliases', () {
    for (final code in ['ABCD1234', ' abcd-1234 ', 'OIl0-1234']) {
      expect(isValidPairingCode(code), isTrue, reason: code);
    }
    for (final code in ['', 'ABCD123', 'ABCU-1234', 'ABCD!1234', ' ' * 33]) {
      expect(isValidPairingCode(code), isFalse, reason: code);
    }
  });

  test(
    'code redemption normalizes input, refreshes status and rejects invalid codes',
    () async {
      final calls = <String>[];
      final repository = FirebaseFamilyRepository(
        AuthenticatedCallableTransport(
          client: MockClient((request) async {
            calls.add(request.url.path);
            if (request.url.path == '/requestFamilyJoinByCode') {
              expect(jsonDecode(request.body), {
                'data': {'code': 'ABCD-1234'},
              });
              return http.Response('{"result":{}}', 200);
            }
            return http.Response('{"result":{"members":[]}}', 200);
          }),
          projectId: 'test',
          currentUid: () => 'parent',
          identity: () async =>
              const CallableIdentity('parent', 'token', 'app-check'),
        ),
      );
      addTearDown(repository.dispose);
      final subscription = repository.watchStatus().listen((_) {});
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      calls.clear();
      await repository.requestJoinByCode(' abcd-1234 ');
      expect(calls, ['/requestFamilyJoinByCode', '/getFamilyStatus']);
      for (final code in ['', 'ABCU1234', 'A' * 33]) {
        await expectLater(
          repository.requestJoinByCode(code),
          throwsA(isA<CallableFailure>()),
        );
      }
      expect(calls.length, 2);
    },
  );

  test('invitation reads the backend short code', () async {
    final repository = FirebaseFamilyRepository(
      AuthenticatedCallableTransport(
        client: MockClient(
          (_) async => http.Response(
            '{"result":{"id":"invite","revision":1,"token":"secret","shortCode":"ABCD-1234","expiresAt":1800000000000}}',
            200,
          ),
        ),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async =>
            const CallableIdentity('child', 'token', 'app-check'),
      ),
    );
    addTearDown(repository.dispose);
    final invitation = await repository.createInvitation(
      SetupDeviceMode.patient,
    );
    expect(invitation.shortCode, 'ABCD-1234');
    expect(
      invitation.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1800000000000),
    );
  });

  test('demo code simulates pairing', () async {
    final repository = DemoFamilyPairingRepository();
    addTearDown(repository.dispose);
    final invitation = await repository.createInvitation(
      SetupDeviceMode.patient,
    );
    expect(invitation.shortCode, 'DEMO-0001');
    await repository.requestJoinByCode(' dowolny kod demo ');
    expect(repository.members[SetupDeviceMode.caregiver], hasLength(1));
  });

  testWidgets('QR card displays and copies the short code', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: FamilyPairingQrCard(code: 'private-qr', shortCode: 'ABCD-1234'),
        ),
      ),
    );
    expect(find.text('ABCD-1234'), findsOneWidget);
    await tester.tap(find.text('Kopiuj kod'));
    await tester.pump();
    expect(copied, 'ABCD-1234');
    expect(find.text('Kod skopiowany'), findsOneWidget);
  });

  testWidgets('legacy QR card has no copy action', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(body: FamilyPairingQrCard(code: 'private-qr')),
      ),
    );
    expect(find.byIcon(Icons.copy), findsNothing);
  });

  testWidgets('caregiver submits manual code through repository', (
    tester,
  ) async {
    final repository = _ManualCodeRepository();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecureFamilyPanel(
              repository: repository,
              mode: SetupDeviceMode.caregiver,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wpisz kod ręcznie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'abcd1234');
    expect(find.text('ABCD-1234'), findsOneWidget);
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
    expect(repository.submittedCode, 'ABCD-1234');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('panel refreshes status after a failed operation', (
    tester,
  ) async {
    final repository = _ManualCodeRepository();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecureFamilyPanel(
              repository: repository,
              mode: SetupDeviceMode.caregiver,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<SecureFamilyPanelState>(
      find.byType(SecureFamilyPanel),
    );
    await state.run(() async {
      throw Exception('timeout');
    });
    await tester.pumpAndSettle();
    expect(repository.refreshes, 1);
    expect(state.busy, isFalse);
  });

  testWidgets('manual dialog validates and returns uppercase code', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showFamilyPairingCodeDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ABCU1234');
    await tester.tap(find.text('Dalej'));
    await tester.pump();
    expect(
      find.text('Wpisz poprawny 8-znakowy kod parowania.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'abcd1234');
    expect(find.text('ABCD-1234'), findsOneWidget);
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
    expect(result, 'ABCD-1234');
  });
}
