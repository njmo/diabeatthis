import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_controller.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_runtime.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_settings_store.dart';
import 'package:diabeatthis/common/family_chat/domain/family_chat_preferences.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;
const _uid = 'child';
const _scope = '["child","family","epoch"]';
const _targets = ['mom1', 'mom2', 'mom3', 'mom4', 'mom5', 'family'];

/// One backend shared by every device of the UID. Rate limits mirror
/// backend/family/common/chat_service.cjs `rate()`: fixed 60 s window per
/// UID and action, opened by the first call; overflow is a 429 that the
/// transport surfaces as `CallableFailure('unavailable')`.
class _Server {
  _Server(this.elapsed);
  final Duration Function() elapsed;
  int get now => 1000000 + elapsed().inMilliseconds;

  static const limits = {
    'getFamilyChatConfig': 60,
    'fetchFamilyChatConversations': 60,
    'fetchFamilyChatMessages': 120,
    'fetchFamilyChatMessageStates': 60,
    'acknowledgeFamilyChatMessages': 60,
    'reserveFamilyChatOperations': 10,
    'sendFamilyChatMessage': 30,
    'fetchFamilyChatShortcuts': 60,
  };
  final _windows = <String, ({int start, int count})>{};
  final peak = <String, int>{};
  final exhausted = <String>[];
  final calls = <({String device, String name, Duration at})>[];
  final refused = <String>[];
  final stateRequests = <({String device, List<String> ids})>[];
  final messages = <String, List<Map<String, dynamic>>>{
    for (final target in _targets) target: [],
  };
  final acked = <String>{};
  Object? ackFailure;
  Object? sendFailure;
  int _sequence = 0;
  int _ticket = 0;

  void addIncoming(String target, int count) {
    for (var i = 0; i < count; i++) {
      final sequence = ++_sequence;
      messages[target]!.add({
        'id': 'in-$target-$sequence',
        'senderUid': target == 'family' ? 'mom1' : target,
        'conversationId': target == 'family' ? 'family' : 'direct-$target',
        'kind': 'text',
        'text': 'message $sequence',
        'sequence': sequence,
        'sentAt': now,
        'expiresAt': now + _day,
        'historyGeneration': 0,
        'receipts': <String, dynamic>{
          _uid: <String, dynamic>{'deliveredAt': null, 'readAt': null},
        },
      });
    }
  }

  Map<String, dynamic> get config => {
    'uid': _uid,
    'familyId': 'family',
    'epoch': 'epoch',
    'historyGeneration': 0,
    'serverTime': now,
    'canManage': false,
    'policyConfigured': true,
    'account': {'enabled': true, 'revision': 0, 'offGeneration': 0},
    'policy': {
      'enabled': true,
      'revision': 0,
      'offGeneration': 0,
      'retention': 'day',
    },
    'members': [
      {'uid': _uid, 'role': 'child', 'displayName': 'Child'},
      for (final target in _targets)
        if (target != 'family')
          {'uid': target, 'role': 'managingCaregiver', 'displayName': target},
    ],
  };

