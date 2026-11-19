import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../../../core/notifications/inbox/notification_inbox_entry.dart';
import '../../../core/notifications/inbox/notification_inbox_store.dart';
import '../domain/family_question_reply_state.dart';
import 'family_chat_guard_fence.dart';

typedef FamilyChatNotice = ({int id, String tag});
const familyChatReplyAcknowledgmentTimeoutMs = 1000;

String familyChatNotificationTagPrefix(String scope) =>
    'family-chat:${base64Url.encode(utf8.encode(scope))}:';

String? _notificationAccount(String scope) {
  try {
    final decoded = jsonDecode(scope);
    if (decoded is List && decoded.firstOrNull is String) {
      return decoded.first as String;
    }
  } on FormatException {
    return null;
  }
  return null;
}

typedef FamilyChatDraftEdit = ({int at, int policyRevision, int? until});

const familyChatAwaitingTicket = 'awaiting-ticket';

class _ChatQueueAdmissionChanged implements Exception {
  const _ChatQueueAdmissionChanged();
}

/// Separate from medical records and excluded from backup/export.
class FamilyChatDatabase extends GeneratedDatabase {
  FamilyChatDatabase([
    QueryExecutor? executor,
    FamilyChatGuardFence? guardFence,
    NotificationInboxStore? notificationInbox,
  ]) : _notificationInbox =
           notificationInbox ??
           (executor == null ? NotificationInboxStore() : null),
       fence =
           guardFence ??
           (executor == null ? SqliteChatGuardFence() : MemoryChatGuardFence()),
       super(
         executor ??
             driftDatabase(
               name: 'family_chat',
               native: const DriftNativeOptions(
                 databaseDirectory: getApplicationSupportDirectory,
               ),
             ),
       );
  final FamilyChatGuardFence fence;
  final NotificationInboxStore? _notificationInbox;
  Future<int> _retentionNow(String scope, int candidate) async {
    final saved = (await metadata('purgedAt:$scope'))?['time'] as int? ?? 0;
    return candidate > saved ? candidate : saved;
  }

