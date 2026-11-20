import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/models/hash_notification_id_factory.dart';
import '../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../core/notifications/domain/models/notification_key.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_notification_platform.dart';
import '../data/family_chat_remote.dart';
import '../domain/family_question_reply_state.dart';
import '../domain/family_treatment_authorization.dart';

FamilyChatNotice familyChatNotice(String scope, String messageId) {
  final tag = '${familyChatNotificationTagPrefix(scope)}$messageId';
  final bytes = sha256.convert(utf8.encode(tag)).bytes;
  final entityId = bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
  return (
    id: const HashNotificationIdFactory().create(
      NotificationKey(
        type: NotificationEventType.familyChat,
        entityId: entityId,
      ),
    ),
    tag: tag,
  );
}

class FamilyChatPushView {
  const FamilyChatPushView(
    this.guard,
    this.config,
    this.message,
    this.target, {
    this.elapsedMilliseconds,
  });
  final Map<String, dynamic> guard, config, message;
  final String target;
  final int Function()? elapsedMilliseconds;
  FamilyChatNotice get notice =>
      familyChatNotice(guard['scope'] as String, message['id'] as String);
  int? get remainingLifetime {
    var until = message['expiresAt'] as int?;
    if (message['kind'] == 'lowTreatment') {
      final clinical = message['treatment']?['validUntil'] as int? ?? 0;
      if (until == null || clinical < until) until = clinical;
    }
    return until == null
        ? null
        : (until -
                  (config['serverTime'] as int) -
                  (elapsedMilliseconds?.call() ?? 0))
              .clamp(0, 2147483647);
  }

  FamilyChatPushView withInboxRevision(String revision) => FamilyChatPushView(
    {...guard, 'inboxRevision': revision},
    config,
    message,
    target,
    elapsedMilliseconds: elapsedMilliseconds,
  );

  Map<String, dynamic> get payload => {
    'type': 'familyChat',
    ...guard,
    'messageId': message['id'],
    'historyGeneration': message['historyGeneration'] ?? 0,
    'target': target,
    if (message['kind'] == 'lowTreatment' &&
        familyTreatmentAuthorizationFromConfig(config) != null)
      'authorization': familyTreatmentAuthorizationJson(
        familyTreatmentAuthorizationFromConfig(config)!,
      ),
  };
}

abstract interface class FamilyChatPushPresenter {
  Future<void> show(FamilyChatPushView view);
  Future<void> cancel(FamilyChatNotice notice);
  Future<void> replyCompleted(FamilyChatNotice notice, FamilyChatPushView view);
  Future<void> pending(FamilyChatPushView view, {required bool needsTicket});
}

/// Background work never activates a guard; only fresh foreground identity can.
class FamilyChatBackground {
  const FamilyChatBackground({
    required this.db,
    required this.api,
    required this.currentUid,
    required this.presenter,
    this.rolloutEnabled = true,
    this.clock = DateTime.now,
    this.shouldPresent,
  });
  static final _unreadChanges = StreamController<String>.broadcast();

  /// Notifies sessions after an incoming message or local read receipt commits.
  static Stream<String> get unreadChanges => _unreadChanges.stream;