  Future<Map<String, dynamic>> handle(
    String device,
    String name,
    Map<String, Object?> data,
  ) async {
    calls.add((device: device, name: name, at: elapsed()));
    final limit = limits[name];
    if (limit != null) {
      final old = _windows[name];
      final current = old != null && old.start + 60000 > now;
      final count = current ? old.count + 1 : 1;
      _windows[name] = (start: current ? old.start : now, count: count);
      peak[name] = count > (peak[name] ?? 0) ? count : peak[name]!;
      if (count > limit) {
        exhausted.add(name);
        throw const CallableFailure('unavailable');
      }
    }
    Map<String, dynamic> copy(Map<String, dynamic> row) =>
        Map<String, dynamic>.from(jsonDecode(jsonEncode(row)) as Map);
    switch (name) {
      case 'getFamilyChatConfig':
        return config;
      case 'fetchFamilyChatConversations':
        return {'conversations': [], 'cursor': '', 'hasMore': false};
      case 'fetchFamilyChatShortcuts':
        return {'items': null, 'revision': 0, 'order': [], 'orderRevision': 0};
      case 'fetchFamilyChatMessages':
        final all = messages[data['targetUid']] ?? const [];
        final after = data['after'] as int? ?? 0;
        var rows = data['latest'] == true
            ? all.reversed.take(50).toList().reversed.toList()
            : all.where((row) => (row['sequence'] as int) > after).toList();
        rows = rows.take(50).toList();
        return {
          'messages': rows.map(copy).toList(),
          'cursor': rows.isEmpty ? after : rows.last['sequence'],
          'hasMore': false,
        };
      case 'fetchFamilyChatMessageStates':
        final ids = (data['ids'] as List).cast<String>();
        stateRequests.add((device: device, ids: ids));
        return {
          'messages': [
            for (final rows in messages.values)
              for (final row in rows)
                if (ids.contains(row['id'])) copy(row),
          ],
        };
      case 'acknowledgeFamilyChatMessages':
        if (ackFailure != null) throw ackFailure!;
        final items = data['items'] as List;
        for (final item in items) {
          acked.add(item['messageId'] as String);
          for (final rows in messages.values) {
            for (final row in rows) {
              if (row['id'] == item['messageId']) {
                (row['receipts'] as Map)[_uid]['deliveredAt'] ??= now;
              }
            }
          }
        }
        return {
          'acknowledged': [for (final item in items) item['messageId']],
          'ignored': [],
        };
      case 'reserveFamilyChatOperations':
        return {
          'tickets': [
            for (var i = 0; i < (data['count'] as int); i++)
              {
                'id': 'ticket-${++_ticket}',
                'token': 'token-$_ticket',
                'expiresAt': now + _day,
              },
          ],
        };
      case 'sendFamilyChatMessage':
        if (sendFailure != null) throw sendFailure!;
        final target = data['targetUid'] as String;
        final row = <String, dynamic>{
          // Like the backend: the message id is the ticket id, not its token.
          'id': (data['ticket'] as String).replaceFirst('token-', 'ticket-'),
          'senderUid': _uid,
          'conversationId': target == 'family' ? 'family' : 'direct-$target',
          'kind': data['kind'] ?? 'text',
          'text': data['text'],
          'sequence': ++_sequence,
          'sentAt': now,
          'expiresAt': now + _day,
          'historyGeneration': 0,
          'receipts': <String, dynamic>{
            target: <String, dynamic>{'deliveredAt': null, 'readAt': null},
          },
        };
        messages[target]!.add(row);
        return {'message': copy(row)};
      case 'configureFamilyChat':
        return {'ok': true};
    }
    throw StateError(name);
  }

  // [since] is an index into [calls]: fake time does not advance while
  // microtasks flush, so a timestamp mark would include earlier calls.
  Iterable<String> names({String? device, int? since}) => calls
      .skip(since ?? 0)
      .where((call) => device == null || call.device == device)
      .map((call) => call.name);
}

class _Device implements FamilyChatApi {
  _Device(this.server, this.name);
  final _Server server;
  final String name;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      server.refused.add(operation);
      throw const CallableFailure('cancelled');
    }
    return server.handle(name, operation, data);
  }
}

FamilyChatSession _session(
  _Server server,
  String device,
  FamilyChatDatabase db,
) => FamilyChatSession(
  uid: _uid,
  api: _Device(server, device),
  db: db,
  isCurrentAccount: () => true,
  clock: () => DateTime.fromMillisecondsSinceEpoch(server.now),
);

/// Completes [future] inside fake time without advancing timers.
T _drain<T>(FakeAsync time, Future<T> future) {
  late T value;
  Object? error;
  var done = false;
  future.then(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object failure) {
      error = failure;
      done = true;
    },
  );
  time.flushMicrotasks();
  if (!done) fail('future did not complete without timers');
  if (error != null) throw error!;
  return value;
}