  @override
  int get schemaVersion => 6;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE chat_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE chat_messages (scope TEXT NOT NULL, target TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, expires_at INTEGER, PRIMARY KEY(scope,id))',
      );
      await customStatement(
        'CREATE TABLE chat_tickets (scope TEXT NOT NULL, id TEXT NOT NULL, token TEXT NOT NULL, expires_at INTEGER NOT NULL, PRIMARY KEY(scope,id))',
      );
      await customStatement(
        'CREATE TABLE chat_outbox (scope TEXT NOT NULL, id TEXT NOT NULL, target TEXT NOT NULL, payload TEXT NOT NULL, expires_at INTEGER NOT NULL, created_at INTEGER NOT NULL, error TEXT, retention_until INTEGER, policy_revision INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,id))',
      );
      await customStatement(
        'CREATE TABLE chat_actions (scope TEXT NOT NULL, id TEXT NOT NULL, is_read INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,id))',
      );
      await customStatement(
        'CREATE TABLE chat_drafts (scope TEXT NOT NULL, target TEXT NOT NULL, value TEXT NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0, retention_until INTEGER, policy_revision INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,target))',
      );
      await _installLocalReads();
      await _installMessageIndexes();
      await _installNotifications();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _installLocalReads();
      if (from < 3) await _installMessageIndexes();
      if (from < 4) await _installNotifications();
      if (from < 5) {
        await customStatement(
          'ALTER TABLE chat_outbox ADD COLUMN retention_until INTEGER',
        );
        await customStatement(
          'ALTER TABLE chat_outbox ADD COLUMN policy_revision INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE chat_outbox SET retention_until=created_at+604800000',
        );
        await customStatement(
          'ALTER TABLE chat_drafts ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE chat_drafts ADD COLUMN retention_until INTEGER',
        );
        await customStatement(
          'ALTER TABLE chat_drafts ADD COLUMN policy_revision INTEGER NOT NULL DEFAULT 0',
        );
        // Unreleased legacy drafts have no trustworthy age. Do not invent one.
        await customStatement('UPDATE chat_drafts SET retention_until=0');
      }
      if (from < 6) {
        // Retire the removed device-local text-to-speech preference.
        await customStatement(
          "DELETE FROM chat_metadata WHERE key GLOB 'speech:*'",
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA busy_timeout=5000');
      await customStatement('PRAGMA journal_mode=WAL');
    },
  );
  Future<({int revision, int? until})> _lifetime(
    String scope,
    int time,
    Map? policy,
  ) async {
    final saved = await metadata('retention:$scope');
    final selected =
        saved != null &&
            saved['retention'] != null &&
            (saved['revision'] as int? ?? 0) >=
                (policy?['revision'] as int? ?? -1)
        ? saved
        : policy ?? saved;
    const periods = {'day': 1, 'week': 7, 'month': 30, 'unlimited': null};
    final period = selected?['retention'] ?? 'week';
    if (!periods.containsKey(period)) throw StateError('Invalid retention');
    final days = periods[period];
    var until = days == null ? null : time + days * 86400000;
    if (policy?['retention'] != null) {
      if (!periods.containsKey(policy!['retention'])) {
        throw StateError('Invalid retention');
      }
      final suppliedDays = periods[policy['retention']];
      if (suppliedDays != null) {
        final limit = time + suppliedDays * 86400000;
        if (until == null || limit < until) until = limit;
      }
      for (final change in saved?['shortenings'] as List? ?? []) {
        if ((change['revision'] as int) > (policy['revision'] as int? ?? 0)) {
          final limit = time + (change['days'] as int) * 86400000;
          if (until == null || limit < until) until = limit;
        }
      }
    }
    return (revision: selected?['revision'] as int? ?? 0, until: until);
  }

  Future<void> _installNotifications() => customStatement(
    "CREATE TABLE chat_notifications (scope TEXT NOT NULL,id INTEGER NOT NULL,tag TEXT NOT NULL,stamp TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'pending',PRIMARY KEY(scope,id,tag))",
  );

  /// The first DML obtains SQLite's writer lock before reading authorization.
  /// Background notification display and logout cancellation share this order.
  Future<void> _lockActive() => customStatement(
    "UPDATE chat_metadata SET value=value WHERE key='activeChat'",
  );
  Future<Map<String, dynamic>> activeChat() => fence.read();
  Future<bool> activateChat(
    String uid,
    String scope,
    String stamp, {
    bool Function()? allowed,
    String? expectedGeneration,
  }) async {
    final version =
        expectedGeneration ?? (await fence.read())['version'] as String;
    final admitted = await transaction(() async {
      await _lockActive();
      if (allowed?.call() == false) return false;
      if (await fence.blocked() &&
          (await customSelect(
            'SELECT id FROM chat_notifications LIMIT 1',
          ).get()).isNotEmpty) {
        throw StateError('Pending chat notification cancellation');
      }
      if (!await fence.activate(version, uid, scope, stamp)) return false;
      if (allowed?.call() == false) {
        await fence.block(expectedStamp: stamp);
        return false;
      }
      return true;
    });
    if (admitted && _notificationInbox != null) {
      NotificationInboxStore.notifyFamilyChatAccessChanged();
    }
    return admitted;
  }

  Future<List<FamilyChatNotice>> deactivateChat({
    String? expectedStamp,
    void Function(String)? onBlocked,
  }) async {
    final version = await fence.block(expectedStamp: expectedStamp);
    if (version == null) return <FamilyChatNotice>[];
    if (_notificationInbox != null) {
      NotificationInboxStore.notifyFamilyChatAccessChanged();
    }
    onBlocked?.call(version);
    return cancellationIntents();
  }

  Future<List<FamilyChatNotice>> cancellationIntents() async {
    while (true) {
      try {
        return await transaction(() async {
          await _lockActive();
          final rows = await customSelect(
            'SELECT id,tag FROM chat_notifications',
          ).get();
          return rows
              .map(
                (row) =>
                    (id: row.read<int>('id'), tag: row.read<String>('tag')),
              )
              .toList();
        });
      } catch (error) {
        final cause = error is DriftRemoteException ? error.remoteCause : error;
        if (cause is! SqliteException ||
            (cause.resultCode != 5 && cause.resultCode != 6)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<List<FamilyChatNotice>> noticesForAccount(String uid) async {
    final rows = await customSelect(
      'SELECT scope,id,tag FROM chat_notifications',
    ).get();
    return rows
        .where((row) {
          final scope = jsonDecode(row.read<String>('scope')) as List;
          return scope.firstOrNull == uid;
        })
        .map((row) => (id: row.read<int>('id'), tag: row.read<String>('tag')))
        .toList();
  }

  Future<T?> withChatGuard<T>(
    Map<String, dynamic> expected,
    Future<T> Function() action,
  ) async {
    if (await fence.blocked()) return null;
    return transaction(() async {
      await _lockActive();
      final active = await activeChat();
      if (active['enabled'] != true ||
          [
            'uid',
            'scope',
            'stamp',
          ].any((key) => active[key] != expected[key]) ||
          await fence.blocked() ||
          expected['historyGeneration'] is int &&
              !await historyAllows(
                expected['scope'] as String,
                expected['historyGeneration'] as int,
              )) {
        return null;
      }
      final value = await action();
      final after = await activeChat();
      return after['enabled'] == true &&
              [
                'uid',
                'scope',
                'stamp',
              ].every((key) => after[key] == expected[key])
          ? value
          : null;
    });
  }

  Future<bool> notificationShown(
    String scope,
    int id, {
    String tag = '',
  }) async => (await customSelect(
    "SELECT id FROM chat_notifications WHERE scope=? AND id=? AND tag=? AND status='shown'",
    variables: [Variable(scope), Variable(id), Variable(tag)],
  ).get()).isNotEmpty;
  Future<void> rememberNotification(
    String scope,
    int id,
    String stamp, {
    String tag = '',
  }) => customStatement(
    'INSERT OR IGNORE INTO chat_notifications(scope,id,tag,stamp) VALUES (?,?,?,?)',
    [scope, id, tag, stamp],
  );
  Future<bool> prepareNotification(
    Map<String, dynamic> expected,
    FamilyChatNotice notice,
  ) async =>
      await withChatGuard(expected, () async {
        final scope = expected['scope'] as String;
        if (await notificationShown(scope, notice.id, tag: notice.tag) ||
            await notificationCancelling(scope, notice.tag)) {
          return false;
        }
        await rememberNotification(
          scope,
          notice.id,
          expected['stamp'] as String,
          tag: notice.tag,
        );
        return true;
      }) ??
      false;
  Future<void> confirmCancelled(FamilyChatNotice notice) =>
      transaction(() async {
        await customStatement(
          'DELETE FROM chat_notifications WHERE id=? AND tag=?',
          [notice.id, notice.tag],
        );
        await clearReplyAcknowledgment(notice.tag);
      });
  Future<bool> hasCancellationIntent(FamilyChatNotice notice) async =>
      (await customSelect(
        'SELECT id FROM chat_notifications WHERE id=? AND tag=?',
        variables: [Variable(notice.id), Variable(notice.tag)],
      ).get()).isNotEmpty;
  Future<bool> notificationCancelling(
    String scope,
    String tag,
  ) async => (await customSelect(
    "SELECT id FROM chat_notifications WHERE scope=? AND tag=? AND status='cancel' LIMIT 1",
    variables: [Variable(scope), Variable(tag)],
  ).get()).isNotEmpty;

  Future<List<String>> notificationMessageIds(
    String scope,
    String target,
  ) async {
    final rows = await customSelect(
      "SELECT DISTINCT m.id FROM chat_messages m JOIN chat_notifications n ON n.scope=m.scope AND n.tag=? || m.id WHERE m.scope=? AND m.target=? AND n.status!='cancel'",
      variables: [
        Variable(familyChatNotificationTagPrefix(scope)),
        Variable(scope),
        Variable(target),
      ],
    ).get();
    return rows.map((row) => row.read<String>('id')).toList();
  }

  /// Whether [uid]'s own reply to [parent] blocks another reply, decided by
  /// the shared domain policy: confirmed, pending or ambiguous replies block;
  /// a definitively failed operation permits a conscious new answer. Replies
  /// of other members never count. An empty [uid] never authorizes a reply.
  Future<bool> hasAuthoredReply(String scope, String uid, String parent) async {
    if (uid.isEmpty) return true;
    final question = await customSelect(
      'SELECT target, payload FROM chat_messages WHERE scope=? AND id=?',
      variables: [Variable(scope), Variable(parent)],
    ).getSingleOrNull();
    final questionPayload = question == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(question.read<String>('payload')) as Map,
          );
    final rows = <Map<String, dynamic>>[
      // Evaluated as the parent of a reply whatever its kind, so notification
      // replies to ordinary messages keep their duplicate protection.
      {
        'id': parent,
        'kind': 'question',
        if (questionPayload['sentAt'] is int)
          'sentAt': questionPayload['sentAt'],
      },
    ];
    for (final row in await customSelect(
      '''
      SELECT payload FROM chat_messages
      WHERE scope=? AND json_extract(payload,'\$.kind')='answer'
        AND json_extract(payload,'\$.senderUid')=?
        AND json_extract(payload,'\$.replyTo')=?
      ''',
      variables: [Variable(scope), Variable(uid), Variable(parent)],
    ).get()) {
      rows.add({
        ...Map<String, dynamic>.from(
          jsonDecode(row.read<String>('payload')) as Map,
        ),
        'delivery': null,
        'sendOutcomeUnknown': false,
      });
    }
    // The outbox only holds this account's own operations.
    for (final row in await customSelect(
      '''
      SELECT id, error, json_type(payload,'\$.ticket')='text' AS signed
      FROM chat_outbox
      WHERE scope=? AND json_extract(payload,'\$.kind')='answer'
        AND json_extract(payload,'\$.replyTo')=?
      ''',
      variables: [Variable(scope), Variable(parent)],
    ).get()) {
      rows.add({
        'id': 'outbox:${row.read<String>('id')}',
        'kind': 'answer',
        'replyTo': parent,
        'senderUid': uid,
        'operationError': row.readNullable<String>('error'),
        'operationSigned': row.readNullable<bool>('signed') ?? false,
      });
    }
    final prefix = 'outcome:$scope:';
    for (final row in await customSelect(
      'SELECT value FROM chat_metadata WHERE substr(key,1,?)=?',
      variables: [Variable(prefix.length), Variable(prefix)],
    ).get()) {
      final marker = Map<String, dynamic>.from(
        jsonDecode(row.read<String>('value')) as Map,
      );
      // Legacy markers without an association only block their own target.
      if (marker['kind'] == null &&
          (question == null ||
              marker['target'] != question.read<String>('target'))) {
        continue;
      }
      rows.add({
        'id': 'outcome:${marker['id']}',
        'senderUid': uid,
        'redactedOutcome': true,
        'outcomeKind': marker['kind'],
        'replyTo': marker['replyTo'],
        'sentAt': marker['createdAt'],
      });
    }
    return familyQuestionReplyStates(
      rows,
      childUid: uid,
    )[parent]!.blocksNewAnswer;
  }

  Future<void> markReplyNotificationForCancellation(
    String scope,
    String parent,
  ) => customStatement(
    "UPDATE chat_notifications SET status='cancel' WHERE scope=? AND tag=?",
    [scope, '${familyChatNotificationTagPrefix(scope)}$parent'],
  );

  Future<void> deferReplyCancellation(String tag) =>
      setMetadata('replyAcknowledgment:$tag', {
        'until':
            DateTime.now().millisecondsSinceEpoch +
            familyChatReplyAcknowledgmentTimeoutMs,
      });

  Future<void> clearReplyAcknowledgment(String tag) => customStatement(
    'DELETE FROM chat_metadata WHERE key=?',
    ['replyAcknowledgment:$tag'],
  );

  Future<bool> presentNotification(
    Map<String, dynamic> expected,
    FamilyChatNotice notice, {
    required Future<void> Function() show,
    required Future<void> Function() cancel,
  }) async {
    // This commit must complete before the irreversible OS side effect.
    if (!await prepareNotification(expected, notice)) return false;
    final shown = await withChatGuard(expected, () async {
      if (await notificationCancelling(
            expected['scope'] as String,
            notice.tag,
          ) ||
          await notificationShown(
            expected['scope'] as String,
            notice.id,
            tag: notice.tag,
          )) {
        return false;
      }
      await show();
      await markNotificationShown(expected, notice);
      return true;
    });
    if (shown == null) {
      await cancel();
      await confirmCancelled(notice);
      return false;
    }
    return shown;
  }

  Future<void> markNotificationShown(
    Map<String, dynamic> expected,
    FamilyChatNotice notice,
  ) => customStatement(
    "UPDATE chat_notifications SET status='shown' WHERE scope=? AND id=? AND tag=? AND stamp=?",
    [expected['scope'], notice.id, notice.tag, expected['stamp']],
  );

  @override
  Future<void> close() async {
    await super.close();
    await fence.close();
  }

  Future<void> _installLocalReads() => customStatement(
    'CREATE TABLE chat_local_reads (scope TEXT NOT NULL,id TEXT NOT NULL,PRIMARY KEY(scope,id))',
  );
  Future<void> _installMessageIndexes() async {
    await customStatement(
      'CREATE INDEX chat_message_page ON chat_messages(scope,target,CAST(json_extract(payload,\'\$.sequence\') AS INTEGER) DESC)',
    );
    await customStatement(
      'CREATE INDEX chat_message_expiry ON chat_messages(scope,expires_at)',
    );
  }

  Future<Map<String, dynamic>?> metadata(String key) async {
    final rows = await customSelect(
      'SELECT value FROM chat_metadata WHERE key=?',
      variables: [Variable(key)],
    ).get();
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.single.read<String>('value')) as Map,
          );
  }

  Future<void> setMetadata(String key, Map<String, dynamic> value) =>
      customStatement(
        'INSERT OR REPLACE INTO chat_metadata(key,value) VALUES (?,?)',
        [key, jsonEncode(value)],
      );

  Future<Map<String, dynamic>> historyState(String scope) async =>
      await metadata('history:$scope') ?? {};

  Future<bool> historyAllows(String scope, int generation) async =>
      generation >= ((await historyState(scope))['minimum'] as int? ?? 0);

  Future<Map<String, dynamic>> observeHistoryGeneration(
    String scope,
    int generation,
  ) => transaction(() async {
    await _lockActive();
    final state = await historyState(scope);
    final confirmed = state['confirmed'] as int? ?? 0;
    if (generation <= confirmed) return state;
    return _advanceHistory(scope, state, generation, confirmed: generation);
  });

  Future<Map<String, dynamic>> beginHistoryClear(
    String scope,
    int expectedGeneration,
    String operationId,
  ) => transaction(() async {
    await _lockActive();
    final state = await historyState(scope);
    if (state['intent'] != null ||
        (state['confirmed'] as int? ?? 0) != expectedGeneration ||
        (state['minimum'] as int? ?? 0) > expectedGeneration) {
      throw StateError('History settings changed');
    }
    final parts = jsonDecode(scope) as List;
    state
      ..remove('conflict')
      ..['intent'] = {
        'familyId': parts[1],
        'epoch': parts[2],
        'expectedGeneration': expectedGeneration,
        'operationId': operationId,
      };
    return _advanceHistory(scope, state, expectedGeneration + 1);
  });

  Future<Map<String, dynamic>> finishHistoryClear(
    String scope,
    String operationId, {
    int? generation,
  }) => transaction(() async {
    await _lockActive();
    final state = await historyState(scope);
    if (state['intent']?['operationId'] != operationId) return state;
    state.remove('intent');
    if (generation == null) state['conflict'] = true;
    return _advanceHistory(
      scope,
      state,
      generation ?? 0,
      confirmed: generation,
    );
  });

  Future<Map<String, dynamic>> _advanceHistory(
    String scope,
    Map<String, dynamic> state,
    int generation, {
    int? confirmed,
  }) async {
    final previous = state['minimum'] as int? ?? 0;
    if (confirmed != null && confirmed > (state['confirmed'] as int? ?? 0)) {
      state['confirmed'] = confirmed;
    }
    if (generation > previous) {
      state['minimum'] = generation;
      await _notificationInbox?.purgeFamilyChat(
        scope: scope,
        beforeHistoryGeneration: generation,
      );
      if ((await metadata('chatOpen'))?['scope'] == scope) {
        await customStatement("DELETE FROM chat_metadata WHERE key='chatOpen'");
      }
      // Save the barrier with the purge. Late writers see either both or neither.
      for (final table in [
        'chat_messages',
        'chat_actions',
        'chat_local_reads',
      ]) {
        await customStatement('DELETE FROM $table WHERE scope=?', [scope]);
      }
      // Existing signed operations may already have reached the server. Keep
      // them for verification without resending them across the history clear.
      await customStatement(
        "UPDATE chat_outbox SET error='send-outcome-unknown' "
        "WHERE scope=? AND error IS NULL AND json_type(payload,'\$.ticket')='text'",
        [scope],
      );
      final prefix = 'cursor:$scope:';
      await customStatement(
        'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
        [prefix.length, prefix],
      );
      await customStatement('DELETE FROM chat_metadata WHERE key=?', [
        'threads:$scope',
      ]);
      await customStatement(
        "UPDATE chat_notifications SET status='cancel' WHERE scope=?",
        [scope],
      );
    }
    await setMetadata('history:$scope', state);
    return state;
  }

  Future<List<FamilyChatNotice>> historyCancellationIntents(
    String scope, {
    bool includeDeferred = false,
    int? now,
  }) async {
    final rows = await customSelect(
      '''
      SELECT id,tag FROM chat_notifications AS notice
      WHERE scope=? AND status='cancel' AND (? OR NOT EXISTS (
        SELECT 1 FROM chat_metadata
        WHERE key='replyAcknowledgment:' || notice.tag
          AND json_extract(value,'\$.until')>?
      ))
      ''',
      variables: [
        Variable(scope),
        Variable(includeDeferred),
        Variable(now ?? DateTime.now().millisecondsSinceEpoch),
      ],
    ).get();
    return rows
        .map((row) => (id: row.read<int>('id'), tag: row.read<String>('tag')))
        .toList();
  }

  Future<bool> saveMessage(
    String scope,
    String target,
    Map<String, dynamic> message, {
    int? serverNow,
  }) => transaction(() async {
    await _lockActive();
    if (!await historyAllows(
      scope,
      message['historyGeneration'] as int? ?? 0,
    )) {
      return false;
    }
    final value = Map<String, dynamic>.from(message);
    final id = value['id'] as String;
    final cached = await this.message(scope, id);
    final account = _notificationAccount(scope);
    final parent = value['replyTo'];
    if (account != null &&
        value['senderUid'] == account &&
        value['kind'] == 'answer' &&
        parent is String) {
      await markReplyNotificationForCancellation(scope, parent);
    }
    final receipts = value['receipts'] as Map?;
    final observed = receipts?[account] as Map?;
    final cachedReceipt = (cached?['receipts'] as Map?)?[account] as Map?;
    if (account != null &&
        cachedReceipt?['readAt'] != null &&
        observed?['readAt'] == null) {
      value['receipts'] = {
        ...?receipts,
        account: {...?observed, 'readAt': cachedReceipt!['readAt']},
      };
    }
    if (cached?['_notificationSuppressed'] == true) {
      value['_notificationSuppressed'] = true;
    }
    var until = value['expiresAt'] as int?;
    final oldUntil = cached?['expiresAt'] as int?;
    if (oldUntil != null && (until == null || oldUntil < until)) {
      until = oldUntil;
    }
    final policy = await metadata('retention:$scope');
    for (final change in policy?['shortenings'] as List? ?? []) {
      if ((change['revision'] as int) >
          (value['policyRevision'] as int? ?? 0)) {
        final limit =
            (value['sentAt'] as int) + (change['days'] as int) * 86400000;
        if (until == null || limit < until) until = limit;
      }
    }
    value['expiresAt'] = until;
    final now = await _retentionNow(scope, serverNow ?? 0);
    final ownRead = ((value['receipts'] as Map?)?[account] as Map?)?['readAt'];
    if (account != null && value['senderUid'] != account && ownRead != null ||
        until != null &&
            (until <= now ||
                cached != null && (oldUntil == null || until < oldUntil))) {
      final tag = '${familyChatNotificationTagPrefix(scope)}$id';
      await customStatement(
        "UPDATE chat_notifications SET status='cancel' WHERE scope=? AND tag=?",
        [scope, tag],
      );
      if (ownRead == null && await notificationCancelling(scope, tag)) {
        value['_notificationSuppressed'] = true;
      }
    }
    if (until != null && until <= now) {
      await customStatement(
        'DELETE FROM chat_messages WHERE scope=? AND id=?',
        [scope, value['id']],
      );
      return false;
    }
    await customStatement(
      'INSERT OR REPLACE INTO chat_messages(scope,target,id,payload,expires_at) VALUES (?,?,?,?,?)',
      [scope, target, value['id'], jsonEncode(value), until],
    );
    return true;
  });
  Future<List<Map<String, dynamic>>> messages(
    String scope,
    String target, {
    int? before,
    int limit = 50,
  }) async {
    final rows = await customSelect(
      'SELECT m.payload, CASE WHEN r.id IS NULL THEN 0 ELSE 1 END AS locally_read FROM chat_messages m LEFT JOIN chat_local_reads r ON r.scope=m.scope AND r.id=m.id WHERE m.scope=? AND m.target=? ${before == null ? '' : "AND CAST(json_extract(m.payload,'\$.sequence') AS INTEGER)<?"} ORDER BY CAST(json_extract(m.payload,\'\$.sequence\') AS INTEGER) DESC LIMIT ?',
      variables: [
        Variable(scope),
        Variable(target),
        if (before != null) Variable(before),
        Variable(limit),
      ],
    ).get();
    return rows
        .map(
          (row) => (Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          )..['_localRead'] = row.read<int>('locally_read') == 1),
        )
        .toList()
      ..sort((a, b) => (a['sequence'] as num).compareTo(b['sequence'] as num));
  }

  /// A badge never depends on which bounded history page is currently shown.
  Future<Map<String, dynamic>> unread(String scope, String uid) async {
    final rows = await customSelect(
      "SELECT json_extract(m.payload,'\$.senderUid') AS sender, COUNT(*) OVER() AS total FROM chat_messages m LEFT JOIN chat_local_reads r ON r.scope=m.scope AND r.id=m.id WHERE m.scope=? AND r.id IS NULL AND json_extract(m.payload,'\$.senderUid')<>? AND json_extract(m.payload,?) IS NULL ORDER BY json_extract(m.payload,'\$.sentAt') DESC LIMIT 1",
      variables: [
        Variable(scope),
        Variable(uid),
        Variable('\$.receipts.${jsonEncode(uid)}.readAt'),
      ],
    ).get();
    return rows.isEmpty
        ? {'count': 0}
        : {
            'count': rows.single.read<int>('total'),
            'senderUid': rows.single.read<String>('sender'),
          };
  }

  Future<Map<String, dynamic>?> message(String scope, String id) async {
    final rows = await customSelect(
      'SELECT payload FROM chat_messages WHERE scope=? AND id=?',
      variables: [Variable(scope), Variable(id)],
    ).get();
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.single.read<String>('payload')) as Map,
          );
  }

  /// The independent fence can change while this transaction holds the writer.
  Future<T?> withComposerQueueAdmission<T>({
    required String uid,
    required String scope,
    required String expectedVersion,
    required String? expectedStamp,
    int? expectedHistoryGeneration,
    required bool Function() allowed,
    required Future<T> Function() action,
  }) async {
    Future<bool> admitted() async {
      final state = await fence.read();
      if (state['version'] != expectedVersion ||
          await fence.accountRevocation(uid) != null ||
          !allowed()) {
        return false;
      }
      if (expectedStamp != null || state['enabled'] == true) {
        return state['enabled'] == true &&
            state['uid'] == uid &&
            state['scope'] == scope &&
            (expectedStamp == null || state['stamp'] == expectedStamp);
      }
      return true;
    }

    try {
      return await transaction(() async {
        await _lockActive();
        if (!await admitted() ||
            expectedHistoryGeneration != null &&
                !await historyAllows(scope, expectedHistoryGeneration)) {
          return null;
        }
        if (expectedStamp == null) {
          final cached = await metadata('account:$uid');
          if (cached?['uid'] != uid ||
              cached?['familyId'] is! String ||
              cached?['epoch'] is! String ||
              jsonEncode([uid, cached?['familyId'], cached?['epoch']]) !=
                  scope ||
              cached?['account']?['enabled'] != true ||
              cached?['policy']?['enabled'] != true) {
            return null;
          }
        }
        final result = await action();
        if (!await admitted()) throw const _ChatQueueAdmissionChanged();
        return result;
      });
    } on _ChatQueueAdmissionChanged {
      return null;
    }
  }

  Future<String?> enqueueUnsignedComposerMessage(
    String scope,
    String id,
    String target,
    Map<String, dynamic> payload,
    int now,
  ) async {
    final count = (await customSelect(
      'SELECT COUNT(*) AS n FROM chat_outbox WHERE scope=?',
      variables: [Variable(scope)],
    ).getSingle()).read<int>('n');
    if (count >= 50) throw StateError('Outgoing queue is full');
    final lifetime = await _lifetime(scope, now, null);
    if (lifetime.until != null &&
        lifetime.until! <= await _retentionNow(scope, now)) {
      return null;
    }
    await customStatement(
      'INSERT INTO chat_outbox(scope,id,target,payload,expires_at,created_at,error,retention_until,policy_revision) VALUES (?,?,?,?,?,?,?,?,?)',
      [
        scope,
        id,
        target,
        jsonEncode(payload),
        lifetime.until ?? 9007199254740991,
        now,
        familyChatAwaitingTicket,
        lifetime.until,
        lifetime.revision,
      ],
    );
    return id;
  }

  /// The caller holds a verified composer queue admission. The ticket
  /// replaces the local identity in place without resetting retention.
  Future<void> promoteComposerMessages(
    String scope,
    List<dynamic> tickets,
    int now, {
    required int accountOffGeneration,
    required int familyOffGeneration,
  }) async {
    final available = tickets.iterator;
    for (final row in await outbox(scope)) {
      if (row.readNullable<String>('error') != familyChatAwaitingTicket) {
        continue;
      }
      final id = row.read<String>('id');
      final deadline = row.readNullable<int>('retention_until');
      final payload = Map<String, dynamic>.from(
        jsonDecode(row.read<String>('payload')) as Map,
      );
      final admission = payload.remove('_admission') as Map?;
      if (admission?['accountOffGeneration'] != accountOffGeneration ||
          admission?['familyOffGeneration'] != familyOffGeneration ||
          deadline != null && deadline <= await _retentionNow(scope, now)) {
        await complete(scope, id);
        continue;
      }
      if (!available.moveNext()) return;
      final ticket = available.current as Map;
      if ((ticket['expiresAt'] as int) <= now) return;
      final target = row.read<String>('target');
      await customStatement(
        'UPDATE chat_outbox SET id=?, payload=?, expires_at=?, error=NULL WHERE scope=? AND id=? AND error=?',
        [
          ticket['id'],
          jsonEncode({
            ...payload,
            'ticket': ticket['token'],
            'targetUid': target,
          }),
          ticket['expiresAt'],
          scope,
          id,
          familyChatAwaitingTicket,
        ],
      );
    }
  }

  Future<bool> enqueueUnsentReply(
    String scope,
    String id,
    String target,
    Map<String, dynamic> payload,
    int now,
    String marker, {
    Map? policy,
  }) => transaction(() async {
    final count = (await customSelect(
      'SELECT COUNT(*) AS n FROM chat_outbox WHERE scope=?',
      variables: [Variable(scope)],
    ).getSingle()).read<int>('n');
    if (count >= 50) throw StateError('Outgoing queue is full');
    final lifetime = await _lifetime(scope, now, policy);
    if (lifetime.until != null &&
        lifetime.until! <= await _retentionNow(scope, now)) {
      return false;
    }
    await customStatement(
      'INSERT OR IGNORE INTO chat_outbox(scope,id,target,payload,expires_at,created_at,error,retention_until,policy_revision) VALUES (?,?,?,?,?,?,?,?,?)',
      [
        scope,
        id,
        target,
        jsonEncode(payload),
        lifetime.until ?? 9007199254740991,
        now,
        'needs-ticket',
        lifetime.until,
        lifetime.revision,
      ],
    );
    await setMetadata('notificationDraft:$scope:$id', {'marker': marker});
    return true;
  });
  Future<String?> promoteNotificationDraft(
    String scope,
    String id,
    int now, {
    String? target,
  }) => transaction(() async {
    final row = (await outbox(
      scope,
    )).where((row) => row.read<String>('id') == id).firstOrNull;
    if (row == null || row.readNullable<String>('error') != 'needs-ticket') {
      return null;
    }
    final deadline = row.readNullable<int>('retention_until');
    if (deadline != null && deadline <= await _retentionNow(scope, now)) {
      await complete(scope, id);
      return null;
    }
    final draft = await metadata('notificationDraft:$scope:$id');
    await complete(scope, id);
    final next = await enqueue(
      scope,
      target ?? row.read<String>('target'),
      Map<String, dynamic>.from(jsonDecode(row.read<String>('payload')) as Map),
      now,
      originalLifetime: (
        at: row.read<int>('created_at'),
        policyRevision: row.read<int>('policy_revision'),
        until: deadline,
      ),
    );
    if (next == null) throw StateError('Reconnect before sending');
    if (draft != null) {
      final key = draft['marker'] as String;
      await setMetadata(key, {...?await metadata(key), 'id': next});
    }
    await customStatement('DELETE FROM chat_metadata WHERE key=?', [
      'notificationDraft:$scope:$id',
    ]);
    return next;
  });

  Future<void> addTickets(
    String scope,
    List<dynamic> tickets,
  ) => transaction(() async {
    for (final raw in tickets) {
      final value = raw as Map;
      await customStatement(
        'INSERT OR IGNORE INTO chat_tickets(scope,id,token,expires_at) VALUES (?,?,?,?)',
        [scope, value['id'], value['token'], value['expiresAt']],
      );
    }
  });
  Future<String?> enqueue(
    String scope,
    String target,
    Map<String, dynamic> payload,
    int serverNow, {
    String? composerDraft,
    String Function()? latestDraft,
    FamilyChatDraftEdit? Function()? latestDraftEdit,
    int Function()? currentServerNow,
    FamilyChatDraftEdit? originalLifetime,
    Map? policy,
  }) => transaction(() async {
    final rows = await customSelect(
      'SELECT * FROM chat_tickets WHERE scope=? AND expires_at>? ORDER BY expires_at LIMIT 1',
      variables: [Variable(scope), Variable(serverNow)],
    ).get();
    if (rows.isEmpty) return null;
    final count = await customSelect(
      'SELECT COUNT(*) AS n FROM chat_outbox WHERE scope=?',
      variables: [Variable(scope)],
    ).getSingle();
    if (count.read<int>('n') >= 50) throw StateError('Outgoing queue is full');
    final ticket = rows.single;
    final createdAt = originalLifetime?.at ?? serverNow;
    var lifetime = await _lifetime(scope, createdAt, policy);
    if (originalLifetime != null) {
      final original = originalLifetime.until;
      lifetime = (
        revision: originalLifetime.policyRevision,
        until:
            original != null &&
                (lifetime.until == null || original < lifetime.until!)
            ? original
            : lifetime.until,
      );
    }
    if (lifetime.until != null &&
        lifetime.until! <=
            await _retentionNow(scope, currentServerNow?.call() ?? serverNow)) {
      return null;
    }
    final id = ticket.read<String>('id');
    await customStatement(
      'INSERT INTO chat_outbox(scope,id,target,payload,expires_at,created_at,retention_until,policy_revision) VALUES (?,?,?,?,?,?,?,?)',
      [
        scope,
        id,
        target,
        jsonEncode({
          ...payload,
          'ticket': ticket.read<String>('token'),
          'targetUid': target,
        }),
        ticket.read<int>('expires_at'),
        createdAt,
        lifetime.until,
        lifetime.revision,
      ],
    );
    await customStatement('DELETE FROM chat_tickets WHERE scope=? AND id=?', [
      scope,
      id,
    ]);
    if (composerDraft != null) {
      final latest = latestDraft?.call() ?? composerDraft;
      await saveDraft(
        scope,
        target,
        latest == composerDraft ? '' : latest,
        serverNow: currentServerNow?.call() ?? serverNow,
        edit: latestDraftEdit?.call(),
      );
    }
    return id;
  });
  Future<List<QueryRow>> outbox(String scope) => customSelect(
    'SELECT * FROM chat_outbox WHERE scope=? ORDER BY rowid',
    variables: [Variable(scope)],
  ).get();
  Future<void> complete(String scope, String id) => transaction(() async {
    await customStatement('DELETE FROM chat_outbox WHERE scope=? AND id=?', [
      scope,
      id,
    ]);
    await clearOutcome(scope, id);
  });
  Future<void> clearOutcome(String scope, String id) => customStatement(
    'DELETE FROM chat_metadata WHERE key=?',
    ['outcome:$scope:$id'],
  );
  Future<List<Map<String, dynamic>>> outcomeMarkers(String scope) async {
    final prefix = 'outcome:$scope:';
    final rows = await customSelect(
      'SELECT value FROM chat_metadata WHERE substr(key,1,?)=? ORDER BY CAST(json_extract(value,\'\$.createdAt\') AS INTEGER) DESC LIMIT 50',
      variables: [Variable(prefix.length), Variable(prefix)],
    ).get();
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row.read<String>('value')) as Map,
          ),
        )
        .toList();
  }

  Future<void> failOperation(String scope, String id, String error) =>
      customStatement('UPDATE chat_outbox SET error=? WHERE scope=? AND id=?', [
        error,
        scope,
        id,
      ]);
  Future<void> queueReceipt(
    String scope,
    String id,
    bool read,
  ) => transaction(() async {
    await customStatement(
      'INSERT INTO chat_actions(scope,id,is_read) VALUES (?,?,?) ON CONFLICT(scope,id) DO UPDATE SET is_read=MAX(chat_actions.is_read,excluded.is_read)',
      [scope, id, read ? 1 : 0],
    );
    if (read) {
      await customStatement(
        'INSERT OR IGNORE INTO chat_local_reads(scope,id) VALUES (?,?)',
        [scope, id],
      );
    }
  });
  Future<List<QueryRow>> receipts(String scope) => customSelect(
    'SELECT * FROM chat_actions WHERE scope=?',
    variables: [Variable(scope)],
  ).get();
  Future<bool> locallyRead(String scope, String id) async =>
      (await customSelect(
        'SELECT id FROM chat_local_reads WHERE scope=? AND id=?',
        variables: [Variable(scope), Variable(id)],
      ).get()).isNotEmpty;
  Future<void> completeReceipt(String scope, String id, bool read) =>
      customStatement(
        'DELETE FROM chat_actions WHERE scope=? AND id=? AND is_read<=?',
        [scope, id, read ? 1 : 0],
      );
  Future<String> draft(String scope, String target) async {
    final rows = await customSelect(
      'SELECT value FROM chat_drafts WHERE scope=? AND target=?',
      variables: [Variable(scope), Variable(target)],
    ).get();
    return rows.isEmpty ? '' : rows.single.read<String>('value');
  }

  Future<void> saveDraft(
    String scope,
    String target,
    String value, {
    int? serverNow,
    FamilyChatDraftEdit? edit,
    bool allowCreate = true,
  }) => transaction(() async {
    final now = await _retentionNow(
      scope,
      serverNow ?? DateTime.now().millisecondsSinceEpoch,
    );
    final rows = await customSelect(
      'SELECT * FROM chat_drafts WHERE scope=? AND target=?',
      variables: [Variable(scope), Variable(target)],
    ).get();
    final old = rows.firstOrNull;
    if (value.isEmpty ||
        old?.readNullable<int>('retention_until') != null &&
            old!.read<int>('retention_until') <= now &&
            old.read<String>('value') == value) {
      await customStatement(
        'DELETE FROM chat_drafts WHERE scope=? AND target=?',
        [scope, target],
      );
      return;
    }
    if (old?.read<String>('value') == value || !allowCreate && edit == null) {
      return;
    }
    final life = await _lifetime(scope, edit?.at ?? now, null);
    final revision = edit?.policyRevision ?? life.revision;
    var until = edit == null ? life.until : edit.until;
    final policy = await metadata('retention:$scope');
    for (final change in policy?['shortenings'] as List? ?? []) {
      if ((change['revision'] as int) > revision) {
        final limit = (edit?.at ?? now) + (change['days'] as int) * 86400000;
        if (until == null || limit < until) until = limit;
      }
    }
    if (until != null && until <= now) {
      await customStatement(
        'DELETE FROM chat_drafts WHERE scope=? AND target=?',
        [scope, target],
      );
      return;
    }
    await customStatement(
      'INSERT OR REPLACE INTO chat_drafts(scope,target,value,updated_at,retention_until,policy_revision) VALUES (?,?,?,?,?,?)',
      [scope, target, value, edit?.at ?? now, until, revision],
    );
  });

  /// Private offline draft only. Never grants sending or clinical authority.
  Future<bool> saveCachedDraft(
    String uid,
    String scope,
    String target,
    String value, {
    required String expectedVersion,
    int? expectedHistoryGeneration,
    required bool Function() allowed,
    int? serverNow,
    FamilyChatDraftEdit? edit,
    bool allowCreate = true,
  }) => transaction(() async {
    await _lockActive();
    final state = await fence.read();
    if (!allowed() ||
        state['version'] != expectedVersion ||
        state['enabled'] == true ||
        await fence.accountRevocation(uid) != null ||
        expectedHistoryGeneration != null &&
            !await historyAllows(scope, expectedHistoryGeneration)) {
      return false;
    }
    await saveDraft(
      scope,
      target,
      value,
      serverNow: serverNow,
      edit: edit,
      allowCreate: allowCreate,
    );
    return true;
  });
  Future<void> purge(String scope, int serverNow) => transaction(() async {
    final previous = (await metadata('purgedAt:$scope'))?['time'] as int? ?? 0;
    await setMetadata('purgedAt:$scope', {
      'time': serverNow > previous ? serverNow : previous,
    });
    await customStatement(
      "UPDATE chat_notifications SET status='cancel' WHERE scope=? AND tag IN (SELECT ? || id FROM chat_messages WHERE scope=? AND expires_at<=?)",
      [scope, familyChatNotificationTagPrefix(scope), scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_local_reads WHERE scope=? AND id IN (SELECT id FROM chat_messages WHERE scope=? AND expires_at IS NOT NULL AND expires_at<=?)',
      [scope, scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_actions WHERE scope=? AND id IN (SELECT id FROM chat_messages WHERE scope=? AND expires_at IS NOT NULL AND expires_at<=?)',
      [scope, scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_messages WHERE scope=? AND expires_at IS NOT NULL AND expires_at<=?',
      [scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_tickets WHERE scope=? AND expires_at<=?',
      [scope, serverNow],
    );
    await customStatement(
      "UPDATE chat_outbox SET error='send-outcome-unknown' WHERE scope=? AND expires_at<=? AND error IS NULL",
      [scope, serverNow],
    );
    await customStatement(
      "INSERT OR REPLACE INTO chat_metadata(key,value) SELECT 'outcome:'||scope||':'||id, json_object('id',id,'state','unknown','target',target,'createdAt',created_at,'kind',json_extract(payload,'\$.kind'),'replyTo',json_extract(payload,'\$.replyTo')) FROM chat_outbox WHERE scope=? AND retention_until IS NOT NULL AND retention_until<=? AND json_type(payload,'\$.ticket')='text'",
      [scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_outbox WHERE scope=? AND retention_until IS NOT NULL AND retention_until<=?',
      [scope, serverNow],
    );
    await customStatement(
      'DELETE FROM chat_drafts WHERE scope=? AND retention_until IS NOT NULL AND retention_until<=?',
      [scope, serverNow],
    );
  });
  String _inboxScopeKey(String scope) => 'inboxRevisionScope:$scope';
  String _inboxAccountKey(String uid) => 'inboxRevisionAccount:$uid';

  Future<int> _inboxRevision(String key) async =>
      (await metadata(key))?['revision'] as int? ?? 0;

  Future<void> _advanceInboxRevision(String key) async {
    await setMetadata(key, {'revision': await _inboxRevision(key) + 1});
  }

  Future<String> notificationInboxRevision(String uid, String scope) async {
    final account = await _inboxRevision(_inboxAccountKey(uid));
    final membership = await _inboxRevision(_inboxScopeKey(scope));
    return '$account:$membership';
  }

  /// Verifies the durable barriers even if Android restores a preference
  /// deletion that had not reached disk when the process stopped.
  Future<List<NotificationInboxEntry>> authorizedInbox(
    String uid,
    List<NotificationInboxEntry> entries,
  ) async {
    final guard = await activeChat();
    final scope = guard['scope'];
    if (guard['enabled'] != true || guard['uid'] != uid || scope is! String) {
      return const [];
    }
    final historyKey = 'history:$scope';
    final accountKey = _inboxAccountKey(uid);
    final scopeKey = _inboxScopeKey(scope);
    // One query reads all three barriers from the same SQLite snapshot.
    final rows = await customSelect(
      'SELECT key, value FROM chat_metadata WHERE key IN (?, ?, ?)',
      variables: [Variable(historyKey), Variable(accountKey), Variable(scopeKey)],
    ).get();
    final barriers = {
      for (final row in rows)
        row.read<String>('key'): jsonDecode(row.read<String>('value')) as Map,
    };
    final minimum = barriers[historyKey]?['minimum'] as int? ?? 0;
    final account = barriers[accountKey]?['revision'] as int? ?? 0;
    final membership = barriers[scopeKey]?['revision'] as int? ?? 0;
    final revision = '$account:$membership';
    final latestGuard = await activeChat();
    if (latestGuard['stamp'] != guard['stamp']) return const [];
    return entries.where((entry) {
      final payload = entry.data['payload'];
      if (payload is! Map ||
          payload['uid'] != uid ||
          payload['scope'] != scope) {
        return false;
      }
      return payload['inboxRevision'] == revision &&
          ((payload['historyGeneration'] as int?) ?? 0) >= minimum;
    }).toList();
  }

  Future<void> clearScope(String scope, {bool preserveHistory = false}) =>
      transaction(() async {
        await _lockActive();
        await _notificationInbox?.purgeFamilyChat(scope: scope);
        await _advanceInboxRevision(_inboxScopeKey(scope));
        if (!preserveHistory) {
          await customStatement('DELETE FROM chat_metadata WHERE key=?', [
            'history:$scope',
          ]);
        }
        if ((await metadata('chatOpen'))?['scope'] == scope) {
          await customStatement(
            "DELETE FROM chat_metadata WHERE key='chatOpen'",
          );
        }
        for (final table in [
          'chat_messages',
          'chat_tickets',
          'chat_outbox',
          'chat_actions',
          'chat_drafts',
          'chat_local_reads',
        ]) {
          await customStatement('DELETE FROM $table WHERE scope=?', [scope]);
        }
        final prefix = 'cursor:$scope:';
        await customStatement(
          'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
          [prefix.length, prefix],
        );
        final outcomes = 'outcome:$scope:';
        await customStatement(
          'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
          [outcomes.length, outcomes],
        );
        final replyPrefix = 'notificationReply:$scope:';
        await customStatement(
          'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
          [replyPrefix.length, replyPrefix],
        );
        final draftPrefix = 'notificationDraft:$scope:';
        await customStatement(
          'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
          [draftPrefix.length, draftPrefix],
        );
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'threads:$scope',
        ]);
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'retention:$scope',
        ]);
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'purgedAt:$scope',
        ]);
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'shortcuts:$scope',
        ]);
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'shortcutEdit:$scope',
        ]);
        await customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'shortcutAttempt:$scope',
        ]);
      });

  Future<void> clearAccount(
    String uid, {
    bool preserveHistory = false,
  }) => transaction(() async {
    await _lockActive();
    await _notificationInbox?.purgeFamilyChat(uid: uid);
    await _advanceInboxRevision(_inboxAccountKey(uid));
    if ((await metadata('chatOpen'))?['uid'] == uid) {
      await customStatement("DELETE FROM chat_metadata WHERE key='chatOpen'");
    }
    final rows = await customSelect(
      'SELECT scope FROM chat_messages UNION SELECT scope FROM chat_outbox UNION SELECT scope FROM chat_actions UNION SELECT scope FROM chat_drafts UNION SELECT scope FROM chat_tickets UNION SELECT scope FROM chat_local_reads UNION SELECT scope FROM chat_notifications',
    ).get();
    for (final row in rows) {
      final scope = row.read<String>('scope');
      final parts = jsonDecode(scope) as List;
      if (parts.first == uid) {
        await clearScope(scope, preserveHistory: preserveHistory);
      }
    }
    for (final kind in [
      if (!preserveHistory) 'history:',
      'cursor:',
      'threads:',
      'retention:',
      'purgedAt:',
      'shortcuts:',
      'shortcutEdit:',
      'shortcutAttempt:',
      'notificationReply:',
      'notificationDraft:',
      'outcome:',
    ]) {
      final prefix =
          '$kind${jsonEncode([uid]).substring(0, jsonEncode([uid]).length - 1)},';
      await customStatement(
        'DELETE FROM chat_metadata WHERE substr(key,1,?)=?',
        [prefix.length, prefix],
      );
    }
    await customStatement('DELETE FROM chat_metadata WHERE key=?', [
      'account:$uid',
    ]);
  });

  Future<int> validTicketCount(String scope, int now) async =>
      (await customSelect(
        'SELECT COUNT(*) AS n FROM chat_tickets WHERE scope=? AND expires_at>?',
        variables: [Variable(scope), Variable(now)],
      ).getSingle()).read<int>('n');
  Future<void> invalidateTickets(String scope) =>
      customStatement('DELETE FROM chat_tickets WHERE scope=?', [scope]);
  Future<void> applyRetention(
    String scope,
    Map policy,
  ) => transaction(() async {
    final applied =
        (await metadata('retention:$scope'))?['revision'] as int? ?? -1;
    if ((policy['revision'] as int? ?? 0) < applied) return;
    for (final change in policy['shortenings'] as List? ?? []) {
      const shortened = "CAST(json_extract(payload,'\$.sentAt') AS INTEGER)+?";
      final cutoff = (change['days'] as int) * 86400000;
      await customStatement(
        "UPDATE chat_notifications SET status='cancel' WHERE scope=? AND tag IN (SELECT ? || id FROM chat_messages WHERE scope=? AND COALESCE(json_extract(payload,'\$.policyRevision'),0)<? AND (expires_at IS NULL OR expires_at>$shortened))",
        [
          scope,
          familyChatNotificationTagPrefix(scope),
          scope,
          change['revision'],
          cutoff,
        ],
      );
      await customStatement(
        "UPDATE chat_messages SET payload=json_set(payload,'\$._notificationSuppressed',json('true')) WHERE scope=? AND (? || id) IN (SELECT tag FROM chat_notifications WHERE scope=? AND status='cancel')",
        [scope, familyChatNotificationTagPrefix(scope), scope],
      );
      await customStatement(
        "UPDATE chat_messages SET expires_at=$shortened, payload=json_set(payload,'\$.expiresAt',$shortened) WHERE scope=? AND COALESCE(json_extract(payload,'\$.policyRevision'),0)<? AND (expires_at IS NULL OR expires_at>$shortened)",
        [
          (change['days'] as int) * 86400000,
          (change['days'] as int) * 86400000,
          scope,
          change['revision'],
          (change['days'] as int) * 86400000,
        ],
      );
      for (final table in ['chat_outbox', 'chat_drafts']) {
        final time = table == 'chat_outbox' ? 'created_at' : 'updated_at';
        await customStatement(
          'UPDATE $table SET retention_until=$time+? WHERE scope=? AND policy_revision<? AND (retention_until IS NULL OR retention_until>$time+?)',
          [
            (change['days'] as int) * 86400000,
            scope,
            change['revision'],
            (change['days'] as int) * 86400000,
          ],
        );
      }
    }
    await setMetadata('retention:$scope', {
      'revision': policy['revision'] ?? 0,
      'retention': policy['retention'] ?? 'week',
      'shortenings': policy['shortenings'] ?? [],
    });
  });
}
