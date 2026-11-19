import 'dart:async';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';

class FamilyChatTestApi implements FamilyChatApi {
  FamilyChatTestApi(this.uid, {this.caregiver = false});
  final String uid;
  final bool caregiver;
  final additionalMembers = <Map<String, Object?>>[];
  int ticket = 0;
  int configCalls = 0;
  bool offlineConfig = false;
  String? heldOperation;
  Completer<void>? operationEntered, operationRelease;
  Map<String, dynamic> shortcutState = {
    'items': null,
    'revision': 0,
    'order': [],
    'orderRevision': 0,
  };
  bool failShortcutSave = false;
  bool failShortcutFetch = false;
  bool failAfterShortcutCommit = false;
  bool accountEnabled = true;
  String familyId = 'f';

  /// Operations that passed allowRequest and would have been posted.
  final dispatchedOperations = <String>[];

  /// Operations refused by allowRequest after simulated identity.
  final rejectedOperations = <String>[];
  String epoch = 'e';
  Map<String, bool?>? unreadByTarget;
  final conversationSummaryOverrides = <String, Object?>{};
  Completer<void>? shortcutResponseGate;
  Completer<void>? shortcutCommitEntered;
  Completer<void>? shortcutSaveGate;
  Completer<void>? shortcutOrderGate;
  Completer<void>? shortcutFetchGate;
  Completer<void>? shortcutFetchEntered;
  Completer<void>? fetchGate;
  Completer<void>? sendGate;
  int sendRequests = 0;
  String? rejectSendReason;
  final sendPayloads = <Map<String, Object?>>[];
  final readIds = <String>{};
  final messages = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (operation == heldOperation) {
      heldOperation = null;
      operationEntered!.complete();
      await operationRelease!.future;
    }
    // heldOperation above simulates the transport's identity resolution; the
    // admission check runs afterwards exactly like the real transport.
    if (allowRequest != null && !await allowRequest()) {
      rejectedOperations.add(operation);
      throw const CallableFailure('cancelled');
    }
    dispatchedOperations.add(operation);
    switch (operation) {
      case 'fetchFamilyChatShortcuts':
        if (shortcutFetchGate != null) {
          if (shortcutFetchEntered?.isCompleted == false) {
            shortcutFetchEntered!.complete();
          }
          await shortcutFetchGate!.future;
        }
        if (failShortcutFetch) throw const CallableFailure('unavailable');
        return Map.of(shortcutState);
      case 'saveFamilyChatShortcuts':
        if (shortcutSaveGate != null) await shortcutSaveGate!.future;
        if (failShortcutSave) throw const CallableFailure('unavailable');
        if (data['expectedRevision'] != shortcutState['revision']) {
          throw const CallableFailure(
            'rejected',
            rejectionCode: 'already-exists',
          );
        }
        shortcutState = {
          ...shortcutState,
          'items': data['items'],
          'revision': (shortcutState['revision'] as int) + 1,
        };
        final responseGate = shortcutResponseGate;
        shortcutResponseGate = null;
        if (responseGate != null) {
          shortcutCommitEntered?.complete();
          await responseGate.future;
        }
        if (failAfterShortcutCommit) throw const CallableFailure('unavailable');
        return {'ok': true};
      case 'orderFamilyChatShortcuts':
        if (shortcutOrderGate != null) await shortcutOrderGate!.future;
        shortcutState = {
          ...shortcutState,
          'order': data['ids'],
          'orderRevision': (shortcutState['orderRevision'] as int) + 1,
        };
        return {'ok': true};
      case 'getFamilyChatConfig':
        configCalls++;
        if (offlineConfig) throw const CallableFailure('unavailable');
        return {
          'uid': uid,
          'familyId': familyId,
          'epoch': epoch,
          'serverTime': now,
          'account': {
            'enabled': accountEnabled,
            'revision': 0,
            'offGeneration': 0,
          },
          'policy': {
            'enabled': true,
            'revision': 0,
            'retention': 'week',
            'offGeneration': 0,
            'shortenings': [],
          },
          'members': [
            {
              'uid': uid,
              'role': caregiver ? 'managingCaregiver' : 'child',
              'displayName': caregiver ? 'Rodzic' : 'Dziecko Z',
            },
            {
              'uid': 'mom',
              'role': caregiver ? 'child' : 'managingCaregiver',
              'displayName': caregiver ? 'Dziecko Z' : 'Ola',
            },
            ...additionalMembers,
          ],
        };
      case 'fetchFamilyChatConversations':
        return {
          'conversations': [
            for (final row in (unreadByTarget ?? {}).entries)
              {'targetUid': row.key, 'hasUnread': row.value},
          ],
          'cursor': '',
          'hasMore': false,
          if (unreadByTarget != null) ...{
            'familyId': familyId,
            'epoch': epoch,
            'historyGeneration': 0,
            'serverTime': now,
          },
          ...conversationSummaryOverrides,
        };
      case 'fetchFamilyChatMessageStates':
        return {
          'messages': messages
              .where((row) => (data['ids'] as List).contains(row['id']))
              .toList(),
          'missing': <String>[],
        };
      case 'fetchFamilyChatMessages':
        if (data['targetUid'] == 'mom' && fetchGate != null) {
          await fetchGate!.future;
        }
        var rows = ['mom', 'family'].contains(data['targetUid'])
            ? messages
                  .where(
                    (row) =>
                        (data['targetUid'] != 'family' ||
                            row['conversationId'] == 'family') &&
                        (data['before'] != null
                            ? (row['sequence'] as int) < (data['before'] as int)
                            : (row['sequence'] as int) >
                                  (data['after'] as int? ?? 0)),
                  )
                  .toList()
            : <Map<String, dynamic>>[];
        if (data['latest'] == true || data['before'] != null) {
          rows = rows.reversed.take(50).toList().reversed.toList();
        } else {
          rows = rows.take(50).toList();
        }
        return {
          'messages': rows.where((row) => row['hidden'] != true).toList(),
          'oldestCursor': rows.isEmpty
              ? data['before'] ?? 0
              : rows.first['sequence'],
          'cursor': rows.isEmpty ? data['after'] ?? 0 : rows.last['sequence'],
          'hasMore': rows.length == 50,
        };
      case 'reserveFamilyChatOperations':
        return {
          'tickets': [
            for (var i = 0; i < (data['count'] as int); i++)
              {
                'id': '$uid-${++ticket}',
                'token': '$uid-$ticket',
                'expiresAt': now + 86400000,
              },
          ],
        };
      case 'sendFamilyChatMessage':
        sendRequests++;
        sendPayloads.add(Map.of(data));
        if (rejectSendReason != null) {
          throw CallableFailure(
            'rejected',
            rejectionCode: 'failed-precondition',
            rejectionReason: rejectSendReason,
          );
        }
        if (sendGate != null) await sendGate!.future;
        final existing = messages
            .where((row) => row['id'] == data['ticket'])
            .firstOrNull;
        if (existing != null) return {'message': existing};
        if (data['verifyOnly'] == true) {
          throw const CallableFailure(
            'rejected',
            rejectionCode: 'failed-precondition',
            rejectionReason: 'chat-send-outcome-unknown',
          );
        }
        final row = {
          'id': data['ticket'],
          'senderUid': uid,
          'text': data['text'],
          'kind': data['kind'],
          'answers': data['answers'],
          'replyTo': data['replyTo'],
          if (data['answerIndex'] != null) 'answerIndex': data['answerIndex'],
          'conversationId': data['targetUid'] == 'family' ? 'family' : 'direct',
          if (data['treatment'] != null) 'treatment': data['treatment'],
          'sequence': messages.length + 1,
          'sentAt': now,
          'expiresAt': now + 86400000,
          'receipts': <String, dynamic>{
            'mom': {'readAt': null, 'deliveredAt': null},
          },
        };
        messages.add(row);
        return {'message': row};
      case 'acknowledgeFamilyChatMessages':
        final items = data['items'] as List;
        for (final item in items) {
          if (item['read'] == true) readIds.add(item['messageId'] as String);
        }
        return {
          'acknowledged': items.map((item) => item['messageId']).toList(),
          'ignored': <String>[],
        };
    }
    throw StateError(operation);
  }
}
