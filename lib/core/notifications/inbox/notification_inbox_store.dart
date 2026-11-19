import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import '../../logger/logger.dart';
import '../domain/models/notification_event_type.dart';
import 'notification_inbox_entry.dart';

/// Notification history shared by the UI, foreground-service and
/// notification-response isolates.
///
/// Each entry lives under its own key (the OS notification id, so re-posting
/// replaces it), and its `read` / `inactive` states are separate marker keys.
/// Markers only ever get set, so writers in different isolates never undo each
/// other with a stale read-modify-write; only [put] resets them for a new
/// delivery. Failures are logged and swallowed: the inbox mirrors delivery and
/// must never block it.
class NotificationInboxStore {
  NotificationInboxStore({
    SharedPreferencesAsync? preferences,
    SharedPreferencesAsync? chatPreferences,
    this.maxEntries = 40,
    this.retention = const Duration(days: 3),
  }) : _injected = preferences,
       _injectedChat = chatPreferences;

  static const keyPrefix = 'notification_inbox:';
  static const retryPrefix = 'notification_inbox.retry:';
  static const readPrefix = 'notification_inbox.read:';
  static const inactivePrefix = 'notification_inbox.inactive:';

  static final _changes = StreamController<void>.broadcast();

  /// Fires after any store in this isolate changed the inbox, including
  /// short-lived ones owned by push handlers, so the UI can follow along.
  static Stream<void> get changes => _changes.stream;

  static void notifyFamilyChatAccessChanged() => _changes.add(null);

  void _changed() => _changes.add(null);

  final SharedPreferencesAsync? _injected;
  final SharedPreferencesAsync? _injectedChat;
  late final SharedPreferencesAsync _prefs =
      _injected ?? SharedPreferencesAsync();

  late final SharedPreferencesAsync _chatPrefs =
      _injectedChat ??
      (_injected == null && !kIsWeb && Platform.isAndroid
          ? SharedPreferencesAsync(
              options: const SharedPreferencesAsyncAndroidOptions(
                backend:
                    SharedPreferencesAndroidBackendLibrary.SharedPreferences,
                originalSharedPreferencesOptions:
                    AndroidSharedPreferencesStoreOptions(
                      fileName: 'family_chat_notification_inbox',
                    ),
              ),
            )
          : _prefs);

  Set<SharedPreferencesAsync> get _stores => {_chatPrefs, _prefs};

  SharedPreferencesAsync _preferencesFor(NotificationInboxEntry entry) =>
      entry.type == NotificationEventType.familyChat ? _chatPrefs : _prefs;

  final int maxEntries;
  final Duration retention;

  String _key(int id) => '$keyPrefix$id';
  String _retryKey(int id) => '$retryPrefix$id';
  String _readKey(int id) => '$readPrefix$id';
  String _inactiveKey(int id) => '$inactivePrefix$id';

  /// Records a new delivery. Returns false when it could not be persisted.
  Future<bool> put(NotificationInboxEntry entry) async {
    try {
      final prefs = _preferencesFor(entry);
      await prefs.remove(_readKey(entry.id));
      await prefs.remove(_inactiveKey(entry.id));
      await prefs.remove(_retryKey(entry.id));
      await prefs.setString(_key(entry.id), jsonEncode(entry.toJson()));
      if (entry.retryAt case final due?) {
        await _writeRetryProgress(
          prefs,
          entry,
          nextDue: due,
          remaining: entry.retriesRemaining,
          inApp: entry.inApp,
        );
      }
      if (entry.read) await prefs.setBool(_readKey(entry.id), true);
      if (!entry.active) await prefs.setBool(_inactiveKey(entry.id), true);
    } catch (error) {
      Log.w('NotificationInbox', 'Inbox put failed (${error.runtimeType})');
      return false;
    }
    await _guard('prune', _prune);
    _changed();
    return true;
  }

