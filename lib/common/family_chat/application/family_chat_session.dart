import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/foundation.dart';

import '../../../core/logger/logger.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_guard_fence.dart';
import '../data/family_chat_notification_platform.dart';
import '../data/family_chat_remote.dart';
import '../domain/family_question_reply_state.dart';
import 'family_chat_background.dart';
import 'queue_family_chat_message.dart';

/// One authenticated account and membership generation per live session.
class FamilyChatSession extends ChangeNotifier {
  FamilyChatSession({
    required this.uid,
    required this.api,
    required this.db,
    required this.isCurrentAccount,
    this.expectedScope,
    this.notificationPresenter,
    this.isChatVisible,
    this.loadHistoryWhenHidden = true,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final String uid;
  final FamilyChatApi api;
  final FamilyChatDatabase db;
  final bool Function() isCurrentAccount;
  final String? expectedScope;
  final FamilyChatPushPresenter? notificationPresenter;
  final bool Function()? isChatVisible;
  final bool loadHistoryWhenHidden;
  final DateTime Function() clock;
  Map<String, dynamic>? config;
  String? scope;
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _invalidated = false;
  bool get isInvalidated => _invalidated;
  Future<void>? _invalidation;
  bool _suspended = false;
  bool _serverVerified = false;
  String? _cachedDraftVersion;
  String? _cachedComposerScope;
  bool _appForeground = false;
  bool _chatVisible = false;
  bool _hasQueuedSends = false;
  int _queuedRetryAttempts = 0;
  Timer? _queuedRetry;
  static const _queuedRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  /// A transient ACK failure left durable receipts for the bounded retry.
  bool _receiptsPending = false;
  static const _statesBatch = 50;
  static const _statesNecessaryCap = 40;
  int _statesNecessaryOffset = 0;
  int _statesTargetOffset = 0;
  final _statesCursor = <String, int>{};
  bool _syncQueued = false;
  bool _syncAgain = false;
  Future<void> _operations = Future.value();
  Future<void> _draftOperations = Future.value();
  final _elapsed = Stopwatch()..start();
  int? _serverAnchor;
  int _timeHighWatermark = 0;
  int _generation = 0;
  int _serverOffset = 0;
  Timer? _timer;
  final _history = <String, List<Map<String, dynamic>>>{};
  final _historySyncedTargets = <String>{};
  final _before = <String, int>{};
  final _olderCursor = <String, int>{};
  final _latestFirst = <String, int>{};
  final _pageRevisions = <String, int>{};
  Map<String, dynamic> _unread = {'count': 0};
  StreamSubscription<String>? _notificationUnreadChanges;
  int get unreadCount => enabled ? _unread['count'] as int : 0;
  bool get hasUnread =>
      enabled &&
      !historyClearPending &&
      (unreadCount > 0 || threads.any((thread) => thread['hasUnread'] == true));
  String? get unreadSender => enabled ? _unread['senderUid'] as String? : null;

  /// Null means the server has no authoritative summary for this conversation.
  bool? hasUnreadIn(String target) {
    if (!enabled || historyClearPending) return null;
    final row = threads.where((row) => row['targetUid'] == target).firstOrNull;
    return row?['hasUnread'] as bool?;
  }

  Future<Map<String, dynamic>> _callApi(
    String operation,
    Map<String, Object?> data,
  ) {
    if (operation == 'completeFamilyChatTreatment' ||
        operation == 'getFamilyChatConfig') {
      return api.call(operation, data);
    }
    // Captured before identity resolution starts inside the transport.
    final capturedUid = uid;
    final capturedScope = scope;
    final capturedStamp = _guardStamp;
    final capturedGeneration = _generation;
    final capturedHistory = _historyMinimum;
    bool unchanged() =>
        active &&
        enabled &&
        capturedScope != null &&
        scope == capturedScope &&
        _guardStamp == capturedStamp &&
        _generation == capturedGeneration;
    return api.call(
      operation,
      data,
      allowRequest: () async {
        if (!unchanged()) return false;
        if (await db.fence.accountRevocation(capturedUid) != null) {
          return false;
        }
        if (!unchanged()) return false;
        // Fence (enabled/uid/scope/stamp), OFF latch and durable history are
        // verified under the writer lock and re-read after the action, so a
        // same-UID OFF->ON or history clear by another connection/isolate
        // during these reads cannot slip through. Only a synchronous check
        // runs inside the writer.
        final admitted = await db.withChatGuard({
          'uid': capturedUid,
          'scope': capturedScope,
          'stamp': capturedStamp,
          'historyGeneration': capturedHistory,
        }, () async => unchanged());
        // Final synchronous recheck after every await.
        return admitted == true && unchanged();
      },
    );
  }

  bool isLoadingHistory(String target) =>
      busy && !_historySyncedTargets.contains(target);

  bool showingOlder(String target) => _before.containsKey(target);
  Future<List<Map<String, dynamic>>> _readHistory(
    String scope,
    String target,
  ) async {
    final rows = await db.messages(scope, target, before: _before[target]);
    final first = rows.firstOrNull?['sequence'] as int?;
    if (!_before.containsKey(target) &&
        first != null &&
        _latestFirst[target] != first) {
      _latestFirst[target] = first;
      _olderCursor[target] = first;
    }
    return rows;
  }

  Future<void> loadHistory(String target, {bool latest = false}) {
    final revision = (_pageRevisions[target] ?? 0) + 1;
    _pageRevisions[target] = revision;
    return _serial(() async {
      if (!await _mayWrite()) return;
      final currentScope = scope!;
      final boundary =
          _olderCursor[target] ??
          _history[target]?.firstOrNull?['sequence'] as int?;
      if (!latest && boundary == null) return;
      final result = await _callApi('fetchFamilyChatMessages', {
        'targetUid': target,
        if (latest) 'latest': true else 'before': boundary,
      });
      if (!enabled ||
          scope != currentScope ||
          _pageRevisions[target] != revision) {
        return;
      }
      final committed = await _write(currentScope, () async {
        if (_pageRevisions[target] != revision) return false;
        for (final value in result['messages'] as List) {
          final message = Map<String, dynamic>.from(value as Map);
          final saved = await db.saveMessage(
            currentScope,
            target,
            message,
            serverNow: serverNow,
          );
          if (saved &&
              message['senderUid'] != uid &&
              (message['receipts'] as Map?)?[uid]?['deliveredAt'] == null) {
            await db.queueReceipt(currentScope, message['id'] as String, false);
          }
        }
        return true;
      });
      if (committed != true) return;
      if (!enabled ||
          scope != currentScope ||
          _pageRevisions[target] != revision) {
        return;
      }
      if (latest) {
        _before.remove(target);
      } else if ((result['messages'] as List).isNotEmpty) {
        _before[target] = boundary!;
      }
      final scanned = result['oldestCursor'] as int?;
      if (scanned != null && scanned > 0) _olderCursor[target] = scanned;
      _history[target] = await _readHistory(currentScope, target);
      _unread = await db.unread(currentScope, uid);
      _notify();
      unawaited(synchronize(enqueueAgain: true));
    });
  }

  final _pending = <String, List<Map<String, dynamic>>>{};
  final _drafts = <String, String>{};
  final _draftEdits = <String, FamilyChatDraftEdit>{};
  final _expiredDrafts = <String>{};
  final _draftRevisions = <String, int>{};
  List<Map<String, dynamic>> threads = [];
  Map<String, dynamic>? _shortcuts;
  Map<String, dynamic>? _shortcutEdit;
  String _guardStamp =
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';
  Future<String?> _disableBackground() async {
    _serverVerified = false;
    _cachedComposerScope = null;
    _cancelQueuedRetry(reset: true);
    final stamp = _guardStamp;
    _guardStamp = _shortcutEditId();
    String? version;
    final ids = await db.deactivateChat(
      expectedStamp: stamp,
      onBlocked: (value) => version = value,
    );
    await FamilyChatNotificationPlatform.cancel(
      db,
      ids,
      keepTrying: () => !_disposed,
    );
    return version;
  }

  String _shortcutEditId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';

  bool get shortcutPending => enabled && _shortcutEdit != null;
  bool get shortcutConflict =>
      shortcutPending && _shortcutEdit?['conflict'] == true;
  List<Map<String, dynamic>>? get shortcuts {
    final raw = _shortcutEdit?['items'] ?? _shortcuts?['items'];
    if (!enabled || raw == null) return null;
    final items = (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final order = _shortcutEdit != null
        ? items.map((item) => item['id']).toList()
        : _shortcuts!['order'] as List? ?? [];
    int rank(Map item) {
      final index = order.indexOf(item['id']);
      return index < 0 ? order.length : index;
    }

    items.sort((a, b) => rank(a).compareTo(rank(b)));
    return items;
  }

  Future<void> _fetchShortcuts(String currentScope) async {
    final next = await _callApi(
      'fetchFamilyChatShortcuts',
      {},
    ).timeout(const Duration(seconds: 2));
    if (!enabled || scope != currentScope) return;
    if (!await _store(
      currentScope,
      () => db.setMetadata('shortcuts:$currentScope', next),
    )) {
      return;
    }
    if (enabled && scope == currentScope) _shortcuts = next;
  }

  Future<void> saveShortcuts(
    List<Map<String, dynamic>> items, {
    bool orderOnly = false,
  }) => _local(() async {
    if (!await _mayWrite()) throw StateError('Chat unavailable');
    final currentScope = scope!;
    final previous = await db.metadata('shortcutEdit:$currentScope');
    final edit = {
      'id': _shortcutEditId(),
      'items': items,
      'version': (previous?['version'] as int? ?? 0) + 1,
      'baseRevision': previous?['baseRevision'] ?? _shortcuts?['revision'] ?? 0,
      'baseOrderRevision':
          previous?['baseOrderRevision'] ?? _shortcuts?['orderRevision'] ?? 0,
      'orderOnly':
          orderOnly &&
          _shortcuts?['items'] != null &&
          (previous == null ||
              previous['orderOnly'] == true ||
              previous['phase'] == 'order'),
      'phase': 'library',
      'conflict': previous?['conflict'] == true,
      'createdAt': serverNow,
    };
    final saved = await _write(currentScope, () async {
      await db.setMetadata('shortcutEdit:$currentScope', edit);
      return true;
    });
    if (saved != true) throw StateError('Chat unavailable');
    if (!enabled || scope != currentScope) return;
    _shortcutEdit = edit;
    _notify();
    unawaited(synchronize(enqueueAgain: true));
  });

  Future<void> resolveShortcutConflict({required bool keepMine}) =>
      _local(() async {
        if (!await _mayWrite() || _shortcutEdit == null) return;
        final currentScope = scope!;
        await _write(currentScope, () async {
          if (keepMine) {
            _shortcutEdit = {
              ..._shortcutEdit!,
              'id': _shortcutEditId(),
              'version': (_shortcutEdit!['version'] as int) + 1,
              'baseRevision': _shortcuts?['revision'] ?? 0,
              'baseOrderRevision': _shortcuts?['orderRevision'] ?? 0,
              'phase': 'library',
              'orderOnly': false,
              'conflict': false,
            };
            await db.setMetadata('shortcutEdit:$currentScope', _shortcutEdit!);
          } else {
            await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
              'shortcutEdit:$currentScope',
            ]);
            _shortcutEdit = null;
          }
          await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
            'shortcutAttempt:$currentScope',
          ]);
          return true;
        });
        _notify();
        unawaited(synchronize(enqueueAgain: true));
      });

  static String _canonical(dynamic value) {
    dynamic sorted(dynamic value) => value is Map
        ? {
            for (final key
                in (value.keys.map((key) => key.toString()).toList()..sort()))
              key: sorted(value[key]),
          }
        : value is List
        ? value.map(sorted).toList()
        : value;
    return jsonEncode(sorted(value));
  }

  Future<void> _shortcutProgress(
    String currentScope,
    Map edit, {
    int? libraryRevision,
    int? orderRevision,
    bool complete = false,
    bool conflict = false,
  }) => _local(() async {
    if (!enabled || scope != currentScope) return;
    await _store(currentScope, () async {
      final current = await db.metadata('shortcutEdit:$currentScope');
      if (current == null) return;
      if (complete && current['id'] == edit['id']) {
        await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'shortcutEdit:$currentScope',
        ]);
        _shortcutEdit = null;
      } else {
        if (libraryRevision != null &&
            current['baseRevision'] == edit['baseRevision']) {
          current['baseRevision'] = libraryRevision;
          if (current['id'] == edit['id']) current['phase'] = 'order';
        }
        if (orderRevision != null &&
            current['baseOrderRevision'] == edit['baseOrderRevision']) {
          current['baseOrderRevision'] = orderRevision;
        }
        if (conflict) current['conflict'] = true;
        await db.setMetadata('shortcutEdit:$currentScope', current);
        _shortcutEdit = current;
      }
    });
  });

  Future<void> _syncShortcuts(String currentScope) async {
    await _fetchShortcuts(currentScope);
    if (!await _mayWrite() || scope != currentScope) return;
    var edit = await db.metadata('shortcutEdit:$currentScope');
    if (edit == null || edit['conflict'] == true) return;
    final attempt = await db.metadata('shortcutAttempt:$currentScope');
    if (attempt != null) {
      final previous = Map<String, dynamic>.from(attempt['edit'] as Map);
      final library = attempt['phase'] == 'library';
      final base =
          previous[library ? 'baseRevision' : 'baseOrderRevision'] as int;
      final current =
          _shortcuts![library ? 'revision' : 'orderRevision'] as int;
      final desired = library
          ? previous['items']
          : (previous['items'] as List).map((item) => item['id']).toList();
      final actual = _shortcuts![library ? 'items' : 'order'];
      if (current == base) {
        // Retry the exact uncertain snapshot before sending a newer local edit.
        edit = previous;
      } else if (current == base + 1 &&
          _canonical(desired) == _canonical(actual)) {
        await _shortcutProgress(
          currentScope,
          previous,
          libraryRevision: library ? current : null,
          orderRevision: library ? null : current,
          complete: !library,
        );
        await _clearShortcutAttempt(
          currentScope,
          previous,
          attempt['phase'] as String,
        );
        edit = await db.metadata('shortcutEdit:$currentScope');
        if (edit == null || !enabled || scope != currentScope) return;
      } else {
        await _shortcutProgress(currentScope, edit, conflict: true);
        return;
      }
    }
    final items = edit['items'] as List;
    final ids = items.map((item) => item['id']).toList();
    if (edit['orderOnly'] != true && edit['phase'] != 'order') {
      if (edit['baseRevision'] != _shortcuts!['revision']) {
        if (_canonical(items) != _canonical(_shortcuts!['items'])) {
          await _shortcutProgress(currentScope, edit, conflict: true);
          return;
        }
      } else {
        await _rememberShortcutAttempt(currentScope, edit, 'library');
        if (!await _mayWrite() || scope != currentScope) return;
        await _callApi('saveFamilyChatShortcuts', {
          'items': items,
          'expectedRevision': edit['baseRevision'],
        }).timeout(const Duration(seconds: 2));
        if (!enabled || scope != currentScope) return;
        _shortcuts = {
          ..._shortcuts!,
          'items': items,
          'revision': (edit['baseRevision'] as int) + 1,
        };
        if (!await _store(
          currentScope,
          () => db.setMetadata('shortcuts:$currentScope', _shortcuts!),
        )) {
          return;
        }
      }
      await _shortcutProgress(
        currentScope,
        edit,
        libraryRevision: _shortcuts!['revision'] as int,
      );
      await _clearShortcutAttempt(currentScope, edit, 'library');
      if (!enabled || scope != currentScope) return;
      final latest = await db.metadata('shortcutEdit:$currentScope');
      if (latest?['id'] != edit['id']) return;
      edit = latest!;
    }
    if (edit['baseOrderRevision'] != _shortcuts!['orderRevision']) {
      if (_canonical(ids) != _canonical(_shortcuts!['order'])) {
        await _shortcutProgress(currentScope, edit, conflict: true);
        return;
      }
    } else {
      await _rememberShortcutAttempt(currentScope, edit, 'order');
      if (!await _mayWrite() || scope != currentScope) return;
      await _callApi('orderFamilyChatShortcuts', {
        'ids': ids,
        'expectedRevision': edit['baseOrderRevision'],
      }).timeout(const Duration(seconds: 2));
      if (!enabled || scope != currentScope) return;
      _shortcuts = {
        ..._shortcuts!,
        'order': ids,
        'orderRevision': (edit['baseOrderRevision'] as int) + 1,
      };
      if (!await _store(
        currentScope,
        () => db.setMetadata('shortcuts:$currentScope', _shortcuts!),
      )) {
        return;
      }
    }
    await _shortcutProgress(
      currentScope,
      edit,
      orderRevision: _shortcuts!['orderRevision'] as int,
      complete: true,
    );
    await _clearShortcutAttempt(currentScope, edit, 'order');
  }

  Future<void> _rememberShortcutAttempt(
    String currentScope,
    Map edit,
    String phase,
  ) => _local(() async {
    if (!enabled || scope != currentScope) return;
    await _store(
      currentScope,
      () => db.setMetadata('shortcutAttempt:$currentScope', {
        'edit': edit,
        'phase': phase,
      }),
    );
  });
  Future<void> _clearShortcutAttempt(
    String currentScope,
    Map edit,
    String phase,
  ) => _local(() async {
    if (!enabled || scope != currentScope) return;
    final attempt = await db.metadata('shortcutAttempt:$currentScope');
    if (attempt?['edit']?['id'] == edit['id'] && attempt?['phase'] == phase) {
      await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
        'shortcutAttempt:$currentScope',
      ]);
    }
  });

  int get serverNow {
    final wall = clock().millisecondsSinceEpoch + _serverOffset;
    final monotonic = (_serverAnchor ?? wall) + _elapsed.elapsedMilliseconds;
    _timeHighWatermark = [
      _timeHighWatermark,
      wall,
      monotonic,
    ].reduce((a, b) => a > b ? a : b);
    return _timeHighWatermark;
  }

  bool get active => !_disposed && !_invalidated && isCurrentAccount();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<T> _local<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _draftOperations = _draftOperations.catchError((Object _) {}).then((
      _,
    ) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  bool get enabled =>
      active &&
      !_suspended &&
      config?['account']?['enabled'] == true &&
      config?['policy']?['enabled'] == true;
  bool get serverVerified => _serverVerified && enabled;
  bool get canQueueComposer =>
      enabled &&
      !historyClearPending &&
      scope != null &&
      (serverVerified ||
          _cachedComposerScope == scope &&
              _cachedDraftVersion != null &&
              clock().millisecondsSinceEpoch >=
                  (config?['_observedLocalAt'] as int? ?? 0));

  Future<bool> _mayWrite() async {
    if (!active || !serverVerified || scope == null) return false;
    final expectedScope = scope!;
    final stamp = _guardStamp;
    final guard = await db.fence.read();
    return active &&
        serverVerified &&
        scope == expectedScope &&
        _guardStamp == stamp &&
        guard['enabled'] == true &&
        guard['uid'] == uid &&
        guard['scope'] == expectedScope &&
        guard['stamp'] == stamp &&
        await db.historyAllows(expectedScope, _historyMinimum);
  }

  Future<T?> _write<T>(String currentScope, Future<T> Function() action) async {
    final stamp = _guardStamp;
    if (!await _mayWrite()) return null;
    if (scope != currentScope || stamp != _guardStamp) return null;
    final expected = {
      'uid': uid,
      'scope': currentScope,
      'stamp': stamp,
      'historyGeneration': _historyMinimum,
    };
    return db.withChatGuard(expected, () async {
      if (!active ||
          !serverVerified ||
          scope != expected['scope'] ||
          _guardStamp != expected['stamp']) {
        throw StateError('Chat unavailable');
      }
      return action();
    });
  }

  Future<bool> _store(
    String currentScope,
    Future<void> Function() action,
  ) async =>
      await _write(currentScope, () async {
        await action();
        return true;
      }) ==
      true;

  List<Map<String, dynamic>> get members => (config?['members'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
  bool get isCaregiver =>
      members.any((v) => v['uid'] == uid && v['role'] == 'managingCaregiver');
  String name(String id) => id == 'family'
      ? 'Rodzina'
      : members.where((v) => v['uid'] == id).firstOrNull?['displayName']
                as String? ??
            threads
                    .where((v) => v['targetUid'] == id)
                    .firstOrNull?['displayName']
                as String? ??
            id;
  List<String> get targets => <String>{
    ...members
        .where((v) => v['uid'] != uid && (v['role'] == 'child' || !isCaregiver))
        .map((v) => v['uid'] as String),
    ...threads.map((v) => v['targetUid'] as String),
    ..._pending.keys,
    'family',
  }.toList();
  List<Map<String, dynamic>> messages(String target) => !enabled
      ? const []
      : [
          for (final row in _history[target] ?? const [])
            if ((row['historyGeneration'] as int? ?? 0) >= _historyMinimum) row,
          ...?_pending[target],
        ];
  String draft(String target) => enabled ? _drafts[target] ?? '' : '';
  bool draftWasExpired(String target) =>
      enabled && _expiredDrafts.contains(target);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _refreshUnread() async {
    final currentScope = scope;
    final generation = _generation;
    if (currentScope == null || !enabled || !active) return;
    try {
      final unread = await db.unread(currentScope, uid);
      if (active &&
          enabled &&
          scope == currentScope &&
          _generation == generation &&
          !mapEquals(_unread, unread)) {
        _unread = unread;
        _notify();
      }
    } catch (error) {
      if (active) {
        Log.w('FamilyChatPush', 'Unread refresh failed (${error.runtimeType})');
      }
    }
  }

  void setForeground(bool foreground, {bool chatVisible = true}) {
    final resumed = foreground && !_appForeground;
    final chatOpened = chatVisible && (!_chatVisible || resumed);
    _appForeground = foreground;
    _chatVisible = chatVisible;
    _timer?.cancel();
    _timer = null;
    if (!foreground || !active) {
      _cancelQueuedRetry(reset: true);
      return;
    }
    // An Android reply action may run in a different isolate.
    if (resumed) unawaited(_refreshUnread());
    if (chatVisible) {
      _cancelQueuedRetry(reset: true);
      unawaited(synchronize(enqueueAgain: chatOpened));
      _timer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => unawaited(synchronize()),
      );
    } else if (resumed) {
      resumeQueuedSends();
    } else {
      _scheduleQueuedRetry();
    }
  }

  /// The single bounded retry lifecycle covers sendable outbox work and
  /// durable ACKs left by a transient failure. Terminal or expired outbox rows
  /// and outcome markers never count, so they cannot keep it spinning.
  bool get _hasRetryableWork => _hasQueuedSends || _receiptsPending;
  bool get _canRetryQueuedSends =>
      _appForeground && enabled && _hasRetryableWork;

  void _cancelQueuedRetry({bool reset = false}) {
    _queuedRetry?.cancel();
    _queuedRetry = null;
    if (reset) _queuedRetryAttempts = 0;
  }

  /// An app resume or a network reconnect starts a new retry window.
  ///
  /// Another isolate (RemoteInput reply on Home) may have queued signed work
  /// in the shared database that this session has not loaded, so when no
  /// retryable work is known in memory, one outbox reload decides. Bounded:
  /// one DB read per resume/reconnect, no timer, no polling.
  void resumeQueuedSends() {
    if (!_appForeground ||
        !active ||
        scope == null ||
        config?['account']?['enabled'] != true ||
        config?['policy']?['enabled'] != true) {
      return;
    }
    if (_hasRetryableWork) {
      _cancelQueuedRetry(reset: true);
      unawaited(synchronize());
      return;
    }
    final currentScope = scope!;
    final generation = _generation;
    unawaited(
      () async {
        await _reloadPending(currentScope);
        if (!_appForeground ||
            !active ||
            scope != currentScope ||
            generation != _generation ||
            !_hasRetryableWork) {
          return;
        }
        _cancelQueuedRetry(reset: true);
        await synchronize();
      }().catchError((Object _) {}),
    );
  }

  void _scheduleQueuedRetry() {
    if (!_canRetryQueuedSends) {
      _cancelQueuedRetry(reset: true);
      return;
    }
    if (_chatVisible ||
        busy ||
        _queuedRetry != null ||
        _queuedRetryAttempts >= _queuedRetryDelays.length) {
      return;
    }
    _queuedRetry = Timer(_queuedRetryDelays[_queuedRetryAttempts], () {
      _queuedRetry = null;
      if (!_canRetryQueuedSends || _chatVisible) return;
      _queuedRetryAttempts++;
      unawaited(synchronize());
    });
  }

  Map<String, dynamic> _historyState = {};
  int get _historyMinimum => _historyState['minimum'] as int? ?? 0;
  bool get historyClearPending => _historyState['intent'] != null;
  bool get historyClearConflict => _historyState['conflict'] == true;
  bool get canClearHistory =>
      serverVerified &&
      !historyClearPending &&
      (config?['historyGeneration'] as int? ?? 0) >= _historyMinimum;

  void _adoptHistory(Map<String, dynamic> state) {
    final previous = _historyMinimum;
    if ((state['minimum'] as int? ?? 0) < previous) return;
    _historyState = state;
    if (_historyMinimum <= previous) return;
    _generation++;
    _history.clear();
    _historySyncedTargets.clear();
    _before.clear();
    _olderCursor.clear();
    _latestFirst.clear();
    _pageRevisions.clear();
    _unread = {'count': 0};
    threads = [];
  }

  void reconcileConfirmedScope(Map<String, dynamic> confirmed) {
    if (!active || confirmed['uid'] != uid) return;
    final nextScope = jsonEncode([
      uid,
      confirmed['familyId'],
      confirmed['epoch'],
    ]);
    if (scope != null && scope != nextScope) {
      unawaited(invalidate(preserveHistory: true));
    }
  }

  /// Settings can confirm a remote clear before the next conversation poll.
  void reconcileConfirmedHistory(Map<String, dynamic> confirmed) {
    final generation = confirmed['historyGeneration'];
    if (!enabled ||
        confirmed['uid'] != uid ||
        scope != jsonEncode([uid, confirmed['familyId'], confirmed['epoch']]) ||
        generation is! int ||
        generation <= _historyMinimum) {
      return;
    }
    _adoptHistory({
      ..._historyState,
      'minimum': generation,
      'confirmed': generation,
    });
    _notify();
    unawaited(synchronize(enqueueAgain: true));
  }

  /// Capture the version shown before confirmation and persist one intent.
  Future<void> clearHistory(String confirmedScope, int expectedGeneration) =>
      _local(() async {
        if (!canClearHistory ||
            scope != confirmedScope ||
            (config?['historyGeneration'] as int? ?? 0) != expectedGeneration) {
          throw StateError('Chat history changed');
        }
        final state = await _write(
          confirmedScope,
          () => db.beginHistoryClear(
            confirmedScope,
            expectedGeneration,
            _shortcutEditId(),
          ),
        );
        if (state == null || !active || scope != confirmedScope) {
          throw StateError('Chat unavailable');
        }
        _adoptHistory(state);
        await _reloadPending(confirmedScope);
        _notify();
        unawaited(synchronize(enqueueAgain: true));
      });

  Future<void> _presentQueuedIncoming(String currentScope) async {
    if (!_appForeground || notificationPresenter == null) return;
    for (final receipt in await db.receipts(currentScope)) {
      if (!enabled || scope != currentScope) return;
      if (receipt.read<int>('is_read') != 0) continue;
      final message = await db.message(
        currentScope,
        receipt.read<String>('id'),
      );
      if (message == null || message['senderUid'] == uid) continue;
      final participants = message['participants'] as Map?;
      final target = message['conversationId'] == 'family'
          ? 'family'
          : participants?.keys
                .whereType<String>()
                .where((id) => id != uid)
                .singleOrNull;
      if (target != null) {
        await _presentSyncedMessages(currentScope, target, [message]);
      }
    }
  }

  Future<void> _presentSyncedMessages(
    String currentScope,
    String target,
    List<Map<String, dynamic>> messages,
  ) async {
    final guard = await db.activeChat();
    final currentConfig = config;
    if (guard['scope'] != currentScope ||
        guard['uid'] != uid ||
        currentConfig == null) {
      return;
    }
    final worker = FamilyChatBackground(
      db: db,
      api: api,
      presenter: notificationPresenter!,
      currentUid: () => active && enabled && scope == currentScope ? uid : null,
      shouldPresent: (_) =>
          _appForeground && !(isChatVisible?.call() ?? _chatVisible),
    );
    final elapsedAtSync = _elapsed.elapsedMilliseconds;
    final notificationConfig = {...currentConfig, 'serverTime': serverNow};
    for (final message in messages) {
      try {
        await worker.presentIncoming(
          FamilyChatPushView(
            {...guard, 'historyGeneration': message['historyGeneration'] ?? 0},
            notificationConfig,
            message,
            target,
            elapsedMilliseconds: () =>
                _elapsed.elapsedMilliseconds - elapsedAtSync,
          ),
        );
      } catch (error) {
        Log.w(
          'FamilyChatPush',
          'Sync presentation failed (${error.runtimeType})',
        );
      }
    }
  }

  Future<void> _cancelClearedNotices(String currentScope) async {
    await db.markLocallyReadNotificationsForCancellation(currentScope);
    final notices = await db.historyCancellationIntents(currentScope);
    if (notices.isEmpty) return;
    await FamilyChatNotificationPlatform.cancel(
      db,
      notices,
      keepTrying: () => false,
      operation: notificationPresenter?.cancel,
    );
  }

  Future<bool> _retryHistoryClear(String currentScope) async {
    final intent = _historyState['intent'] as Map<String, dynamic>?;
    if (intent == null) return true;
    final operationId = intent['operationId'] as String;
    final stamp = _guardStamp;
    if (!await _mayWrite() || scope != currentScope) return false;
    int? generation;
    try {
      final result = await _callApi('clearFamilyChatHistory', intent);
      generation = result['generation'] as int?;
      if (generation != (intent['expectedGeneration'] as int) + 1) {
        throw StateError('Invalid history clear result');
      }
    } on CallableFailure catch (failure) {
      if (failure.rejectionCode != 'already-exists') rethrow;
    }
    if (!active || !enabled || scope != currentScope || stamp != _guardStamp) {
      return false;
    }
    final state = await _write(
      currentScope,
      () => db.finishHistoryClear(
        currentScope,
        operationId,
        generation: generation,
      ),
    );
    if (state == null || !active || scope != currentScope) return false;
    _adoptHistory(state);
    if (generation != null &&
        generation > (config?['historyGeneration'] as int? ?? 0)) {
      config = {...config!, 'historyGeneration': generation};
    }
    _notify();
    // A conflict requires a fresh config and a new explicit confirmation.
    return generation != null;
  }

  Future<void> start({bool foreground = false, bool chatVisible = false}) {
    _appForeground = foreground;
    _chatVisible = chatVisible;
    _notificationUnreadChanges ??= FamilyChatBackground.unreadChanges.listen((
      changedScope,
    ) {
      if (scope == changedScope) unawaited(_refreshUnread());
    });
    return _serial(_start);
  }

  Future<void> _start() async {
    _cachedDraftVersion = (await db.fence.read())['version'] as String;
    final cached = await db.metadata('account:$uid');
    if (!active) return;
    if (cached != null) {
      final cachedScope = jsonEncode([
        uid,
        cached['familyId'],
        cached['epoch'],
      ]);
      if (expectedScope != null && cachedScope != expectedScope) {
        // Discard stale cache from mismatched familyId or epoch.
      } else if (clock().millisecondsSinceEpoch <
          (cached['_observedLocalAt'] as int? ?? 0)) {
        config = cached;
        scope = cachedScope;
        _suspended = true;
        error = 'clock-uncertain';
      } else {
        _timeHighWatermark = cached['_lastServerNow'] as int? ?? 0;
        await _applyConfig(cached);
        final currentScope = scope;
        final guard = await db.fence.read();
        if (enabled &&
            currentScope != null &&
            cached['uid'] == uid &&
            cached['familyId'] is String &&
            cached['epoch'] is String &&
            guard['version'] == _cachedDraftVersion &&
            (guard['enabled'] != true ||
                guard['uid'] == uid && guard['scope'] == currentScope) &&
            await db.fence.accountRevocation(uid) == null &&
            active &&
            scope == currentScope) {
          _cachedComposerScope = currentScope;
        }
      }
    }
    await _synchronize();
  }

  Future<void> _applyConfig(
    Map<String, dynamic> next, {
    bool fresh = false,
    String? expectedGuardVersion,
  }) async {
    if (!active) return;
    if (!fresh) _serverVerified = false;
    final nextScope = jsonEncode([uid, next['familyId'], next['epoch']]);
    if (expectedScope != null && nextScope != expectedScope) {
      if (fresh) {
        // Authoritative server scope disagrees with the scope settings
        // admitted: hide the old scope now and abort the running sync. The
        // serialized cleanup is intentionally not awaited because this runs
        // inside _serial and awaiting it here would deadlock.
        unawaited(invalidate(preserveHistory: true));
      }
      return;
    }
    final observed = next['historyGeneration'] ?? 0;
    if (observed is! int || observed < 0 || observed >= 9007199254740991) {
      throw StateError('Invalid history generation');
    }
    if (scope != null && scope != nextScope) {
      expectedGuardVersion = await _disableBackground();
      final oldScope = scope!;
      _generation++;
      config = null;
      scope = null;
      _notify();
      await _draftOperations.catchError((Object _) {});
      await db.clearScope(oldScope);
      _historyState = {};
      _history.clear();
      _historySyncedTargets.clear();
      _before.clear();
      _olderCursor.clear();
      _latestFirst.clear();
      _pending.clear();
      _hasQueuedSends = false;
      _receiptsPending = false;
      _clearDraftState();
      _shortcuts = null;
      _shortcutEdit = null;
    }
    if (!active) return;
    if (config != null &&
        (config?['policy']?['revision'] != next['policy']?['revision'] ||
            config?['account']?['revision'] != next['account']?['revision'])) {
      await db.invalidateTickets(nextScope);
    }
    if (!active) return;
    // A different isolate may already have observed a newer generation.
    await _local(() async {
      final state = await db.observeHistoryGeneration(nextScope, observed);
      if (!active) return;
      if (fresh && observed < (state['confirmed'] as int? ?? 0)) {
        _adoptHistory(state);
        _notify();
        throw StateError('Stale history settings');
      }
      _adoptHistory(state);
    });
    if (!active) return;
    config = next;
    if (fresh) _suspended = false;
    scope = nextScope;
    if (fresh && next['serverTime'] is int) {
      _serverOffset =
          (next['serverTime'] as int) - clock().millisecondsSinceEpoch;
      _serverAnchor = next['serverTime'] as int;
      _elapsed.reset();
    } else {
      _serverOffset = next['_serverOffset'] as int? ?? 0;
      _serverAnchor = clock().millisecondsSinceEpoch + _serverOffset;
      _elapsed.reset();
    }
    if (!enabled) {
      await _disableBackground();
      _shortcuts = null;
      _shortcutEdit = null;
      await _draftOperations.catchError((Object _) {});
      await db.clearScope(nextScope, preserveHistory: true);
      _history.clear();
      _historySyncedTargets.clear();
      _pending.clear();
      _hasQueuedSends = false;
      _receiptsPending = false;
      _clearDraftState();
      threads = [];
    } else {
      await _cancelClearedNotices(nextScope);
      await _local(() async {
        if (!enabled || scope != nextScope) return;
        final shortcuts = await db.metadata('shortcuts:$nextScope');
        final edit = await db.metadata('shortcutEdit:$nextScope');
        if (!enabled || scope != nextScope) return;
        _shortcuts = shortcuts;
        _shortcutEdit = edit;
      });
      final summary = await db.metadata('threads:$nextScope');
      final cachedThreads = (summary?['values'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (!active) return;
      threads = (summary?['historyGeneration'] as int? ?? 0) >= _historyMinimum
          ? cachedThreads
          : [];
      await db.applyRetention(nextScope, next['policy'] as Map);
      await db.purge(nextScope, serverNow);
      if (active && enabled && scope == nextScope) {
        await _cancelClearedNotices(nextScope);
      }
      for (final target in targets) {
        final revision = _draftRevisions[target] ?? 0;
        final messages = await _readHistory(nextScope, target);
        final draft = await db.draft(nextScope, target);
        if (!active) return;
        _history[target] = messages;
        if ((_draftRevisions[target] ?? 0) == revision &&
            !_draftEdits.containsKey(target)) {
          if ((_drafts[target] ?? '').isNotEmpty && draft.isEmpty) {
            _expiredDrafts.add(target);
          }
          _drafts[target] = draft;
        }
      }
      _unread = await db.unread(nextScope, uid);
      await _reloadPending(nextScope);
    }
    if (enabled &&
        fresh &&
        scope == nextScope &&
        expectedGuardVersion != null) {
      if (await db.fence.blocked()) {
        final pending = await db.cancellationIntents();
        await FamilyChatNotificationPlatform.cancel(
          db,
          pending,
          keepTrying: () => !_disposed,
        );
      }
      if (!enabled || scope != nextScope) return;
      final stamp = _guardStamp;
      final admitted = await db.activateChat(
        uid,
        nextScope,
        stamp,
        expectedGeneration: expectedGuardVersion,
        allowed: () => enabled && scope == nextScope && _guardStamp == stamp,
      );
      if (!admitted) {
        _serverVerified = false;
        config = null;
        scope = null;
        throw StateError('Chat admission changed');
      }
      _serverVerified = true;
      _cachedDraftVersion = null;
      _cachedComposerScope = null;
    }
    if (active) _notify();
  }

  Future<void> synchronize({bool enqueueAgain = false}) {
    if (_syncQueued) {
      if (enqueueAgain) _syncAgain = true;
      return _operations;
    }
    if (!active) return Future.value();
    _syncQueued = true;
    return _serial(() async {
      try {
        do {
          _syncAgain = false;
          await _synchronize();
        } while (_syncAgain && active);
      } finally {
        _syncQueued = false;
      }
    });
  }

  Future<void> _localPurge() async {
    if (!active || scope == null || !enabled) return;
    final currentScope = scope!;
    _adoptHistory(await db.historyState(currentScope));
    if (!enabled || scope != currentScope) return;
    await db.applyRetention(currentScope, config!['policy'] as Map);
    await db.purge(currentScope, serverNow);
    if (!active || !enabled || scope != currentScope) return;
    await _cancelClearedNotices(currentScope);
    for (final target in targets) {
      _history[target] = await _readHistory(currentScope, target);
      final revision = _draftRevisions[target];
      final storedDraft = await db.draft(currentScope, target);
      if (!_draftEdits.containsKey(target) &&
          _draftRevisions[target] == revision) {
        if ((_drafts[target] ?? '').isNotEmpty && storedDraft.isEmpty) {
          _expiredDrafts.add(target);
        }
        _drafts[target] = storedDraft;
      }
    }
    _unread = await db.unread(currentScope, uid);
    await _reloadPending(currentScope);
    if (active) await _persistConfig();
  }

  Future<void> _persistConfig() async {
    if (scope == null) return;
    await _store(
      scope!,
      () => db.setMetadata('account:$uid', {
        ...config!,
        '_serverOffset': _serverOffset,
        '_lastServerNow': serverNow,
        '_observedLocalAt': clock().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _synchronize() async {
    if (!active || busy) return;
    busy = true;
    _notify();
    var configVerified = false;
    try {
      await _localPurge();
      if (!active) return;
      final generation = _generation;
      final guardVersion = (await db.fence.read())['version'] as String;
      final next = await _callApi('getFamilyChatConfig', {});
      if (!active || generation != _generation) return;
      configVerified = true;
      await _applyConfig(next, fresh: true, expectedGuardVersion: guardVersion);
      if (!active) return;
      await _persistConfig();
      error = null;
      if (!enabled) return;
      final currentScope = scope!;
      if (!await _retryHistoryClear(currentScope)) return;
      await _persistConfig();
      final currentGeneration = _generation;
      bool valid() =>
          active &&
          scope == currentScope &&
          _generation == currentGeneration &&
          enabled;
      await _presentQueuedIncoming(currentScope);
      if (!valid()) return;
      await _flushReceipts(currentScope, valid);
      final list = <Map<String, dynamic>>[];
      final cached = await db.metadata('threads:$currentScope');
      var summaryAt = cached?['summaryAt'] as int?;
      var after = '';
      while (valid()) {
        final page = await _callApi('fetchFamilyChatConversations', {
          'after': after,
        });
        if (!valid()) return;
        final scoped =
            page.containsKey('familyId') ||
            page.containsKey('epoch') ||
            page.containsKey('historyGeneration') ||
            page.containsKey('serverTime');
        if (scoped) {
          final observed = page['historyGeneration'];
          final time = page['serverTime'];
          if (page['familyId'] != config!['familyId'] ||
              page['epoch'] != config!['epoch'] ||
              (page['uid'] != null && page['uid'] != uid) ||
              observed is! int ||
              observed < 0 ||
              time is! int ||
              (summaryAt != null && time < summaryAt)) {
            return;
          }
          final expected = config!['historyGeneration'] as int? ?? 0;
          if (observed != expected) {
            if (observed > expected) {
              final state = await _write(
                currentScope,
                () => db.observeHistoryGeneration(currentScope, observed),
              );
              if (state != null && valid()) {
                _adoptHistory(state);
                _notify();
                unawaited(synchronize(enqueueAgain: true));
              }
            }
            return;
          }
          summaryAt = time;
        }
        for (final row in page['conversations'] as List) {
          final thread = Map<String, dynamic>.from(row as Map);
          if (!scoped || thread['hasUnread'] is! bool) {
            thread['hasUnread'] = null;
          }
          list.add(thread);
        }
        if (page['hasMore'] != true) break;
        after = page['cursor'] as String;
      }
      if (!valid()) return;
      if (!await _store(
        currentScope,
        () => db.setMetadata('threads:$currentScope', {
          'values': list,
          'summaryAt': summaryAt,
          'historyGeneration': _historyMinimum,
        }),
      )) {
        return;
      }
      if (!valid()) return;
      threads = list;
      final historyTargets = _chatVisible || loadHistoryWhenHidden
          ? targets
          : const <String>[];
      for (final target in historyTargets) {
        if (!_chatVisible && !loadHistoryWhenHidden) break;
        var cursor =
            (await db.metadata('cursor:$currentScope:$target'))?['value']
                as int? ??
            0;
        for (var pageNumber = 0; pageNumber < 2 && valid(); pageNumber++) {
          final page = await _callApi('fetchFamilyChatMessages', {
            'targetUid': target,
            if (cursor == 0) 'latest': true else 'after': cursor,
          });
          if (!valid()) return;
          if (cursor == 0 && page['oldestCursor'] is int) {
            _olderCursor[target] = page['oldestCursor'] as int;
          }
          final rows = (page['messages'] as List).map(
            (v) => Map<String, dynamic>.from(v as Map),
          );
          final incoming = <Map<String, dynamic>>[];
          if (!await _store(currentScope, () async {
            for (final message in rows) {
              if (!await db.historyAllows(
                currentScope,
                message['historyGeneration'] as int? ?? 0,
              )) {
                continue;
              }
              final saved = await db.saveMessage(
                currentScope,
                target,
                message,
                serverNow: serverNow,
              );
              await db.complete(currentScope, message['id'] as String);
              if (saved &&
                  message['senderUid'] != uid &&
                  (message['receipts'] as Map?)?[uid]?['deliveredAt'] == null) {
                if (_appForeground && notificationPresenter != null) {
                  incoming.add(message);
                }
                await db.queueReceipt(
                  currentScope,
                  message['id'] as String,
                  false,
                );
              }
            }
            cursor = page['cursor'] as int;
            await db.setMetadata('cursor:$currentScope:$target', {
              'value': cursor,
            });
          })) {
            return;
          }
          if (incoming.isNotEmpty && valid()) {
            await _presentSyncedMessages(currentScope, target, incoming);
          }
          if (page['hasMore'] != true) break;
        }
        if (!valid()) return;
        final history = await _readHistory(currentScope, target);
        if (!valid()) return;
        _history[target] = history;
        if (_historySyncedTargets.add(target)) _notify();
      }
      if (!valid()) return;
      if (!await _refreshStates(currentScope, valid)) return;
      if (!valid()) return;
      await _cancelClearedNotices(currentScope);
      if (!valid()) return;
      final reserved = await _promoteComposerQueue(currentScope, valid);
      await _flush(currentScope, valid);
      if (valid()) {
        _unread = await db.unread(currentScope, uid);
        await _reloadPending(currentScope);
        final count = await db.validTicketCount(currentScope, serverNow);
        if (count < 5 && !reserved) {
          final tickets = await _callApi('reserveFamilyChatOperations', {
            'count': 5 - count,
          });
          if (valid()) {
            if (!await _store(
              currentScope,
              () => db.addTickets(currentScope, tickets['tickets'] as List),
            )) {
              return;
            }
          }
        }
        // An optional shortcut service failure must not block messages or ACKs.
        try {
          await _syncShortcuts(currentScope);
        } on CallableFailure catch (failure) {
          if (valid() && ['invalid-argument'].contains(failure.rejectionCode)) {
            final edit = await db.metadata('shortcutEdit:$currentScope');
            if (edit != null) {
              await _shortcutProgress(currentScope, edit, conflict: true);
            }
          }
        } catch (_) {
          // Keep the last confirmed library available offline.
        }
      }
    } catch (failure) {
      if (!active) return;
      error = failure is CallableFailure
          ? failure.rejectionCode ?? failure.code
          : 'unavailable';
      if (error == 'permission-denied' &&
          !configVerified &&
          failure is CallableFailure &&
          failure.rejectionCode == 'permission-denied') {
        await _disableBackground();
        _generation++;
        final deniedScope = scope;
        config = null;
        scope = null;
        _history.clear();
        _historySyncedTargets.clear();
        _pending.clear();
        _hasQueuedSends = false;
        _receiptsPending = false;
        _clearDraftState();
        _notify();
        await _draftOperations.catchError((Object _) {});
        if (deniedScope != null) await db.clearScope(deniedScope);
        await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
          'account:$uid',
        ]);
      } else if (error == 'unauthenticated' ||
          error == 'failed-precondition' ||
          error == 'permission-denied') {
        await _disableBackground();
        _suspended = true;
        _history.clear();
        _historySyncedTargets.clear();
        _pending.clear();
      }
    } finally {
      busy = false;
      _scheduleQueuedRetry();
      _notify();
    }
  }

  int get _accountOffGeneration =>
      config?['account']?['offGeneration'] as int? ?? 0;
  int get _familyOffGeneration =>
      config?['policy']?['offGeneration'] as int? ?? 0;

  bool _isUnsigned(QueryRow row) => const {
    familyChatAwaitingTicket,
    'needs-ticket',
  }.contains(row.readNullable<String>('error'));

  Future<bool> _promoteComposerQueue(
    String currentScope,
    bool Function() valid,
  ) async {
    final rows = await db.outbox(currentScope);
    final count = rows
        .where(
          (row) =>
              row.readNullable<String>('error') == familyChatAwaitingTicket,
        )
        .length;
    if (count == 0 || !valid() || !await _mayWrite()) return false;
    final stamp = _guardStamp;
    final version = (await db.fence.read())['version'] as String;
    if (!valid() || stamp != _guardStamp) return false;
    final tickets = await _callApi('reserveFamilyChatOperations', {
      'count': math.min(count, 10),
    });
    if (!valid()) return true;
    await db.withComposerQueueAdmission(
      uid: uid,
      scope: currentScope,
      expectedVersion: version,
      expectedStamp: stamp,
      expectedHistoryGeneration: _historyMinimum,
      allowed: () => valid() && serverVerified && _guardStamp == stamp,
      action: () => db.promoteComposerMessages(
        currentScope,
        tickets['tickets'] as List,
        serverNow,
        accountOffGeneration: _accountOffGeneration,
        familyOffGeneration: _familyOffGeneration,
      ),
    );
    return true;
  }

  Future<void> _flush(String currentScope, bool Function() valid) async {
    for (final operation in await db.outbox(currentScope)) {
      if (!valid() || !await _mayWrite()) return;
      final now = serverNow;
      final retention = operation.readNullable<int>('retention_until');
      if (operation.read<int>('expires_at') <= now ||
          retention != null && retention <= now ||
          operation.readNullable<String>('error') != null) {
        continue;
      }
      final id = operation.read<String>('id');
      try {
        final result = await _callApi(
          'sendFamilyChatMessage',
          Map<String, Object?>.from(
            jsonDecode(operation.read<String>('payload')) as Map,
          ),
        );
        if (!valid()) return;
        if (!await _store(currentScope, () async {
          await db.saveMessage(
            currentScope,
            operation.read<String>('target'),
            Map<String, dynamic>.from(result['message'] as Map),
            serverNow: serverNow,
          );
          await db.complete(currentScope, id);
        })) {
          return;
        }
        final target = operation.read<String>('target');
        if (valid()) await _cancelClearedNotices(currentScope);
        _history[target] = await _readHistory(currentScope, target);
      } on CallableFailure catch (failure) {
        if (!valid()) return;
        if (failure.rejectionCode == 'failed-precondition' &&
            failure.rejectionReason == 'chat-send-outcome-unknown') {
          await _store(
            currentScope,
            () => db.failOperation(currentScope, id, 'send-outcome-unknown'),
          );
          continue;
        }
        if ([
          'not-found',
          'invalid-argument',
          'already-exists',
        ].contains(failure.rejectionCode)) {
          await db.failOperation(currentScope, id, failure.rejectionCode!);
        } else {
          rethrow;
        }
      }
    }
    await _flushReceipts(currentScope, valid);
  }

  /// Receipt changes do not advance message cursors, so they are refreshed
  /// through one bounded `fetchFamilyChatMessageStates` request per sync,
  /// batched across all targets (backend: 50 IDs/request, 60 requests/min/UID
  /// shared by every device of the account).
  ///
  /// Necessary IDs (signed outbox operations whose outcome may be unknown and
  /// messages behind a live notification) go first but are capped while other
  /// threads have recent messages, so old threads keep progressing. The
  /// remaining slots rotate round-robin across targets and, within a target,
  /// across its newest 50 messages.
  Future<bool> _refreshStates(
    String currentScope,
    bool Function() valid,
  ) async {
    // An ID can be listed by several targets' histories (or a notice/outbox
    // row); the save below picks one canonical target.
    final targetsOf = <String, List<String>>{};
    void link(String id, String target) {
      final list = targetsOf.putIfAbsent(id, () => []);
      if (!list.contains(target)) list.add(target);
    }

    final necessary = <String>{};
    final outboxTarget = <String, String>{};
    for (final operation in await db.outbox(currentScope)) {
      if (_isUnsigned(operation)) continue;
      final id = operation.read<String>('id');
      outboxTarget[id] = operation.read<String>('target');
      necessary.add(id);
    }
    final recent = <String, List<String>>{};
    for (final target in targets) {
      for (final entry in outboxTarget.entries) {
        if (entry.value == target) link(entry.key, target);
      }
      for (final id in await db.notificationMessageIds(currentScope, target)) {
        link(id, target);
        necessary.add(id);
      }
      if (!valid()) return false;
      final ids = [
        for (final message in (_history[target] ?? const []).reversed.take(
          _statesBatch,
        ))
          message['id'] as String,
      ];
      for (final id in ids) {
        link(id, target);
      }
      recent[target] = [
        for (final id in ids)
          if (!necessary.contains(id)) id,
      ];
    }
    final batch = <String>[];
    final order = [
      for (final entry in recent.entries)
        if (entry.value.isNotEmpty) entry.key,
    ];
    final urgent = necessary.toList();
    if (urgent.isNotEmpty) {
      final cap = order.isEmpty ? _statesBatch : _statesNecessaryCap;
      final start = _statesNecessaryOffset % urgent.length;
      final take = math.min(cap, urgent.length);
      for (var i = 0; i < take; i++) {
        batch.add(urgent[(start + i) % urgent.length]);
      }
      _statesNecessaryOffset = urgent.length > take ? start + take : 0;
    }
    if (order.isNotEmpty) {
      final first = _statesTargetOffset % order.length;
      _statesTargetOffset = first + 1;
      final taken = <String, int>{};
      var progressed = true;
      while (batch.length < _statesBatch && progressed) {
        progressed = false;
        for (var i = 0; i < order.length && batch.length < _statesBatch; i++) {
          final target = order[(first + i) % order.length];
          final ids = recent[target]!;
          final count = taken[target] ?? 0;
          if (count >= ids.length) continue;
          final cursor = _statesCursor[target] ?? 0;
          final id = ids[(cursor + count) % ids.length];
          if (!batch.contains(id)) batch.add(id);
          taken[target] = count + 1;
          progressed = true;
        }
      }
      for (final entry in taken.entries) {
        _statesCursor[entry.key] =
            ((_statesCursor[entry.key] ?? 0) + entry.value) %
            recent[entry.key]!.length;
      }
    }
    if (batch.isEmpty || !valid()) return valid();
    final result = await _callApi('fetchFamilyChatMessageStates', {
      'ids': batch,
    });
    if (!valid()) return false;
    final touched = <String>{};
    if (!await _store(currentScope, () async {
      for (final value in result['messages'] as List) {
        final message = Map<String, dynamic>.from(value as Map);
        final owners = targetsOf[message['id']] ?? const <String>[];
        if (owners.isEmpty ||
            !await db.historyAllows(
              currentScope,
              message['historyGeneration'] as int? ?? 0,
            )) {
          continue;
        }
        // Messages are keyed by scope+id, so exactly one target may own it:
        // the canonical family conversation wins over discovery order.
        final target = message['conversationId'] == 'family'
            ? 'family'
            : owners.firstWhere(
                (owner) => owner != 'family',
                orElse: () => owners.first,
              );
        await db.saveMessage(
          currentScope,
          target,
          message,
          serverNow: serverNow,
        );
        touched.addAll(owners);
        touched.add(target);
        await db.complete(currentScope, message['id'] as String);
      }
    })) {
      return false;
    }
    for (final target in touched) {
      if (!valid()) return false;
      _history[target] = await _readHistory(currentScope, target);
    }
    return valid();
  }

  /// Timeouts and rate limiting surface as `unavailable` without a definitive
  /// server rejection; authorization, admission (`cancelled`) and other
  /// rejections are not transient.
  static bool _transient(Object failure) =>
      failure is TimeoutException ||
      failure is CallableFailure &&
          failure.code == 'unavailable' &&
          failure.rejectionCode == null;

  /// ACKs stay durable in `chat_actions`. A transient ACK failure leaves them
  /// queued for the bounded session retry and does not abort fetch or outbox.
  Future<void> _flushReceipts(
    String currentScope,
    bool Function() valid,
  ) async {
    if (!valid()) return;
    final actions = await db.receipts(currentScope);
    for (var offset = 0; offset < actions.length; offset += 50) {
      if (!valid() || !await _mayWrite()) return;
      final batch = actions.skip(offset).take(50).toList();
      final Map<String, dynamic> result;
      try {
        result = await _callApi('acknowledgeFamilyChatMessages', {
          'items': [
            for (final action in batch)
              {
                'messageId': action.read<String>('id'),
                'read': action.read<int>('is_read') == 1,
              },
          ],
        });
      } catch (failure) {
        if (!_transient(failure)) rethrow;
        if (valid()) _receiptsPending = true;
        return;
      }
      if (!valid()) return;
      final completed = <dynamic>{
        ...result['acknowledged'] as List,
        ...result['ignored'] as List,
      };
      for (final action in batch) {
        final id = action.read<String>('id');
        if (completed.contains(id)) {
          await db.completeReceipt(
            currentScope,
            id,
            action.read<int>('is_read') == 1,
          );
        }
      }
    }
    // Every batch reached the server; unacknowledged leftovers are retried by
    // the next ordinary sync rather than by the retry lifecycle.
    if (valid()) _receiptsPending = false;
  }

  int get historyGeneration => _historyMinimum;

  Future<void> send(
    String target,
    String text, {
    List<String> answers = const [],
    String kind = 'text',
    String? replyTo,
    int? answerIndex,
    String? composerDraft,
    Map<String, Object?>? treatment,
    void Function(String id)? onQueued,
  }) {
    final submittedScope = scope;
    final submittedHistory = _historyMinimum;
    final draftRevision = _draftRevisions[target];
    return _local(
      () => _send(
        target,
        text,
        submittedScope: submittedScope,
        submittedHistory: submittedHistory,
        draftRevision: draftRevision,
        answers: answers,
        kind: kind,
        replyTo: replyTo,
        answerIndex: answerIndex,
        composerDraft: composerDraft,
        treatment: treatment,
        onQueued: onQueued,
      ),
    );
  }

  Future<void> _send(
    String target,
    String text, {
    required String? submittedScope,
    required int submittedHistory,
    required int? draftRevision,
    required List<String> answers,
    required String kind,
    String? replyTo,
    int? answerIndex,
    String? composerDraft,
    Map<String, Object?>? treatment,
    void Function(String id)? onQueued,
  }) async {
    if (!canQueueComposer ||
        submittedScope == null ||
        submittedHistory != _historyMinimum ||
        scope != submittedScope) {
      throw StateError('Chat unavailable');
    }
    final currentScope = submittedScope;
    final stamp = serverVerified ? _guardStamp : null;
    final expectedVersion = stamp == null
        ? _cachedDraftVersion
        : (await db.fence.read())['version'] as String;
    if (expectedVersion == null) throw StateError('Chat unavailable');
    final generation = _generation;
    bool allowed() =>
        canQueueComposer &&
        scope == currentScope &&
        _generation == generation &&
        (stamp == null || serverVerified && _guardStamp == stamp);
    bool clearSubmittedDraft() =>
        composerDraft != null &&
        _drafts[target] == composerDraft &&
        _draftRevisions[target] == draftRevision;

    final allowUnsigned =
        treatment == null &&
        (kind == 'text' || kind == 'question' || kind == 'answer');
    final signed = await QueueFamilyChatMessage(db)(
      uid: uid,
      scope: currentScope,
      target: target,
      expectedVersion: expectedVersion,
      expectedStamp: stamp,
      expectedHistoryGeneration: _historyMinimum,
      allowed: allowed,
      preferSigned: stamp != null && (error == null || !allowUnsigned),
      allowUnsigned: allowUnsigned,
      payload: {
        'kind': kind,
        'text': text,
        'answers': answers,
        'replyTo': replyTo,
        if (answerIndex != null) 'answerIndex': answerIndex,
        if (treatment != null) 'treatment': treatment,
      },
      accountOffGeneration: _accountOffGeneration,
      familyOffGeneration: _familyOffGeneration,
      now: () => serverNow,
      clearSubmittedDraft: clearSubmittedDraft,
      onQueued: onQueued,
    );
    if (signed == null) throw StateError('Chat unavailable or no valid ticket');
    if (!allowed()) return;
    _pageRevisions[target] = (_pageRevisions[target] ?? 0) + 1;
    _before.remove(target);
    _latestFirst.remove(target);
    _olderCursor.remove(target);
    _history[target] = await _readHistory(currentScope, target);
    if (!allowed()) return;
    if (clearSubmittedDraft()) {
      _drafts[target] = '';
      _draftEdits.remove(target);
      _draftRevisions[target] = (_draftRevisions[target] ?? 0) + 1;
    }
    _cancelQueuedRetry(reset: true);
    await _reloadPending(currentScope);
    _notify();
    if (!signed) return;
    unawaited(
      synchronize(enqueueAgain: true).catchError((Object _) {
        if (active) {
          error = 'unavailable';
          _notify();
        }
      }),
    );
  }

  Future<bool> markRead(String target, {Set<String>? ids}) =>
      _local(() => _markRead(target, ids));
  Future<bool> _markRead(String target, Set<String>? ids) async {
    if (historyClearPending || !await _mayWrite()) return false;
    final currentScope = scope!;
    final notices = <FamilyChatNotice>[];
    for (final message in messages(target)) {
      if (!await _mayWrite() || scope != currentScope) return false;
      if ((ids == null || ids.contains(message['id'])) &&
          message['senderUid'] != uid &&
          (message['receipts'] as Map?)?[uid]?['readAt'] == null) {
        final answers = message['answers'];
        final queued = await _write(currentScope, () async {
          final keepNotification =
              message['kind'] == 'question' &&
              answers is List &&
              answers.isNotEmpty &&
              await db.hasPendingNotificationRetry(
                currentScope,
                message['id'] as String,
              );
          await db.queueReceipt(currentScope, message['id'] as String, true);
          if (!keepNotification) {
            await db.markMessageNotificationForCancellation(
              currentScope,
              message['id'] as String,
            );
          }
          return keepNotification;
        });
        if (queued == null) return false;
        if (!queued) {
          notices.add(familyChatNotice(currentScope, message['id'] as String));
        }
      }
    }
    if (!active || scope != currentScope) return false;
    _history[target] = await _readHistory(currentScope, target);
    _unread = await db.unread(currentScope, uid);
    _notify();
    unawaited(
      FamilyChatNotificationPlatform.cancel(
        db,
        notices,
        keepTrying: () => active && enabled,
        operation: notificationPresenter?.cancel,
      ),
    );
    unawaited(synchronize(enqueueAgain: true));
    return true;
  }

  void _clearDraftState() {
    _drafts.clear();
    _draftEdits.clear();
    _expiredDrafts.clear();
    _draftRevisions.clear();
  }

  Future<void> saveDraft(String target, String text, {bool edited = true}) {
    if (!_mayPersistDraft) return Future.value();
    if (edited) {
      stageDraft(target, text);
    } else if ((_drafts[target] ?? '') != text) {
      return Future.value();
    }
    final revision = _draftRevisions[target];
    final currentScope = scope!;
    return _local(() async {
      if (_draftRevisions[target] != revision) return;
      await _saveDraft(target, text, currentScope);
    });
  }

  void stageDraft(String target, String text) {
    if (!_mayPersistDraft) return;
    if ((_drafts[target] ?? '') == text) return;
    _drafts[target] = text;
    _expiredDrafts.remove(target);
    final now = serverNow;
    final days = switch (config?['policy']?['retention']) {
      'day' => 1,
      'month' => 30,
      'unlimited' => null,
      _ => 7,
    };
    _draftEdits[target] = (
      at: now,
      policyRevision: config?['policy']?['revision'] as int? ?? 0,
      until: days == null ? null : now + days * 86400000,
    );
    _draftRevisions[target] = (_draftRevisions[target] ?? 0) + 1;
  }

  void suspendIdentity() {
    _serverVerified = false;
    unawaited(
      _disableBackground().then<void>((_) {}).catchError((Object _) {
        if (active) {
          error = 'unavailable';
          _notify();
        }
      }),
    );
    _suspended = true;
    _timer?.cancel();
    _notify();
  }

  bool get _mayPersistDraft =>
      active &&
      !_suspended &&
      scope != null &&
      config?['account']?['enabled'] == true &&
      config?['policy']?['enabled'] == true;
  Future<void> _saveDraft(
    String target,
    String text,
    String currentScope,
  ) async {
    if (!_mayPersistDraft || scope != currentScope) return;
    final edit = _draftEdits[target];
    final revision = _draftRevisions[target];
    var saved = false;
    if (serverVerified) {
      saved = await _store(
        currentScope,
        () => db.saveDraft(
          currentScope,
          target,
          text,
          serverNow: serverNow,
          edit: edit,
          allowCreate: edit != null,
        ),
      );
    } else if (_cachedDraftVersion != null) {
      saved = await db.saveCachedDraft(
        uid,
        currentScope,
        target,
        text,
        expectedVersion: _cachedDraftVersion!,
        expectedHistoryGeneration: _historyMinimum,
        allowed: () => _mayPersistDraft && scope == currentScope,
        serverNow: serverNow,
        edit: edit,
        allowCreate: edit != null,
      );
    }
    if (saved &&
        _mayPersistDraft &&
        scope == currentScope &&
        _draftRevisions[target] == revision) {
      _draftEdits.remove(target);
      final stored = await db.draft(currentScope, target);
      if (_mayPersistDraft &&
          scope == currentScope &&
          _draftRevisions[target] == revision &&
          stored != text) {
        _drafts[target] = stored;
        if (text.isNotEmpty && stored.isEmpty) _expiredDrafts.add(target);
        _notify();
      }
    }
  }

  Future<void> retry(String target, String id) => _serial(() async {
    await _synchronize();
    if (!await _mayWrite()) return;
    final currentScope = scope!;
    final operation = (await db.outbox(
      currentScope,
    )).where((row) => row.read<String>('id') == id).firstOrNull;
    if (operation == null ||
        operation.readNullable<String>('error') == null ||
        operation.readNullable<String>('error') == familyChatAwaitingTicket) {
      return;
    }
    final originalPayload = Map<String, dynamic>.from(
      jsonDecode(operation.read<String>('payload')) as Map,
    );
    if (familyReplyOperationStatus(
          error: operation.readNullable<String>('error'),
          signed: originalPayload['ticket'] is String,
        ) ==
        FamilyQuestionReplyStatus.unknown) {
      throw StateError('Verify the original operation instead of resending');
    }
    final body = Map<String, dynamic>.from(originalPayload)
      ..remove('ticket')
      ..remove('targetUid');
    if (body['kind'] == 'lowTreatment') {
      throw StateError('Expired treatment requests need a new confirmation');
    }
    var destination = target;
    if (body['replyTo'] is String) {
      final result = await _callApi('fetchFamilyChatMessageStates', {
        'ids': [body['replyTo']],
      });
      if (!enabled || scope != currentScope) return;
      final parents = result['messages'] as List;
      final parent = parents.firstOrNull as Map?;
      if (parent == null ||
          parent['participants']?[uid] != config!['epoch'] ||
          parent['receipts']?[uid] == null ||
          parent['expiresAt'] != null &&
              (parent['expiresAt'] as int) <= serverNow) {
        await db.failOperation(currentScope, id, 'expired');
        await _reloadPending(currentScope);
        _notify();
        throw StateError('This question is no longer available');
      }
      final peers = (parent['participants'] as Map).keys
          .where((key) => key != uid)
          .toList();
      if (parent['conversationId'] != 'family' && peers.length != 1) {
        throw StateError('Conversation unavailable');
      }
      destination = parent['conversationId'] == 'family'
          ? 'family'
          : peers.single as String;
    }
    if (operation.readNullable<String>('error') == 'needs-ticket') {
      await _store(
        currentScope,
        () => db.promoteNotificationDraft(
          currentScope,
          id,
          serverNow,
          target: destination,
        ),
      );
    } else {
      await _store(currentScope, () async {
        await db.complete(currentScope, id);
        final next = await db.enqueue(
          currentScope,
          destination,
          body,
          serverNow,
          originalLifetime: (
            at: operation.read<int>('created_at'),
            policyRevision: operation.read<int>('policy_revision'),
            until: operation.readNullable<int>('retention_until'),
          ),
        );
        if (next == null) throw StateError('Reconnect before retrying');
      });
    }
    await _reloadPending(currentScope);
    await _synchronize();
  });

  Future<void> verifyOutcome(String target, String id) => _serial(() async {
    await _synchronize();
    if (!await _mayWrite()) return;
    final currentScope = scope!;
    final operation = (await db.outbox(
      currentScope,
    )).where((row) => row.read<String>('id') == id).firstOrNull;
    if (operation != null &&
        (operation.read<String>('target') != target ||
            !const {
              'send-outcome-unknown',
              'expired',
            }.contains(operation.readNullable<String>('error')))) {
      return;
    }
    try {
      Map<String, dynamic>? message;
      if (operation == null) {
        final marker = await db.metadata('outcome:$currentScope:$id');
        if (marker?['target'] != target) return;
        final result = await _callApi('fetchFamilyChatMessageStates', {
          'ids': [id],
        });
        final raw = (result['messages'] as List)
            .cast<Map>()
            .where((value) => value['id'] == id && value['senderUid'] == uid)
            .firstOrNull;
        if (raw != null) message = Map<String, dynamic>.from(raw);
      } else {
        final result = await _callApi('sendFamilyChatMessage', {
          ...Map<String, dynamic>.from(
            jsonDecode(operation.read<String>('payload')) as Map,
          ),
          'verifyOnly': true,
        });
        message = Map<String, dynamic>.from(result['message'] as Map);
      }
      if (message != null &&
          !await _store(currentScope, () async {
            await db.saveMessage(
              currentScope,
              target,
              message!,
              serverNow: serverNow,
            );
            await db.complete(currentScope, id);
          })) {
        return;
      }
      _history[target] = await _readHistory(currentScope, target);
    } on CallableFailure catch (failure) {
      if (failure.rejectionCode != 'failed-precondition' ||
          failure.rejectionReason != 'chat-send-outcome-unknown') {
        rethrow;
      }
    }
    if (!enabled || scope != currentScope) return;
    await _reloadPending(currentScope);
    _notify();
  });

  Future<void> _reloadPending(String currentScope) async {
    final operations = await db.outbox(currentScope);
    final outcomes = await db.outcomeMarkers(currentScope);
    if (!active || scope != currentScope) return;
    final now = serverNow;
    _hasQueuedSends = operations.any((row) {
      final error = row.readNullable<String>('error');
      final retention = row.readNullable<int>('retention_until');
      return (error == null || error == familyChatAwaitingTicket) &&
          row.read<int>('expires_at') > now &&
          (retention == null || retention > now);
    });
    _scheduleQueuedRetry();
    _pending.clear();
    for (final row in operations) {
      final payload = Map<String, dynamic>.from(
        jsonDecode(row.read<String>('payload')) as Map,
      )..remove('_admission');
      final target = row.read<String>('target');
      final error = row.readNullable<String>('error');
      (_pending[target] ??= []).add({
        ...payload,
        'id': row.read<String>('id'),
        'senderUid': uid,
        'sentAt': row.read<int>('created_at'),
        'sequence': 0,
        'operationError': error,
        'operationSigned': payload['ticket'] is String,
        'delivery': error == null || error == familyChatAwaitingTicket
            ? 'pending'
            : 'failed',
        'sendOutcomeUnknown':
            familyReplyOperationStatus(
              error: error,
              signed: payload['ticket'] is String,
            ) ==
            FamilyQuestionReplyStatus.unknown,
        'receipts': <String, dynamic>{},
      });
    }
    final known = <Object?>{
      for (final messages in _history.values)
        ...messages.map((row) => row['id']),
      ...operations.map((row) => row.read<String>('id')),
    };
    for (final marker in outcomes) {
      if (known.contains(marker['id'])) continue;
      final target = marker['target'] as String;
      (_pending[target] ??= []).add({
        'id': marker['id'],
        'text': 'Treść wiadomości została usunięta z tego urządzenia.',
        'kind': 'text',
        'senderUid': uid,
        'sentAt': marker['createdAt'],
        'sequence': 0,
        'delivery': 'failed',
        'sendOutcomeUnknown': true,
        'redactedOutcome': true,
        'outcomeKind': marker['kind'],
        if (marker['replyTo'] is String) 'replyTo': marker['replyTo'],
        'receipts': <String, dynamic>{},
      });
    }
  }

  Future<void> discardOutcome(String target, String id) => _local(() async {
    if (!await _mayWrite()) return;
    final currentScope = scope!;
    final marker = await db.metadata('outcome:$currentScope:$id');
    if (marker?['target'] != target) return;
    await _store(currentScope, () => db.clearOutcome(currentScope, id));
    await _reloadPending(currentScope);
    _notify();
  });

  /// Idempotent: later calls return the first call's pending cleanup, so
  /// callers (and tests before closing the database) can drain it.
  Future<void> invalidate({bool preserveHistory = false}) {
    final pending = _invalidation;
    if (pending != null) return pending;
    final background = _disableBackground();
    final oldScope = scope;
    _invalidated = true;
    _generation++;
    _timer?.cancel();
    config = null;
    scope = null;
    _history.clear();
    _historySyncedTargets.clear();
    _pending.clear();
    _hasQueuedSends = false;
    _receiptsPending = false;
    _clearDraftState();
    threads = [];
    // Assigned before notifying so a re-entrant listener gets this cleanup.
    final cleanup = _invalidation = _serial(() async {
      await background;
      await _clear(oldScope, preserveHistory: preserveHistory);
    });
    _notify();
    return cleanup;
  }

  Future<void> _clear(String? oldScope, {required bool preserveHistory}) async {
    _generation++;
    _timer?.cancel();
    config = null;
    _history.clear();
    _historySyncedTargets.clear();
    _pending.clear();
    _hasQueuedSends = false;
    _receiptsPending = false;
    _clearDraftState();
    scope = null;
    await _draftOperations.catchError((Object _) {});
    if (oldScope != null) {
      await db.clearScope(oldScope, preserveHistory: preserveHistory);
    }
    await db.clearAccount(uid, preserveHistory: preserveHistory);
    _notify();
  }

  @override
  void dispose() {
    unawaited(_notificationUnreadChanges?.cancel());
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _cancelQueuedRetry(reset: true);
    super.dispose();
  }
}
