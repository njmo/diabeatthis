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
  String _readKey(int id) => '$readPrefix$id';
  String _inactiveKey(int id) => '$inactivePrefix$id';

  /// Records a new delivery. Returns false when it could not be persisted.
  Future<bool> put(NotificationInboxEntry entry) async {
    try {
      final prefs = _preferencesFor(entry);
      await prefs.remove(_readKey(entry.id));
      await prefs.remove(_inactiveKey(entry.id));
      await prefs.setString(_key(entry.id), jsonEncode(entry.toJson()));
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

  /// Marks a cancelled notification as no longer actionable. A cancelled
  /// notification that was only scheduled never reached the user, so it is
  /// removed instead of being kept as history.
  Future<void> cancel(int id) => _guard('cancel', () async {
    final entry = await get(id);
    if (entry == null) return;
    if (entry.createdAt.isAfter(clock.now())) {
      await _remove(_preferencesFor(entry), id);
    } else {
      await _preferencesFor(entry).setBool(_inactiveKey(id), true);
    }
  });

  Future<void> cancelAll() => _guard('cancelAll', () async {
    final now = clock.now();
    for (final entry in await _all()) {
      if (entry.createdAt.isAfter(now)) {
        await _remove(_preferencesFor(entry), entry.id);
      } else if (entry.active) {
        await _preferencesFor(entry).setBool(_inactiveKey(entry.id), true);
      }
    }
  });

  /// The user answered one of the notification's actions.
  Future<void> resolve(int id) => _guard('resolve', () async {
    final entry = await get(id);
    if (entry == null) return;
    final prefs = _preferencesFor(entry);
    await prefs.setBool(_inactiveKey(id), true);
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

  Future<void> _remove(SharedPreferencesAsync prefs, int id) async {
    await prefs.remove(_key(id));
    await prefs.remove(_readKey(id));
    await prefs.remove(_inactiveKey(id));
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
    return entry.copyWith(read: read, active: !inactive);
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

  Future<void> _guard(String operation, Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      Log.w('NotificationInbox', 'Inbox $operation failed ($error)');
    }
    if (operation != 'prune') _changed();
  }
}