void main() {
  group('ACK transient failures', () {
    test(
      'ACK 429 does not block fetch or send; receipt stays durable and is retried',
      () {
        fakeAsync((time) {
          final server = _Server(() => time.elapsed)
            ..addIncoming('mom1', 1)
            ..ackFailure = const CallableFailure('unavailable');
          final db = FamilyChatDatabase(NativeDatabase.memory());
          final session = _session(server, 'a', db);
          unawaited(session.start());
          time.flushMicrotasks();

          // Fresh config + fetch succeeded although the ACK hit 429.
          expect(session.scope, _scope);
          expect(session.error, isNull);
          expect(
            session.messages('mom1').map((m) => m['id']),
            contains('in-mom1-1'),
          );
          expect(_drain(time, db.receipts(_scope)), isNotEmpty);

          session.setForeground(true, chatVisible: false);
          time.flushMicrotasks();
          unawaited(session.send('mom1', 'Outgoing'));
          time.flushMicrotasks();

          // Outbox still flushed; chat is not reported offline.
          expect(
            server.messages['mom1']!.map((m) => m['text']),
            contains('Outgoing'),
          );
          expect(session.error, isNull);
          expect(_drain(time, db.outbox(_scope)), isEmpty);
          expect(_drain(time, db.receipts(_scope)), isNotEmpty);
          expect(server.acked, isEmpty);

          // The bounded session retry delivers the durable ACK later.
          server.ackFailure = null;
          time.elapse(const Duration(seconds: 5));
          expect(server.acked, contains('in-mom1-1'));
          expect(_drain(time, db.receipts(_scope)), isEmpty);

          session.dispose();
          unawaited(db.close());
          time.flushMicrotasks();
        });
      },
    );

    test('a timeout-shaped ACK failure is tolerated the same way', () {
      fakeAsync((time) {
        final server = _Server(() => time.elapsed)
          ..addIncoming('mom2', 2)
          ..ackFailure = TimeoutException('ack');
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(server, 'a', db);
        unawaited(session.start());
        time.flushMicrotasks();
        expect(session.error, isNull);
        expect(session.messages('mom2'), hasLength(2));
        expect(_drain(time, db.receipts(_scope)), hasLength(2));
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    });

    test('an authorization rejection of the ACK still fails closed', () {
      fakeAsync((time) {
        final server = _Server(() => time.elapsed)
          ..addIncoming('mom1', 1)
          ..ackFailure = const CallableFailure(
            'unavailable',
            rejectionCode: 'permission-denied',
          );
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(server, 'a', db);
        unawaited(session.start());
        time.flushMicrotasks();
        expect(session.error, 'permission-denied');
        expect(session.enabled, isFalse);
        session.setForeground(true, chatVisible: false);
        final mark = server.calls.length;
        time.elapse(const Duration(minutes: 5));
        expect(server.names(since: mark), isEmpty);
        expect(server.names(), isNot(contains('sendFamilyChatMessage')));
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    });

    test('an actual OFF stops ACK, fetch and send', () {
      fakeAsync((time) {
        final server = _Server(() => time.elapsed)..addIncoming('mom1', 1);
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(server, 'a', db);
        unawaited(session.start());
        time.flushMicrotasks();
        expect(session.enabled, isTrue);
        server.addIncoming('mom1', 1);
        _drain(time, db.fence.revokeAccount(_uid));
        final mark = server.calls.length;
        unawaited(session.synchronize());
        time.flushMicrotasks();
        session.setForeground(true, chatVisible: false);
        time.elapse(const Duration(minutes: 2));
        final after = server.names(since: mark).toSet();
        expect(after, isNot(contains('acknowledgeFamilyChatMessages')));
        expect(after, isNot(contains('fetchFamilyChatMessages')));
        expect(after, isNot(contains('sendFamilyChatMessage')));
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    });
  });

  group('request budget', () {
    test(
      'two devices, six threads, chat open and status every 3 s for a minute stay under limits',
      () {
        fakeAsync((time) {
          final server = _Server(() => time.elapsed);
          for (final target in _targets) {
            server.addIncoming(target, 30);
          }
          final dbs = <FamilyChatDatabase>[];
          final sessions = <FamilyChatSession>[];
          final settings = <FamilyChatSettingsRuntime>[];
          for (final device in ['a', 'b']) {
            final db = FamilyChatDatabase(NativeDatabase.memory());
            dbs.add(db);
            final session = _session(server, device, db);
            sessions.add(session);
            final runtime = FamilyChatSettingsRuntime(
              controller: FamilyChatSettingsController(
                uid: _uid,
                api: _Device(server, device),
                store: FamilyChatSettingsStore(db),
                currentUid: () => _uid,
                readRevocation: () => db.fence.accountRevocation(_uid),
                closeAdmission: (_) async => null,
                applyLocal: (_) async {},
              ),
              db: db,
              currentUid: () => _uid,
              configured: true,
              observeLifecycle: false,
              draft: const FamilyChatPreferences(),
              clock: () => DateTime.fromMillisecondsSinceEpoch(server.now),
            );
            settings.add(runtime);
            unawaited(runtime.start());
            unawaited(session.start());
          }
          time.flushMicrotasks();
          for (final session in sessions) {
            session.setForeground(true, chatVisible: true);
          }
          const status = FamilyStatus();
          final statusTicker = Timer.periodic(const Duration(seconds: 3), (_) {
            for (final runtime in settings) {
              unawaited(runtime.statusChanged(status));
            }
          });
          time.elapse(const Duration(seconds: 60));
          statusTicker.cancel();

          // Manual pull / FCM-triggered refresh is not starved.
          for (final session in sessions) {
            unawaited(session.synchronize());
          }
          time.flushMicrotasks();
          for (final session in sessions) {
            expect(session.error, isNull);
          }

          expect(server.exhausted, isEmpty);
          // Keep at least 25 % headroom on config and states.
          expect(server.peak['getFamilyChatConfig']!, lessThanOrEqualTo(45));
          expect(
            server.peak['fetchFamilyChatMessageStates']!,
            lessThanOrEqualTo(45),
          );
          for (final request in server.stateRequests) {
            expect(request.ids.length, lessThanOrEqualTo(50));
          }
          // Every thread's recent messages were refreshed on each device.
          for (final device in ['a', 'b']) {
            final seen = {
              for (final request in server.stateRequests)
                if (request.device == device) ...request.ids,
            };
            for (final target in _targets) {
              for (final row in server.messages[target]!) {
                expect(seen, contains(row['id']), reason: '$device $target');
              }
            }
          }

          for (final session in sessions) {
            session.dispose();
          }
          for (final runtime in settings) {
            runtime.dispose();
          }
          for (final db in dbs) {
            unawaited(db.close());
          }
          time.flushMicrotasks();
        });
      },
    );

    test(
      'an unknown send outcome is in every states batch without starving threads',
      () {
        fakeAsync((time) {
          final server = _Server(() => time.elapsed);
          for (final target in _targets) {
            server.addIncoming(target, 20);
          }
          final db = FamilyChatDatabase(NativeDatabase.memory());
          final session = _session(server, 'a', db);
          unawaited(session.start());
          time.flushMicrotasks();
          // Lost send response: the signed operation stays in the outbox.
          server.sendFailure = const CallableFailure('unavailable');
          unawaited(session.send('mom3', 'Unknown outcome'));
          time.flushMicrotasks();
          final pending = _drain(time, db.outbox(_scope));
          expect(pending, hasLength(1));
          final id = pending.single.read<String>('id');

          server.stateRequests.clear();
          for (var i = 0; i < 4; i++) {
            unawaited(session.synchronize());
            time.flushMicrotasks();
          }
          expect(server.stateRequests, hasLength(4));
          final perTarget = <String, int>{};
          for (final request in server.stateRequests) {
            expect(request.ids.first, id);
            expect(request.ids.length, lessThanOrEqualTo(50));
            for (final value in request.ids) {
              final target = _targets.firstWhere(
                (t) => value.startsWith('in-$t-'),
                orElse: () => '',
              );
              if (target.isNotEmpty) {
                perTarget[target] = (perTarget[target] ?? 0) + 1;
              }
            }
          }
          for (final target in _targets) {
            expect(perTarget[target], greaterThan(0), reason: target);
          }
          session.dispose();
          unawaited(db.close());
          time.flushMicrotasks();
        });
      },
    );
  });

  group('bounded retry lifecycle', () {
    test('a terminal outbox row alone keeps home quiet', () {
      fakeAsync((time) {
        final server = _Server(() => time.elapsed);
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(server, 'a', db);
        unawaited(session.start());
        time.flushMicrotasks();
        session.setForeground(true, chatVisible: false);
        server.sendFailure = const CallableFailure(
          'unavailable',
          rejectionCode: 'invalid-argument',
        );
        unawaited(session.send('mom1', 'Rejected for good'));
        time.flushMicrotasks();
        final rows = _drain(time, db.outbox(_scope));
        expect(rows, hasLength(1));
        expect(rows.single.readNullable<String>('error'), isNotNull);

        final mark = server.calls.length;
        time.elapse(const Duration(minutes: 10));
        expect(server.names(since: mark), isEmpty);
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    });

    test(
      'pending ACK retry is bounded; only resume restarts it; dispose stops it',
      () {
        fakeAsync((time) {
          final server = _Server(() => time.elapsed)
            ..addIncoming('mom1', 1)
            ..ackFailure = const CallableFailure('unavailable');
          final db = FamilyChatDatabase(NativeDatabase.memory());
          final session = _session(server, 'a', db);
          unawaited(session.start());
          time.flushMicrotasks();
          session.setForeground(true, chatVisible: false);
          time.flushMicrotasks();

          var mark = server.calls.length;
          time.elapse(const Duration(minutes: 3));
          final retries = server
              .names(since: mark)
              .where((name) => name == 'getFamilyChatConfig')
              .length;
          // 2 + 4 + 8 + 16 + 30 s window: at most five retries.
          expect(retries, inInclusiveRange(1, 5));

          mark = server.calls.length;
          time.elapse(const Duration(minutes: 10));
          expect(server.names(since: mark), isEmpty);

          // Unrelated foreground/status notifications do not reset the budget.
          session.setForeground(true, chatVisible: false);
          session.setForeground(true, chatVisible: false);
          time.elapse(const Duration(minutes: 2));
          expect(server.names(since: mark), isEmpty);

          // A real resume starts a new bounded window.
          session.setForeground(false, chatVisible: false);
          session.setForeground(true, chatVisible: false);
          time.elapse(const Duration(minutes: 2));
          expect(
            server.names(since: mark),
            contains('acknowledgeFamilyChatMessages'),
          );

          session.dispose();
          mark = server.calls.length;
          time.elapse(const Duration(minutes: 5));
          expect(server.names(since: mark), isEmpty);
          unawaited(db.close());
          time.flushMicrotasks();
        });
      },
    );

    test('home with no new work is quiet; open chat keeps its 8 s polling', () {
      fakeAsync((time) {
        final server = _Server(() => time.elapsed)..addIncoming('mom1', 1);
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(server, 'a', db);
        unawaited(session.start());
        time.flushMicrotasks();
        session.setForeground(true, chatVisible: false);
        time.flushMicrotasks();
        var mark = server.calls.length;
        time.elapse(const Duration(minutes: 5));
        expect(server.names(since: mark), isEmpty);

        session.setForeground(true, chatVisible: true);
        mark = server.calls.length;
        time.elapse(const Duration(seconds: 33));
        final configs = server
            .names(since: mark)
            .where((name) => name == 'getFamilyChatConfig')
            .length;
        expect(configs, inInclusiveRange(4, 5));
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    });

    test(
      'background RemoteInput reply queued on Home is sent once after reconnect',
      () {
        final directory = Directory.systemTemp.createTempSync('chat-a2-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/chat.sqlite');
        fakeAsync((time) {
          final server = _Server(() => time.elapsed)..addIncoming('mom1', 1);
          // Two real connections to one SQLite file sharing one guard fence,
          // like the foreground app and the background isolate.
          final fence = MemoryChatGuardFence();
          final foreground = FamilyChatDatabase(NativeDatabase(file), fence);
          final background = FamilyChatDatabase(NativeDatabase(file), fence);
          final session = _session(server, 'a', foreground);
          unawaited(session.start());
          time.flushMicrotasks();
          expect(session.serverVerified, isTrue);
          session.setForeground(true, chatVisible: false);
          time.flushMicrotasks();

          // Home idle: nothing to do.
          var mark = server.calls.length;
          time.elapse(const Duration(minutes: 2));
          expect(server.names(since: mark), isEmpty);

          // Background isolate consumes an existing signed ticket.
          final id = _drain(
            time,
            background.enqueue(_scope, 'mom1', {
              'kind': 'text',
              'text': 'From the watch',
            }, server.now),
          );
          expect(id, isNotNull);
          expect(_drain(time, foreground.outbox(_scope)), hasLength(1));

          // Offline: the reconnect-triggered attempt fails transiently.
          server.sendFailure = const CallableFailure('unavailable');
          session.resumeQueuedSends();
          time.flushMicrotasks();
          expect(server.names(), contains('sendFamilyChatMessage'));
          expect(server.messages['mom1']!.where((m) => m['id'] == id), isEmpty);

          // Back online: the same bounded window delivers it exactly once.
          server.sendFailure = null;
          time.elapse(const Duration(minutes: 2));
          expect(
            server.messages['mom1']!.where((m) => m['id'] == id),
            hasLength(1),
          );
          expect(_drain(time, foreground.outbox(_scope)), isEmpty);

          // Another reconnect finds nothing and stays quiet; no duplicate.
          mark = server.calls.length;
          session.resumeQueuedSends();
          time.elapse(const Duration(minutes: 2));
          expect(server.names(since: mark), isEmpty);
          expect(
            server.messages['mom1']!.where((m) => m['id'] == id),
            hasLength(1),
          );

          session.dispose();
          unawaited(background.close());
          unawaited(foreground.close());
          time.flushMicrotasks();
        });
      },
    );
  });
}