  final bool rolloutEnabled;
  final DateTime Function() clock;
  final bool Function(String target)? shouldPresent;
  final FamilyChatDatabase db;
  final FamilyChatApi api;
  final String? Function() currentUid;
  final FamilyChatPushPresenter presenter;
  bool _id(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

  Future<FamilyChatPushView?> _validated(
    Map<String, dynamic> data, {
    Map<String, dynamic>? requiredGuard,
  }) async {
    if (data.length != 5 ||
        data['type'] != 'familyChat' ||
        ![
          'uid',
          'familyId',
          'epoch',
          'messageId',
        ].every((key) => _id(data[key]))) {
      return null;
    }
    final uid = data['uid'] as String;
    if (currentUid() != uid) return null;
    final guard = await db.activeChat();
    final scope = jsonEncode([uid, data['familyId'], data['epoch']]);
    if (guard['enabled'] != true ||
        guard['uid'] != uid ||
        guard['scope'] != scope ||
        requiredGuard != null &&
            [
              'uid',
              'scope',
              'stamp',
            ].any((key) => guard[key] != requiredGuard[key])) {
      return null;
    }
    final watch = Stopwatch()..start();
    final config = await api.call('getFamilyChatConfig', {});
    if (currentUid() != uid ||
        config['uid'] != uid ||
        config['familyId'] != data['familyId'] ||
        config['epoch'] != data['epoch'] ||
        config['account']?['enabled'] != true ||
        config['policy']?['enabled'] != true) {
      return null;
    }
    final observed = config['historyGeneration'] ?? 0;
    if (observed is! int || observed < 0) return null;
    final admitted = await db.withChatGuard(guard, () async {
      if (currentUid() != uid) return false;
      final history = await db.observeHistoryGeneration(scope, observed);
      return observed >= (history['confirmed'] as int? ?? 0);
    });
    if (admitted != true) return null;
    for (final notice in await db.historyCancellationIntents(scope)) {
      try {
        await presenter.cancel(notice);
        await db.confirmCancelled(notice);
      } catch (_) {
        // Keep the durable cancellation intent for the next synchronization.
      }
    }
    final result = await api.call('fetchFamilyChatMessageStates', {
      'ids': [data['messageId']],
    });
    if (currentUid() != uid) return null;
    final rows = result['messages'] as List;
    if (rows.length != 1) return null;
    final message = Map<String, dynamic>.from(rows.single as Map);
    final generation = message['historyGeneration'] ?? 0;
    if (generation is! int ||
        !await db.historyAllows(scope, generation) ||
        requiredGuard != null &&
            requiredGuard['historyGeneration'] != generation) {
      return null;
    }
    if (message['id'] != data['messageId'] ||
        message['senderUid'] == uid ||
        message['participants']?[uid] != data['epoch'] ||
        message['receipts']?[uid] == null) {
      return null;
    }
    final time = result['serverTime'] as int? ?? config['serverTime'] as int;
    if (message['expiresAt'] != null && (message['expiresAt'] as int) <= time) {
      return null;
    }
    if (message['kind'] == 'lowTreatment' &&
        ((message['treatment']?['validUntil'] as int? ?? 0) <= time ||
            message['treatmentResult'] != null)) {
      return null;
    }
    final peers = (message['participants'] as Map).keys
        .where((key) => key != uid)
        .toList();
    if (message['conversationId'] != 'family' && peers.length != 1) return null;
    final target = message['conversationId'] == 'family'
        ? 'family'
        : peers.single as String;
    final view = FamilyChatPushView(
      {...guard, 'historyGeneration': generation},
      {...config, 'serverTime': time},
      message,
      target,
      elapsedMilliseconds: () => watch.elapsedMilliseconds,
    );
    return view.remainingLifetime == 0 ? null : view;
  }

  Future<bool> receive(Map<String, dynamic> data) async {
    if (!rolloutEnabled) return false;
    final view = await _validated(data);
    if (view == null) return false;
    final guard = view.guard, message = view.message;
    final scope = guard['scope'] as String,
        uid = guard['uid'] as String,
        id = message['id'] as String;
    final saved = await db.withChatGuard(guard, () async {
      if (currentUid() != uid) return false;
      final saved = await db.saveMessage(
        scope,
        view.target,
        message,
        serverNow:
            (view.config['serverTime'] as int) +
            (view.elapsedMilliseconds?.call() ?? 0),
      );
      if (!saved) return false;
      await db.queueReceipt(scope, id, false);
      return true;
    });
    if (saved == true) _unreadChanges.add(scope);
    if (currentUid() == uid) {
      await FamilyChatNotificationPlatform.cancel(
        db,
        await db.historyCancellationIntents(scope),
        operation: presenter.cancel,
        keepTrying: () => false,
      );
    }
    if (saved != true) return false;
    await presentIncoming(view);
    if (currentUid() == uid &&
        await db.historyAllows(scope, guard['historyGeneration'] as int)) {
      final capturedUid = uid;
      final capturedScope = scope;
      final capturedStamp = guard['stamp'] as String;
      final capturedHistoryGen = guard['historyGeneration'] as int;
      await api.call(
        'acknowledgeFamilyChatMessages',
        {
          'items': [
            {'messageId': id, 'read': false},
          ],
        },
        allowRequest: () => _allowRequest(
          uid: capturedUid,
          scope: capturedScope,
          stamp: capturedStamp,
          historyGeneration: capturedHistoryGen,
        ),
      );
      await db.withChatGuard(guard, () => db.completeReceipt(scope, id, false));
    }
    return true;
  }

  /// Uses the same journal for push and authenticated foreground sync.
  Future<void> presentIncoming(FamilyChatPushView view) async {
    final guard = view.guard;
    final scope = guard['scope'] as String;
    final uid = guard['uid'] as String;
    final id = view.message['id'] as String;
    if (currentUid() != uid ||
        view.message['senderUid'] == uid ||
        view.message['participants']?[uid] != view.config['epoch'] ||
        view.message['receipts']?[uid] == null ||
        view.message['kind'] == 'lowTreatment' &&
            view.message['treatmentResult'] != null ||
        view.remainingLifetime == 0) {
      return;
    }
    final cached = await db.message(scope, id);
    final locallyRead = await db.locallyRead(scope, id);
    if (cached != null &&
        cached['expiresAt'] == view.message['expiresAt'] &&
        cached['_notificationSuppressed'] != true &&
        cached['receipts']?[uid]?['readAt'] == null &&
        (cached['kind'] != 'question' ||
            !await db.hasAuthoredReply(scope, uid, id)) &&
        !locallyRead) {
      if (shouldPresent?.call(view.target) == false) {
        Log.d('FamilyChatPush', 'Notification suppressed by UI visibility');
        return;
      }
      final presented = await db.presentNotification(
        guard,
        view.notice,
        show: () async {
          final latest = await db.message(scope, id);
          if (currentUid() != uid ||
              !(shouldPresent?.call(view.target) ?? true) ||
              latest == null ||
              latest['_notificationSuppressed'] == true ||
              latest['receipts']?[uid]?['readAt'] != null ||
              latest['expiresAt'] != view.message['expiresAt'] ||
              (latest['kind'] == 'question' &&
                  await db.hasAuthoredReply(scope, uid, id)) ||
              await db.locallyRead(scope, id)) {
            return;
          }
          await presenter.show(
            view.withInboxRevision(
              await db.notificationInboxRevision(uid, scope),
            ),
          );
          Log.d('FamilyChatPush', 'Notification handed to presenter');
        },
        cancel: () => presenter.cancel(view.notice),
      );
      if (!presented) {
        Log.d('FamilyChatPush', 'Notification journal skipped presentation');
      }
    }
  }

  /// The reply is durable before HTTP and uses the existing ticket ID on retry.
  Future<bool> reply(
    Map<String, dynamic> payload,
    String input, {
    bool treatmentUnavailable = false,
    int? answerIndex,
  }) async {
    if (!rolloutEnabled) return false;
    if (payload['type'] != 'familyChat') return false;
    final required = {
      'uid': payload['uid'],
      'scope': payload['scope'],
      'stamp': payload['stamp'],
      'historyGeneration': payload['historyGeneration'] ?? 0,
    };
    final cached = await _cachedReply(payload, required);
    if (cached == null) return false;
    if (answerIndex != null) {
      final answers = cached.message['answers'];
      if (cached.message['kind'] != 'question' ||
          answers is! List ||
          answerIndex < 0 ||
          answerIndex >= answers.length ||
          answers[answerIndex] is! String) {
        return false;
      }
      input = answers[answerIndex] as String;
    }
    final text = input.trim();
    if (text.isEmpty || text.length > 64000) return false;
    if (treatmentUnavailable &&
        (cached.message['kind'] != 'lowTreatment' ||
            cached.message['treatmentResult'] != null ||
            (cached.message['treatment']?['validUntil'] as int? ?? 0) <=
                (cached.config['serverTime'] as int))) {
      return false;
    }
    final guard = cached.guard,
        uid = guard['uid'] as String,
        scope = guard['scope'] as String;
    final parent = payload['messageId'] as String;
    final digest = sha256.convert(utf8.encode(text)).toString();
    final key = 'notificationReply:$scope:$parent';
    final time = cached.config['serverTime'] as int;
    // Persist the action before any network, including configuration or tickets.
    var created = false;
    final queued = await db.withChatGuard(guard, () async {
      if (currentUid() != uid) return false;
      final existing = await db.metadata(key);
      if (existing != null) {
        // Pending or ambiguous: only the same text may continue the existing
        // operation; never create or rebase one. A definitively failed
        // operation must not deadlock a conscious new answer.
        final operation = (await db.outbox(
          scope,
        )).where((row) => row.read<String>('id') == existing['id']).firstOrNull;
        final failed =
            operation != null &&
            familyReplyOperationStatus(
                  error: operation.readNullable<String>('error'),
                  signed:
                      (jsonDecode(operation.read<String>('payload'))
                              as Map)['ticket']
                          is String,
                ) ==
                FamilyQuestionReplyStatus.failed;
        if (!failed) return existing['digest'] == digest;
      }
      if (await db.hasAuthoredReply(scope, uid, parent)) return false;
      final body = <String, dynamic>{
        'kind': 'answer',
        'text': text,
        'answers': <String>[],
        'replyTo': payload['messageId'],
      };
      var id = cached.config['_clockTrusted'] == true
          ? await db.enqueue(
              scope,
              cached.target,
              body,
              time,
              policy: cached.config['policy'] as Map?,
            )
          : null;
      if (id == null) {
        // A fresh local ID after a known failure, so the failed row stays visible.
        id =
            'unsent_${sha256.convert(utf8.encode(existing == null ? key : '$key:${existing['id']}'))}';
        final saved = await db.enqueueUnsentReply(
          scope,
          id,
          cached.target,
          body,
          time,
          key,
          policy: cached.config['policy'] as Map?,
        );
        if (!saved) return false;
      }
      await db.setMetadata(key, {
        'id': id,
        'digest': digest,
        'expiresAt': cached.message['expiresAt'],
      });
      await db.queueReceipt(scope, payload['messageId'] as String, true);
      created = true;
      return true;
    });
    if (queued != true) return false;
    _unreadChanges.add(scope);
    Future<void> cancelCompleted({bool acknowledge = false}) async {
      if (currentUid() != uid) return;
      final tag = cached.notice.tag;
      final notices = (await db.historyCancellationIntents(
        scope,
        includeDeferred: acknowledge,
      )).where((notice) => notice.tag == tag).toList();
      if (acknowledge && notices.isNotEmpty) {
        try {
          final updated = await db.withChatGuard(guard, () async {
            if (currentUid() != uid ||
                !await db.notificationCancelling(scope, tag)) {
              return false;
            }
            for (final notice in notices) {
              if (await db.hasCancellationIntent(notice)) {
                await presenter.replyCompleted(notice, cached);
              }
            }
            await db.deferReplyCancellation(tag);
            return true;
          });
          if (updated == true) return;
        } catch (_) {
          // Fall back to actual cancellation if the OS update fails.
        }
        await db.clearReplyAcknowledgment(tag);
      }
      await FamilyChatNotificationPlatform.cancel(
        db,
        notices,
        operation: presenter.cancel,
        keepTrying: () => false,
      );
    }

    Future<void> pending(bool needsTicket) async {
      if (!await db.hasCancellationIntent(cached.notice) &&
          !await db.prepareNotification(guard, cached.notice)) {
        return;
      }
      await db.withChatGuard(guard, () async {
        final latest = await db.message(scope, payload['messageId'] as String);
        if (currentUid() == uid &&
            latest?['_notificationSuppressed'] != true &&
            latest?['receipts']?[uid]?['readAt'] == null &&
            !await db.notificationCancelling(scope, cached.notice.tag)) {
          await presenter.pending(
            cached.withInboxRevision(
              await db.notificationInboxRevision(uid, scope),
            ),
            needsTicket: needsTicket,
          );
        }
      });
    }

    var marker = await db.metadata(key);
    if (marker == null || currentUid() != uid) return true;
    if (!(await db.outbox(
      scope,
    )).any((row) => row.read<String>('id') == marker!['id'])) {
      await cancelCompleted();
      return true;
    }
    FamilyChatPushView? fresh;
    try {
      final parts = jsonDecode(scope) as List;
      fresh = await _validated({
        'type': 'familyChat',
        'uid': uid,
        'familyId': parts[1],
        'epoch': parts[2],
        'messageId': payload['messageId'],
      }, requiredGuard: required);
      if (fresh == null) {
        await db.withChatGuard(
          guard,
          () => db.failOperation(scope, marker!['id'] as String, 'expired'),
        );
        await pending(true);
        return true;
      }
      var operation = (await db.outbox(
        scope,
      )).where((row) => row.read<String>('id') == marker!['id']).firstOrNull;
      if (operation?.readNullable<String>('error') == 'needs-ticket') {
        if (!created) {
          await pending(true);
          return true;
        }
        if (await db.validTicketCount(
              scope,
              fresh.config['serverTime'] as int,
            ) ==
            0) {
          final capturedUid = uid;
          final capturedScope = scope;
          final capturedStamp = guard['stamp'] as String;
          final tickets = await api.call(
            'reserveFamilyChatOperations',
            {'count': 1},
            allowRequest: () => _allowRequest(
              uid: capturedUid,
              scope: capturedScope,
              stamp: capturedStamp,
              historyGeneration: null,
            ),
          );
          await db.withChatGuard(
            guard,
            () => db.addTickets(scope, tickets['tickets'] as List),
          );
        }
        await db.withChatGuard(
          guard,
          () => db.promoteNotificationDraft(
            scope,
            marker!['id'] as String,
            fresh!.config['serverTime'] as int,
            target: fresh.target,
          ),
        );
        marker = await db.metadata(key);
        operation = (await db.outbox(
          scope,
        )).where((row) => row.read<String>('id') == marker!['id']).firstOrNull;
      }
      if (operation != null &&
          await db.historyAllows(scope, guard['historyGeneration'] as int)) {
        final capturedUid = uid;
        final capturedScope = scope;
        final capturedStamp = guard['stamp'] as String;
        final capturedHistoryGen = guard['historyGeneration'] as int;
        final response = await api.call(
          'sendFamilyChatMessage',
          Map<String, Object?>.from(
            jsonDecode(operation.read<String>('payload')) as Map,
          ),
          allowRequest: () => _allowRequest(
            uid: capturedUid,
            scope: capturedScope,
            stamp: capturedStamp,
            historyGeneration: capturedHistoryGen,
          ),
        );
        final completed = await db.withChatGuard(guard, () async {
          if (currentUid() != uid ||
              !(await db.outbox(scope)).any(
                (row) =>
                    row.read<String>('id') == operation!.read<String>('id'),
              )) {
            return false;
          }
          await db.saveMessage(
            scope,
            fresh!.target,
            Map<String, dynamic>.from(response['message'] as Map),
            serverNow:
                (fresh.config['serverTime'] as int) +
                (fresh.elapsedMilliseconds?.call() ?? 0),
          );
          await db.markMessageNotificationForCancellation(scope, parent);
          if (await db.notificationCancelling(scope, cached.notice.tag)) {
            await db.deferReplyCancellation(cached.notice.tag);
          }
          await db.complete(scope, operation!.read<String>('id'));
          return true;
        });
        if (completed == true) {
          await cancelCompleted(acknowledge: true);
        }
      }
      if (currentUid() == uid &&
          await db.historyAllows(scope, guard['historyGeneration'] as int)) {
        final capturedUid = uid;
        final capturedScope = scope;
        final capturedStamp = guard['stamp'] as String;
        final capturedHistoryGen = guard['historyGeneration'] as int;
        await api.call(
          'acknowledgeFamilyChatMessages',
          {
            'items': [
              {'messageId': payload['messageId'], 'read': true},
            ],
          },
          allowRequest: () => _allowRequest(
            uid: capturedUid,
            scope: capturedScope,
            stamp: capturedStamp,
            historyGeneration: capturedHistoryGen,
          ),
        );
        await db.withChatGuard(
          guard,
          () => db.completeReceipt(scope, payload['messageId'] as String, true),
        );
      }
    } on CallableFailure catch (failure) {
      if (!_networkFailure(failure)) {
        await db.withChatGuard(
          guard,
          () => db.failOperation(
            scope,
            marker!['id'] as String,
            // Same classification as the foreground sender: the server could
            // not tell whether this signed operation was already accepted.
            failure.rejectionCode == 'failed-precondition' &&
                    failure.rejectionReason == 'chat-send-outcome-unknown'
                ? 'send-outcome-unknown'
                : failure.rejectionCode ?? failure.code,
          ),
        );
      }
      final operation = (await db.outbox(
        scope,
      )).where((row) => row.read<String>('id') == marker!['id']).firstOrNull;
      if (operation != null) {
        await pending(operation.readNullable<String>('error') != null);
      }
    }
    return true;
  }

  /// Final admission check the transport runs after identity resolution.
  ///
  /// Each async read is followed by a synchronous account recheck, so an OFF,
  /// account switch or durable history clear (possibly from another SQLite
  /// connection) that lands while identity or a fence read is pending blocks
  /// the request before anything is posted.
  Future<bool> _allowRequest({
    required String uid,
    required String scope,
    required String stamp,
    required int? historyGeneration,
  }) async {
    if (currentUid() != uid) return false;
    if (await db.fence.accountRevocation(uid) != null) return false;
    if (currentUid() != uid) return false;
    // Captured guard (and durable history when captured) is verified under
    // the writer lock and re-read after the synchronous action, so a same-UID
    // OFF->ON by another actor cannot slip through.
    final admitted = await db.withChatGuard({
      'uid': uid,
      'scope': scope,
      'stamp': stamp,
      'historyGeneration': ?historyGeneration,
    }, () async => currentUid() == uid);
    return admitted == true && currentUid() == uid;
  }

  bool _networkFailure(CallableFailure failure) =>
      failure.code == 'unavailable' &&
      (failure.rejectionCode == null || failure.rejectionCode == 'unavailable');
  Future<FamilyChatPushView?> _cachedReply(
    Map<String, dynamic> payload,
    Map<String, dynamic> required,
  ) async {
    final uid = payload['uid'] as String, scope = payload['scope'] as String;
    if (currentUid() != uid ||
        !_id(payload['messageId']) ||
        !_id(payload['target'])) {
      return null;
    }
    final generation = required['historyGeneration'];
    if (generation is! int || !await db.historyAllows(scope, generation)) {
      return null;
    }
    final guard = await db.activeChat();
    if (guard['enabled'] != true ||
        ['uid', 'scope', 'stamp'].any((key) => guard[key] != required[key])) {
      return null;
    }
    final parts = jsonDecode(scope) as List;
    if (parts.length != 3 || parts.first != uid) return null;
    final saved = await db.metadata('account:$uid');
    if (saved != null &&
        (saved['account']?['enabled'] != true ||
            saved['policy']?['enabled'] != true ||
            jsonEncode([uid, saved['familyId'], saved['epoch']]) != scope)) {
      return null;
    }
    final wall = clock().millisecondsSinceEpoch;
    final trusted =
        saved?['_observedLocalAt'] is int &&
        wall >= (saved!['_observedLocalAt'] as int);
    final now = trusted
        ? [
            wall + (saved['_serverOffset'] as int? ?? 0),
            saved['_lastServerNow'] as int? ?? 0,
          ].reduce((a, b) => a > b ? a : b)
        : wall;
    var target = payload['target'] as String;
    final cached = await db.message(scope, payload['messageId'] as String);
    final message =
        cached ??
        <String, dynamic>{
          'id': payload['messageId'],
          'senderUid': target,
          'conversationId': target == 'family' ? 'family' : 'direct_unknown',
          'text': '',
          'answers': <String>[],
          'sentAt': now,
          'expiresAt': null,
        };
    if (cached != null &&
        ((cached['historyGeneration'] ?? 0) != generation ||
            cached['participants']?[uid] != parts[2] ||
            cached['receipts']?[uid] == null)) {
      return null;
    }
    if (cached != null) {
      final peers = (cached['participants'] as Map).keys
          .where((key) => key != uid)
          .toList();
      if (cached['conversationId'] != 'family' && peers.length != 1) {
        return null;
      }
      target = cached['conversationId'] == 'family'
          ? 'family'
          : peers.single as String;
    }
    return FamilyChatPushView(
      {...guard, 'historyGeneration': generation},
      {
        ...?saved,
        'uid': uid,
        'familyId': parts[1],
        'epoch': parts[2],
        'serverTime': now,
        '_clockTrusted':
            trusted &&
            cached != null &&
            (cached['expiresAt'] == null || (cached['expiresAt'] as int) > now),
      },
      message,
      target,
    );
  }
}
