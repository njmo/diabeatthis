import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_controller.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_local_gate.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_runtime.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_settings_store.dart';
import 'package:diabeatthis/common/family_chat/domain/family_chat_preferences.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_settings_section.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements FamilyChatApi {
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
  String familyId = 'family', epoch = 'epoch';
  int historyGeneration = 0;
  bool canManage = true, configured = true, offline = false, loseReply = false;
  bool founder = false;
  Future<void> Function()? beforeGet, beforeConfigure;
  final writes = <Map<String, Object?>>[];
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    if (offline) throw const CallableFailure('unavailable');
    if (name == 'getFamilyChatConfig') {
      await beforeGet?.call();
      return Map<String, dynamic>.from(
        jsonDecode(
              jsonEncode({
                'uid': 'child',
                'familyId': familyId,
                'epoch': epoch,
                'historyGeneration': historyGeneration,
                'account': account,
                'policy': policy,
                'canManage': canManage,
                'policyConfigured': configured,
                'members': [
                  if (founder) {'uid': 'child', 'role': 'child'},
                  {'displayName': 'PRIVATE_ROSTER_NAME'},
                ],
              }),
            )
            as Map,
      );
    }
    if (name != 'configureFamilyChat') throw StateError(name);
    writes.add(Map.of(data));
    await beforeConfigure?.call();
    if (data['initializeIfAbsent'] == true && configured) {
      return {'ok': true, 'initialized': false};
    }
    final own = data.containsKey('accountEnabled');
    final value = own ? account : policy;
    if (value['revision'] != data['expectedRevision']) {
      throw const CallableFailure('rejected', rejectionCode: 'already-exists');
    }
    if (data.containsKey('familyEnabled')) {
      throw StateError('Removed family toggle');
    }
    final enabled = data['accountEnabled'];
    if (enabled is bool) {
      if (value['enabled'] == true && !enabled) value['offGeneration']++;
      value['enabled'] = enabled;
    }
    if (!own && data['retention'] != null) {
      policy['retention'] = data['retention'];
    }
    value['revision']++;
    if (!own) configured = true;
    if (loseReply) {
      loseReply = false;
      offline = true;
      throw const CallableFailure('unavailable');
    }
    return {'ok': true};
  }
}

class _DelayedStore extends FamilyChatSettingsStore {
  _DelayedStore(super.db);
  final entered = Completer<void>(), gate = Completer<void>();
  bool hold = true;
  @override
  Future<Map<String, dynamic>> update(
    String uid,
    FutureOr<void> Function(Map<String, dynamic>) change,
  ) async {
    final result = await super.update(uid, change);
    if (hold) {
      hold = false;
      entered.complete();
      await gate.future;
    }
    return result;
  }
}

class _FailingStore extends FamilyChatSettingsStore {
  _FailingStore(super.db);
  bool fail = false;
  @override
  Future<Map<String, dynamic>> update(
    String uid,
    FutureOr<void> Function(Map<String, dynamic>) change,
  ) {
    if (fail) throw StateError('Storage unavailable');
    return super.update(uid, change);
  }
}

