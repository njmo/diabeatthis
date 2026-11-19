import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_controller.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_runtime.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_settings_store.dart';
import 'package:diabeatthis/common/family_chat/domain/family_chat_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts settings traffic; serves the same config shape as the controller
/// tests.
class _SettingsApi implements FamilyChatApi {
  final account = <String, dynamic>{
    'enabled': true,
    'revision': 0,
    'offGeneration': 0,
  };
  final policy = <String, dynamic>{
    'enabled': true,
    'revision': 0,
    'offGeneration': 0,
    'retention': 'week',
  };
  int configCalls = 0;
  final writes = <Map<String, Object?>>[];
  Completer<void>? configGate;
  Completer<void>? configEntered;

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    if (name == 'getFamilyChatConfig') {
      configCalls++;
      final gate = configGate;
      if (gate != null) {
        configGate = null;
        configEntered?.complete();
        await gate.future;
      }
      return Map<String, dynamic>.from(
        jsonDecode(
              jsonEncode({
                'uid': 'child',
                'familyId': 'family',
                'epoch': 'epoch',
                'historyGeneration': 0,
                'account': account,
                'policy': policy,
                'canManage': true,
                'policyConfigured': true,
                'members': [
                  {'displayName': 'PRIVATE_ROSTER_NAME'},
                ],
              }),
            )
            as Map,
      );
    }
    if (name != 'configureFamilyChat') throw StateError(name);
    writes.add(Map.of(data));
    final enabled = data['accountEnabled'];
    if (enabled is bool) {
      if (account['enabled'] == true && !enabled) account['offGeneration']++;
      account['enabled'] = enabled;
      account['revision']++;
    }
    return {'ok': true};
  }
}

FamilyStatus _status(List<String> memberIds) => FamilyStatus(
  members: [
    for (final id in memberIds)
      FamilyPairingMember(
        id: id,
        displayName: 'Member $id',
        role: FamilyMemberRole.caregiver,
        invitationId: 'invite-$id',
      ),
  ],
);

void main() {
  late FamilyChatDatabase db;
  late _SettingsApi api;
  late FamilyChatSettingsRuntime runtime;
  late DateTime now;

  setUp(() async {
    db = FamilyChatDatabase(NativeDatabase.memory());
    api = _SettingsApi();
    now = DateTime(2026, 11, 19, 12);
    final controller = FamilyChatSettingsController(
      uid: 'child',
      api: api,
      store: FamilyChatSettingsStore(db),
      currentUid: () => 'child',
      readRevocation: () => db.fence.accountRevocation('child'),
      closeAdmission: (revoke) async =>
          revoke ? db.fence.revokeAccount('child') : null,
      applyLocal: (_) async {},
    );
    runtime = FamilyChatSettingsRuntime(
      controller: controller,
      db: db,
      currentUid: () => 'child',
      configured: true,
      observeLifecycle: false,
      draft: const FamilyChatPreferences(),
      clock: () => now,
    );
    await runtime.start();
  });

  tearDown(() async {
    runtime.dispose();
    await db.close();
  });

  // Emits [status] every 3 s for [seconds], like the family-status stream,
  // through the same entry point the provider subscription uses.
  Future<void> emitEvery3s(FamilyStatus status, int seconds) async {
    for (var t = 0; t < seconds; t += 3) {
      await runtime.statusChanged(status);
      now = now.add(const Duration(seconds: 3));
    }
  }

  test(
    'an explicit pump with an unchanged draft fetches config once',
    () async {
      final before = api.configCalls;
      await runtime.pump();
      expect(api.configCalls - before, 1);
      expect(api.writes, isEmpty);
    },
  );

  test(
    'a minute of unchanged ~3 s status emissions stays within the freshness bound',
    () async {
      final status = _status(['mom']);
      final before = api.configCalls;
      // 21 emissions (t = 0..60 s); previously each cost two config fetches.
      await emitEvery3s(status, 63);
      final calls = api.configCalls - before;
      // First emission + one refresh per 30 s of unchanged status.
      expect(calls, inInclusiveRange(2, 3));
      expect(calls, lessThan(21));
    },
  );

  test(
    'remote account OFF without membership change is still observed',
    () async {
      final status = _status(['mom']);
      await runtime.statusChanged(status);
      expect(runtime.controller.confirmed!['account']['enabled'], true);
      // Another device turns the account off; membership never changes.
      api.account
        ..['enabled'] = false
        ..['revision'] = 1
        ..['offGeneration'] = 1;
      await emitEvery3s(status, 33);
      expect(runtime.controller.confirmed!['account']['enabled'], false);
      expect(runtime.controller.admission, FamilyChatSettingsAdmission.revoked);
    },
  );

  test('a membership change bypasses the throttle immediately', () async {
    await runtime.statusChanged(_status(['mom']));
    now = now.add(const Duration(seconds: 3));
    await runtime.statusChanged(_status(['mom']));
    final before = api.configCalls;
    now = now.add(const Duration(seconds: 3));
    await runtime.statusChanged(_status(['mom', 'dad']));
    expect(api.configCalls - before, 1);
  });

  test(
    'unchanged emissions join an in-flight pump; a change queues one rerun',
    () async {
      await runtime.statusChanged(_status(['mom']));
      now = now.add(const Duration(seconds: 31));
      api
        ..configGate = Completer<void>()
        ..configEntered = Completer<void>();
      final gate = api.configGate!;
      final before = api.configCalls;
      final first = runtime.statusChanged(_status(['mom']));
      try {
        await api.configEntered!.future.timeout(const Duration(seconds: 5));
        final joined = runtime.statusChanged(_status(['mom']));
        final joinedAgain = runtime.statusChanged(_status(['mom']));
        expect(identical(joined, first), true);
        expect(identical(joinedAgain, first), true);
        // A membership change during the pump is not lost.
        final changed = runtime.statusChanged(_status(['mom', 'dad']));
        expect(identical(changed, first), true);
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
      await first;
      expect(api.configCalls - before, 2);
    },
  );

  test(
    'explicit settings commands never wait behind the status throttle',
    () async {
      await runtime.statusChanged(_status(['mom']));
      now = now.add(const Duration(seconds: 3));
      await runtime.statusChanged(_status(['mom']));
      await runtime.controller.setAccountEnabled(false);
      await runtime.controller.synchronize();
      expect(api.writes.single['accountEnabled'], false);
      expect(api.account['enabled'], false);
    },
  );
}