  /// Entries that are due, newest first. Scheduled entries stay hidden until
  /// the moment the OS posts them.
  Future<List<NotificationInboxEntry>> visible() async {
    final now = clock.now();
    final entries = await _all();
    return entries.where((entry) => !entry.createdAt.isAfter(now)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// When the earliest scheduled entry becomes visible, if any.
  Future<DateTime?> nextDueAt() async {
    final now = clock.now();
    DateTime? next;
    for (final entry in await _all()) {
      if (entry.createdAt.isAfter(now) &&
          (next == null || entry.createdAt.isBefore(next))) {
        next = entry.createdAt;
      }
    }
    return next;
  }

  Future<NotificationInboxEntry?> get(int id) async {
    try {
      for (final prefs in _stores) {
        final entry = await _readEntry(prefs, _key(id));
        if (entry != null) return entry;
      }
      return null;
    } catch (error) {
      Log.w(
        'NotificationInbox',
        'Could not read entry $id (${error.runtimeType})',
      );
      return null;
    }
  }

  Future<List<NotificationInboxEntry>> retriesDue(DateTime now) async {
    final pending = <NotificationInboxEntry>[];
    await _guard('retriesDue', () async {
      for (final prefs in _stores) {
        for (final key in await prefs.getKeys()) {
          if (!key.startsWith(retryPrefix)) continue;
          final id = int.tryParse(key.substring(retryPrefix.length));
          if (id == null) continue;
          final raw = await prefs.getString(key);
          if (raw == null) continue;
          final progress = jsonDecode(raw);
          if (progress is! Map ||
              progress['remaining'] is! int ||
              (progress['remaining'] as int) <= 0 ||
              progress['retryAt'] is! int ||
              (progress['retryAt'] as int) > now.millisecondsSinceEpoch ||
              ((progress['leaseUntil'] as int?) ?? 0) >
                  now.millisecondsSinceEpoch) {
            continue;
          }
          final entry = await _readEntry(prefs, _key(id));
          if (entry != null &&
              entry.active &&
              entry.createdAt.millisecondsSinceEpoch == progress['createdAt']) {
            pending.add(entry);
          }
        }
      }
    }, notify: false);
    return pending;
  }

  /// Progress belongs to the original delivery and never resets its answer
  /// marker. Only the foreground runtime advances a due retry.
  Future<bool> advanceRetry(
    NotificationInboxEntry entry, {
    required DateTime nextDue,
    required int remaining,
    required bool inApp,
    required bool resetRead,
    bool? retryDelivery,
    DateTime? leaseUntil,
    bool notify = true,
  }) async {
    try {
      final prefs = _preferencesFor(entry);
      final latest = await _readEntry(prefs, _key(entry.id));
      if (latest == null ||
          !latest.active ||
          latest.createdAt != entry.createdAt ||
          latest.retryAt != entry.retryAt ||
          latest.retryClaim != entry.retryClaim ||
          latest.retriesRemaining != entry.retriesRemaining) {
        return false;
      }
      await _writeRetryProgress(
        prefs,
        entry,
        nextDue: nextDue,
        remaining: remaining,
        inApp: inApp,
        retryDelivery: retryDelivery ?? latest.retryDelivery,
        leaseUntil: leaseUntil,
      );
      if (resetRead) await prefs.remove(_readKey(entry.id));
      if (notify) _changed();
      return true;
    } catch (error) {
      Log.w(
        'NotificationInbox',
        'Could not advance retry (${error.runtimeType})',
      );
      return false;
    }
  }

  Future<void> _writeRetryProgress(
    SharedPreferencesAsync prefs,
    NotificationInboxEntry entry, {
    required DateTime nextDue,
    required int remaining,
    required bool inApp,
    bool retryDelivery = false,
    DateTime? leaseUntil,
  }) => prefs.setString(
    _retryKey(entry.id),
    jsonEncode({
      'createdAt': entry.createdAt.millisecondsSinceEpoch,
      'retryAt': nextDue.millisecondsSinceEpoch,
      'remaining': remaining,
      'inApp': inApp,
      if (retryDelivery) 'retryDelivery': true,
      if (leaseUntil != null) 'leaseUntil': leaseUntil.millisecondsSinceEpoch,
    }),
  );

  /// Marks a cancelled notification as no longer actionable. A cancelled
  /// notification that was only scheduled never reached the user, so it is
  /// removed instead of being kept as history.
  Future<void> cancel(int id) => _guard('cancel', () async {
    final entry = await get(id);
    if (entry == null) return;
    if (entry.createdAt.isAfter(clock.now())) {
      await _remove(_preferencesFor(entry), id);
    } else {
      final prefs = _preferencesFor(entry);
      await prefs.setBool(_inactiveKey(id), true);
      await prefs.remove(_retryKey(id));
    }
  });

  Future<void> cancelAll() => _guard('cancelAll', () async {
    final now = clock.now();
    for (final entry in await _all()) {
      if (entry.createdAt.isAfter(now)) {
        await _remove(_preferencesFor(entry), entry.id);
      } else if (entry.active) {
        final prefs = _preferencesFor(entry);
        await prefs.setBool(_inactiveKey(entry.id), true);
        await prefs.remove(_retryKey(entry.id));
      }
    }
  });

  /// The user answered one of the notification's actions.
  Future<void> resolve(int id) => _guard('resolve', () async {
    final entry = await get(id);
    if (entry == null) return;
    final prefs = _preferencesFor(entry);
    await prefs.setBool(_inactiveKey(id), true);
    await prefs.remove(_retryKey(id));
    await prefs.setBool(_readKey(id), true);
  });

  Future<void> markRead(Iterable<int> ids) => _guard('markRead', () async {
    for (final id in ids) {
      final entry = await get(id);
      if (entry != null) {
        await _preferencesFor(entry).setBool(_readKey(id), true);
      }
    }
  });

  /// Erases the chat copy when its account, scope or history is erased.
  Future<void> purgeFamilyChat({
    String? uid,
    String? scope,
    int? beforeHistoryGeneration,
  }) async {
    try {
      for (final key in await _chatPrefs.getKeys()) {
        if (!key.startsWith(keyPrefix)) continue;
        final entry = await _readEntry(_chatPrefs, key);
        if (entry?.type != NotificationEventType.familyChat) continue;
        final payload = entry!.data['payload'] as Map?;
        if (uid != null && payload?['uid'] != uid) continue;
        if (scope != null && payload?['scope'] != scope) continue;
        if (beforeHistoryGeneration != null &&
            ((payload?['historyGeneration'] as int?) ?? 0) >=
                beforeHistoryGeneration) {
          continue;
        }
        await _remove(_chatPrefs, entry.id);
      }
    } finally {
      _changed();
    }
  }

  /// Clears the visible history. Scheduled entries are kept so they still
  /// appear once they fire.
  Future<void> clear() => _guard('clear', () async {
    for (final entry in await visible()) {
      await _remove(_preferencesFor(entry), entry.id);
    }
  });

  Future<void> remove(int id) => _guard('remove', () async {
    final entry = await get(id);
    if (entry != null) await _remove(_preferencesFor(entry), id);
  });

  Future<void> _remove(SharedPreferencesAsync prefs, int id) async {
    await prefs.remove(_key(id));
    await prefs.remove(_readKey(id));
    await prefs.remove(_inactiveKey(id));
    await prefs.remove(_retryKey(id));
  }

  Future<NotificationInboxEntry?> _readEntry(
    SharedPreferencesAsync prefs,
    String key,
  ) async {
    final raw = await prefs.getString(key);
    if (raw == null) return null;
    final json = jsonDecode(raw);
    final entry = json is Map<String, dynamic>
        ? NotificationInboxEntry.tryParse(json)
        : null;
    if (entry == null) {
      await prefs.remove(key);
      return null;
    }
    if (prefs != _preferencesFor(entry)) {
      // Older Android builds wrote full chat content to the default DataStore.
      // Remove it on first access; it may belong to a revoked account.
      await _remove(prefs, entry.id);
      return null;
    }
    final read = await prefs.getBool(_readKey(entry.id)) ?? false;
    final inactive = await prefs.getBool(_inactiveKey(entry.id)) ?? false;
    var current = entry.copyWith(read: read, active: !inactive);
    if (entry.retryAt != null) {
      final rawProgress = await prefs.getString(_retryKey(entry.id));
      final progress = rawProgress == null ? null : jsonDecode(rawProgress);
      if (progress is Map &&
          progress['createdAt'] == entry.createdAt.millisecondsSinceEpoch) {
        current = current.copyWith(
          retryAt: DateTime.fromMillisecondsSinceEpoch(
            progress['retryAt'] as int,
          ),
          retriesRemaining: progress['remaining'] as int,
          inApp: progress['inApp'] as bool,
          retryDelivery: progress['retryDelivery'] == true,
          retryClaim: progress['leaseUntil'] as int?,
        );
      }
    }
    return current;
  }

  Future<List<NotificationInboxEntry>> _all() async {
    final Set<SharedPreferencesAsync> stores;
    try {
      stores = _stores;
    } catch (error) {
      Log.w('NotificationInbox', 'Inbox unavailable (${error.runtimeType})');
      return const [];
    }
    final entries = <NotificationInboxEntry>[];
    for (final prefs in stores) {
      try {
        for (final key in await prefs.getKeys()) {
          if (!key.startsWith(keyPrefix)) continue;
          try {
            final entry = await _readEntry(prefs, key);
            if (entry != null) entries.add(entry);
          } on FormatException {
            await prefs.remove(key);
          }
        }
      } catch (error) {
        Log.w(
          'NotificationInbox',
          'Could not read inbox (${error.runtimeType})',
        );
      }
    }
    return entries;
  }

  Future<void> _prune() async {
    final now = clock.now();
    final cutoff = now.subtract(retention);
    final due =
        (await _all()).where((entry) => !entry.createdAt.isAfter(now)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (var index = 0; index < due.length; index++) {
      final entry = due[index];
      if (index >= maxEntries || entry.createdAt.isBefore(cutoff)) {
        await _remove(_preferencesFor(entry), entry.id);
      }
    }
  }

  Future<void> _guard(
    String operation,
    Future<void> Function() body, {
    bool notify = true,
  }) async {
    try {
      await body();
    } catch (error) {
      Log.w('NotificationInbox', 'Inbox $operation failed ($error)');
    }
    if (notify && operation != 'prune') _changed();
  }
}