void main() {
  late FamilyChatDatabase db;
  late FamilyChatSettingsStore store;
  late _Api api;
  late FamilyChatSettingsController controller;
  FamilyChatSettingsRuntime? wrapper;
  late List<bool> local;
  late bool guardOpen;
  var failOpening = false;
  String? uid;
  FamilyChatSettingsController create() => FamilyChatSettingsController(
    uid: 'child',
    api: api,
    store: store,
    currentUid: () => uid,
    readRevocation: () => db.fence.accountRevocation('child'),
    closeAdmission: (revoke) async {
      guardOpen = false;
      if (revoke) return db.fence.revokeAccount('child');
      final expected = await db.fence.read();
      final token = await db.fence.accountRevocation('child');
      if (await db.fence.block(expected: expected) == null) {
        throw StateError('Admission changed');
      }
      return token;
    },
    applyLocal: (value) async {
      guardOpen = false;
      if (value == FamilyChatSettingsAdmission.open) {
        if (failOpening) throw StateError('Crash before clearing OFF');
        final token = await db.fence.accountRevocation('child');
        if (token != null) {
          final accepted = controller.state['opening']?['token'];
          if (accepted is! String ||
              !await db.fence.clearAccountRevocation('child', accepted)) {
            throw StateError('A newer OFF exists');
          }
        }
        await db.activateChat(
          'child',
          jsonEncode(['child', 'family', 'epoch']),
          'settings',
        );
        guardOpen = (await db.activeChat())['enabled'] == true;
      } else {
        await db.fence.block();
      }
      local.add(guardOpen);
    },
  );
  setUp(() async {
    wrapper = null;
    db = FamilyChatDatabase(NativeDatabase.memory());
    store = FamilyChatSettingsStore(db);
    api = _Api();
    local = [];
    guardOpen = false;
    failOpening = false;
    uid = 'child';
    controller = create();
  });
  tearDown(() async {
    if (wrapper != null) {
      wrapper!.dispose();
    } else {
      controller.dispose();
    }
    await db.close();
  });
  Future<void> start() async {
    await controller.start();
    await controller.synchronize();
  }

  test(
    'fresh settings durably advance only the matching history scope',
    () async {
      const scope = '["child","family","epoch"]';
      const otherScope = '["child","family","other-epoch"]';
      await start();
      final message = {
        'id': 'prior',
        'sequence': 1,
        'senderUid': 'mom',
        'sentAt': 1,
        'historyGeneration': 0,
      };
      await db.saveMessage(scope, 'family', message);
      await db.saveMessage(otherScope, 'family', message);
      api.historyGeneration = 1;
      await controller.synchronize();
      expect((await store.read('child'))['confirmed']['historyGeneration'], 1);
      expect((await db.historyState(scope))['minimum'], 1);
      expect(await db.message(scope, 'prior'), isNull);
      expect(await db.message(otherScope, 'prior'), isNotNull);
      expect(await db.saveMessage(scope, 'family', message), isFalse);
    },
  );

  test('offline settings restart refuses an older history cache', () async {
    await start();
    await db.setMetadata('account:child', {
      ...controller.confirmed!,
      '_observedLocalAt': 0,
      '_lastServerNow': 0,
    });
    api.historyGeneration = 1;
    await controller.synchronize();
    controller.dispose();
    controller = create();
    api.offline = true;
    final runtime = FamilyChatSettingsRuntime(
      controller: controller,
      db: db,
      currentUid: () => uid,
      configured: true,
      observeLifecycle: false,
      draft: const FamilyChatPreferences(),
    );
    wrapper = runtime;
    await runtime.start();
    await runtime.pump();
    expect(controller.mayUseCachedRead, isTrue);
    expect(runtime.allowSession, isFalse);
    await db.setMetadata('account:child', {
      ...(await db.metadata('account:child'))!,
      'historyGeneration': 1,
    });
    await runtime.pump();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.cachedOnly, isTrue);
  });

  for (final locale in ['pl', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'settings show only personal participation and shared retention at narrow width: $locale dark=$dark',
        (tester) async {
          await tester.runAsync(start);
          wrapper = FamilyChatSettingsRuntime(
            controller: controller,
            db: db,
            currentUid: () => uid,
            configured: true,
            draft: const FamilyChatPreferences(),
            observeLifecycle: false,
          );
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                familyChatSettingsRuntimeProvider.overrideWithValue(wrapper),
              ],
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.5),
                  ),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: FamilyChatSettingsSection(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(
            find.byType(FamilyChatSettingsSection),
          );
          expect(find.byType(SwitchListTile), findsOneWidget);
          expect(find.text('Conversations for the whole family'), findsNothing);
          expect(find.text('Rozmowy całej rodziny'), findsNothing);
          expect(
            find.text(context.lang.familyChatRefreshSettings),
            findsNothing,
          );
          expect(
            find.byType(DropdownButtonFormField<ChatRetention>),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  test(
    'real local gate preserves held cache and cancels unapplied intentions on OFF',
    () async {
      controller.dispose();
      final cancelled = <String>[];
      final gate = FamilyChatSettingsLocalGate(
        uid: 'child',
        db: db,
        store: store,
        currentUid: () => uid,
        controller: () => controller,
        cancelClinical: (owner) async {
          cancelled.add(owner);
        },
        cancelNotification: (_) async {},
      );
      controller = FamilyChatSettingsController(
        uid: 'child',
        api: api,
        store: store,
        currentUid: () => uid,
        applyLocal: gate.apply,
        closeAdmission: gate.closeAdmission,
        readRevocation: () => db.fence.accountRevocation('child'),
      );
      const scope = '["child","family","epoch"]';
      await db.saveDraft(scope, 'mom', 'Private pending text');
      api.offline = true;
      await start();
      expect(await db.draft(scope, 'mom'), 'Private pending text');
      expect(cancelled, isEmpty);
      api.offline = false;
      await controller.synchronize();
      expect(controller.readyForRuntime, true);
      await controller.setAccountEnabled(false);
      await controller.synchronize();
      expect(controller.readyForRuntime, false);
      expect(await db.draft(scope, 'mom'), '');
      expect(cancelled, contains('child'));
      expect(await db.fence.accountRevocation('child'), isNotNull);
    },
  );

  test(
    'setup pending choices do not mutate remote account before commit',
    () async {
      final runtime = FamilyChatSettingsRuntime(
        controller: controller,
        db: db,
        currentUid: () => uid,
        configured: true,
        observeLifecycle: false,
        draft: const FamilyChatPreferences()
            .copyWith(enabled: false)
            .asPendingSetup(),
      );
      wrapper = runtime;
      await runtime.start();
      await runtime.pump();
      expect(api.writes, isEmpty);
      expect(runtime.allowSession, false);
      runtime.setDraft(runtime.draft.committedSetup());
      await runtime.pump();
      expect(api.account['enabled'], false);
      expect(runtime.allowSession, false);
    },
  );

  test(
    'policy draft marker is bound to family epoch and initializes a new founder scope',
    () async {
      api.founder = true;
      final runtime = FamilyChatSettingsRuntime(
        controller: controller,
        db: db,
        currentUid: () => uid,
        configured: true,
        observeLifecycle: false,
        draft: const FamilyChatPreferences(retention: ChatRetention.month),
      );
      wrapper = runtime;
      await runtime.start();
      await runtime.pump();
      expect(api.writes, isEmpty);
      api.familyId = 'new-family';
      api.epoch = 'new-epoch';
      api.configured = false;
      api.policy['revision'] = 0;
      await runtime.pump();
      await runtime.pump();
      expect(
        api.writes.where((value) => value['initializeIfAbsent'] == true),
        hasLength(1),
      );
      expect(api.policy['retention'], 'month');
      expect(
        (await store.read('child'))['policyDraft'],
        contains('new-family'),
      );
    },
  );

  test(
    'a previous setup verification cannot open a later configured generation',
    () async {
      final runtime = FamilyChatSettingsRuntime(
        controller: controller,
        db: db,
        currentUid: () => uid,
        configured: false,
        observeLifecycle: false,
        draft: const FamilyChatPreferences(),
      );
      wrapper = runtime;
      await runtime.start();
      await controller.synchronize();
      var calls = 0;
      final oldEntered = Completer<void>(), oldRelease = Completer<void>();
      final newEntered = Completer<void>(), newRelease = Completer<void>();
      api.beforeGet = () async {
        calls++;
        if (calls == 2) {
          oldEntered.complete();
          await oldRelease.future;
        } else if (calls >= 3) {
          if (!newEntered.isCompleted) newEntered.complete();
          await newRelease.future;
        }
      };
      runtime.setConfigured(true);
      await oldEntered.future.timeout(const Duration(seconds: 3));
      runtime.setConfigured(false);
      runtime.setConfigured(true);
      var prematurelyOpened = false;
      runtime.addListener(() {
        if (!newRelease.isCompleted && runtime.allowSession) {
          prematurelyOpened = true;
        }
      });
      oldRelease.complete();
      await newEntered.future.timeout(const Duration(seconds: 3));
      expect(runtime.allowSession, false);
      expect(prematurelyOpened, false);
      newRelease.complete();
      await runtime.pump();
      expect(runtime.allowSession, true);
    },
  );

  test(
    'mutations and verification cannot race startup reconstruction',
    () async {
      expect(() => controller.setAccountEnabled(false), throwsStateError);
      expect(
        () => controller.setFamilyPolicy(retention: ChatRetention.day),
        throwsStateError,
      );
      expect(
        () => controller.initializeFounder(ChatRetention.day),
        throwsStateError,
      );
      await controller.synchronize();
      expect(api.writes, isEmpty);
      expect(await store.read('child'), isEmpty);
      await start();
      expect(controller.initialized, true);
    },
  );

  test(
    'startup stays closed until fresh authority and stores no roster content',
    () async {
      final gate = Completer<void>();
      api.beforeGet = () => gate.future;
      await controller.start();
      expect(local, [false]);
      expect(controller.localAllowed, false);
      gate.complete();
      await controller.synchronize();
      expect(controller.localAllowed, true);
      expect(local.last, true);
      expect(
        jsonEncode(await store.read('child')),
        isNot(contains('PRIVATE_ROSTER_NAME')),
      );
    },
  );
  test('a held older store response cannot erase a newer local OFF', () async {
    controller.dispose();
    final delayed = _DelayedStore(db);
    store = delayed;
    controller = create();
    await controller.start();
    await delayed.entered.future;
    await controller.setAccountEnabled(false);
    delayed.gate.complete();
    await controller.synchronize();
    expect(api.account['enabled'], false);
    expect(controller.localAllowed, false);
    expect(local, everyElement(false));
    expect(controller.state['account'], isNull);
  });
  test(
    'OFF closes the independent fence before a held settings write',
    () async {
      controller.dispose();
      final delayed = _DelayedStore(db)..hold = false;
      store = delayed;
      controller = create();
      await start();
      expect(guardOpen, true);
      delayed.hold = true;
      final request = controller.setAccountEnabled(false);
      await delayed.entered.future;
      expect(guardOpen, false);
      expect((await db.activeChat())['enabled'], false);
      delayed.gate.complete();
      await request;
      await controller.synchronize();
      expect(controller.localAllowed, false);
    },
  );
  test(
    'failed OFF persistence never restores admission on a later refresh',
    () async {
      controller.dispose();
      final failing = _FailingStore(db);
      store = failing;
      controller = create();
      await start();
      failing.fail = true;
      await expectLater(controller.setAccountEnabled(false), throwsStateError);
      expect(guardOpen, false);
      expect(controller.admission, FamilyChatSettingsAdmission.revoked);
      failing.fail = false;
      await controller.synchronize();
      expect(guardOpen, false);
      expect(api.writes, isEmpty);
    },
  );

  test(
    'offline OFF remains locally closed and survives cache clearing/restart',
    () async {
      await start();
      api.offline = true;
      await controller.setAccountEnabled(false);
      await controller.synchronize();
      expect(local.last, false);
      expect(controller.state['account']['changes']['accountEnabled'], false);
      expect(controller.error, 'pending');
      await db.clearAccount('child');
      controller.dispose();
      controller = create();
      api.offline = false;
      await start();
      expect(api.account['enabled'], false);
      expect(controller.state['account'], isNull);
      expect(controller.localAllowed, false);
    },
  );

  test(
    'ON remains closed offline and opens only after authoritative confirmation',
    () async {
      api.account['enabled'] = false;
      await start();
      api.offline = true;
      await controller.setAccountEnabled(true);
      await controller.synchronize();
      expect(controller.localAllowed, false);
      expect(local, everyElement(false));
      api.offline = false;
      await controller.synchronize();
      expect(api.account['enabled'], true);
      expect(controller.localAllowed, true);
      expect(controller.state['account'], isNull);
    },
  );

  test(
    'lost OFF response reconciles without a duplicate write or lost pending intent',
    () async {
      await start();
      api.loseReply = true;
      await controller.setAccountEnabled(false);
      await controller.synchronize();
      expect(api.account['enabled'], false);
      expect(api.writes, hasLength(1));
      expect(controller.state['account'], isNotNull);
      controller.dispose();
      controller = create();
      api.offline = false;
      await start();
      expect(api.writes, hasLength(1));
      expect(controller.state['account'], isNull);
    },
  );

  test('an old OFF response cannot clear a superseding ON intent', () async {
    await start();
    final entered = Completer<void>(), gate = Completer<void>();
    api.beforeConfigure = () {
      if (!entered.isCompleted) entered.complete();
      return gate.future;
    };
    await controller.setAccountEnabled(false);
    await entered.future;
    await controller.setAccountEnabled(true);
    final id = controller.state['account']['id'];
    gate.complete();
    await controller.synchronize();
    expect(controller.state['account']['id'], id);
    expect(controller.state['account']['conflict'], 'revision');
    expect(controller.localAllowed, false);
    expect(api.writes, hasLength(1));
  });

  test(
    'a stale ON cannot override another device OFF; explicit retry uses fresh revision',
    () async {
      api.account['enabled'] = false;
      await start();
      api.account['revision'] = 2;
      api.account['offGeneration'] = 1;
      await controller.setAccountEnabled(true);
      await controller.synchronize();
      expect(controller.state['account']['conflict'], 'revision');
      expect(api.writes, isEmpty);
      expect(controller.localAllowed, false);
      await controller.setAccountEnabled(true);
      await controller.synchronize();
      expect(api.writes.single['expectedRevision'], 2);
      expect(controller.localAllowed, true);
    },
  );

  test('retention conflicts preserve the other caregiver choice', () async {
    await start();
    api.offline = true;
    await controller.setFamilyPolicy(retention: ChatRetention.day);
    await controller.synchronize();
    expect(controller.localAllowed, true);
    api.policy['retention'] = 'month';
    api.policy['revision'] = 1;
    api.offline = false;
    await controller.synchronize();
    expect(controller.state['policy']['conflict'], 'revision');
    expect(api.policy['retention'], 'month');
    expect(api.writes, isEmpty);
  });

  for (final newerOff in [false, true]) {
    test(
      'retired family OFF discard preserves a newer revocation: $newerOff',
      () async {
        controller.dispose();
        final gate = FamilyChatSettingsLocalGate(
          uid: 'child',
          db: db,
          store: store,
          currentUid: () => uid,
          controller: () => controller,
          cancelClinical: (_) async {},
          cancelNotification: (_) async {},
        );
        FamilyChatSettingsController realController() =>
            FamilyChatSettingsController(
              uid: 'child',
              api: api,
              store: store,
              currentUid: () => uid,
              applyLocal: gate.apply,
              closeAdmission: gate.closeAdmission,
              readRevocation: () => db.fence.accountRevocation('child'),
            );
        controller = realController();
        await store.update('child', (state) {
          state['policy'] = {
            'id': 'old-family-off',
            'familyId': api.familyId,
            'epoch': api.epoch,
            'expectedRevision': 0,
            'changes': {'familyEnabled': false},
          };
        });
        await start();
        api.offline = true;
        await expectLater(
          () => controller.setFamilyPolicy(retention: ChatRetention.day),
          throwsStateError,
        );
        expect(controller.state['policy']['legacyOff'], true);
        expect(controller.state['policy']['changes'], isEmpty);
        expect(controller.localAllowed, false);
        api.offline = false;
        await controller.synchronize();
        expect(api.writes, isEmpty);
        expect(api.policy['enabled'], true);
        expect(api.account['enabled'], true);
        String? newerToken;
        if (newerOff) {
          api.beforeGet = () async {
            api.beforeGet = null;
            newerToken = await db.fence.revokeAccount('child');
          };
        }
        await controller.discardPolicyConflict();
        await controller.synchronize();
        expect(controller.state['policy'], isNull);
        expect(controller.readyForRuntime, !newerOff);
        expect(await db.fence.accountRevocation('child'), newerToken);
        controller.dispose();
        controller = realController();
        await start();
        expect(controller.readyForRuntime, !newerOff);
        if (newerOff) {
          expect(api.account['enabled'], false);
          expect(await db.fence.accountRevocation('child'), newerToken);
        } else {
          expect(api.writes, isEmpty);
        }
      },
    );
  }

  test('pending policy cannot cross a family or membership change', () async {
    await start();
    api.offline = true;
    await controller.setFamilyPolicy(retention: ChatRetention.day);
    await controller.synchronize();
    api.familyId = 'other';
    api.epoch = 'new';
    api.offline = false;
    await controller.synchronize();
    expect(controller.state['policy']['conflict'], 'scope');
    expect(api.writes, isEmpty);
    expect(api.policy['enabled'], true);
    expect(controller.localAllowed, true);
  });

  test(
    'joining/default initialization never overwrites an existing family policy',
    () async {
      api.policy['retention'] = 'month';
      await start();
      await controller.initializeFounder(ChatRetention.day);
      await controller.synchronize();
      expect(api.writes, isEmpty);
      expect(api.policy['retention'], 'month');
      expect(controller.state['policy'], isNull);
    },
  );

  test('accepted ON survives a crash before token clearing', () async {
    await start();
    await controller.setAccountEnabled(false);
    await controller.synchronize();
    final token = await db.fence.accountRevocation('child');
    failOpening = true;
    await controller.setAccountEnabled(true);
    await controller.synchronize();
    expect(controller.state['opening']['token'], token);
    expect(controller.state['account'], isNull);
    expect(await db.fence.accountRevocation('child'), token);
    expect(controller.readyForRuntime, false);
    controller.dispose();
    controller = create();
    failOpening = false;
    await start();
    expect(controller.readyForRuntime, true);
    expect(guardOpen, true);
    expect(await db.fence.accountRevocation('child'), isNull);
  });
  test(
    'untracked OFF after an accepted ON reconstructs emergency OFF on restart',
    () async {
      await start();
      await controller.setAccountEnabled(false);
      await controller.synchronize();
      failOpening = true;
      await controller.setAccountEnabled(true);
      await controller.synchronize();
      final newer = await db.fence.revokeAccount('child');
      controller.dispose();
      controller = create();
      failOpening = false;
      await start();
      expect(api.account['enabled'], false);
      expect(await db.fence.accountRevocation('child'), newer);
      expect(controller.state['offAck']['token'], newer);
      expect(controller.readyForRuntime, false);
    },
  );
  test('held ON verification cannot adopt a later OFF token', () async {
    await start();
    await controller.setAccountEnabled(false);
    await controller.synchronize();
    final older = await db.fence.accountRevocation('child');
    final entered = Completer<void>(), release = Completer<void>();
    api.beforeGet = () {
      if (!entered.isCompleted) entered.complete();
      return release.future;
    };
    await controller.setAccountEnabled(true);
    await entered.future;
    final newer = await db.fence.revokeAccount('child');
    release.complete();
    await controller.synchronize();
    expect(controller.state['opening']['token'], older);
    expect(await db.fence.accountRevocation('child'), newer);
    expect(controller.readyForRuntime, false);
    expect(guardOpen, false);
  });
  test(
    'OFF→ON→OFF preserves the last local OFF during a held ON response',
    () async {
      await start();
      await controller.setAccountEnabled(false);
      await controller.synchronize();
      final entered = Completer<void>(), release = Completer<void>();
      api.beforeConfigure = () {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      await controller.setAccountEnabled(true);
      await entered.future;
      await controller.setAccountEnabled(false);
      final newest = await db.fence.accountRevocation('child');
      release.complete();
      await controller.synchronize();
      expect(api.account['enabled'], false);
      expect(await db.fence.accountRevocation('child'), newest);
      expect(controller.readyForRuntime, false);
    },
  );
  for (final changedScope in [false, true]) {
    test(
      'remote ON releases only acknowledged OFF in the same epoch: changed=$changedScope',
      () async {
        await start();
        await controller.setAccountEnabled(false);
        await controller.synchronize();
        final token = await db.fence.accountRevocation('child');
        if (changedScope) api.epoch = 'replacement';
        api.account['enabled'] = true;
        api.account['revision']++;
        await controller.synchronize();
        expect(controller.readyForRuntime, !changedScope);
        expect(guardOpen, !changedScope);
        expect(
          await db.fence.accountRevocation('child'),
          changedScope ? token : null,
        );
      },
    );
  }
  test('child settings are read-only for family policy', () async {
    api.canManage = false;
    await start();
    expect(
      () => controller.setFamilyPolicy(retention: ChatRetention.day),
      throwsStateError,
    );
    expect(api.writes, isEmpty);
  });

  test(
    'UID switch during a held settings response cannot persist or open it',
    () async {
      final entered = Completer<void>(), gate = Completer<void>();
      api.beforeGet = () {
        if (!entered.isCompleted) entered.complete();
        return gate.future;
      };
      await controller.start();
      await entered.future;
      uid = 'other';
      gate.complete();
      await controller.synchronize();
      expect(local, [false]);
      expect((await store.read('child'))['confirmed'], isNull);
      expect(api.writes, isEmpty);
    },
  );
}
