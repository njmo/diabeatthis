import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../logger/logger.dart';
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
    this.maxEntries = 40,
    this.retention = const Duration(days: 3),
  }) : _injected = preferences;

  static const keyPrefix = 'notification_inbox:';
  static const readPrefix = 'notification_inbox.read:';
  static const inactivePrefix = 'notification_inbox.inactive:';

  static final _changes = StreamController<void>.broadcast();

  /// Fires after any store in this isolate changed the inbox, including
  /// short-lived ones owned by push handlers, so the UI can follow along.
  static Stream<void> get changes => _changes.stream;

  void _changed() => _changes.add(null);

  final SharedPreferencesAsync? _injected;
  late final SharedPreferencesAsync _prefs =
      _injected ?? SharedPreferencesAsync();

  final int maxEntries;
  final Duration retention;

  String _key(int id) => '$keyPrefix$id';
  String _readKey(int id) => '$readPrefix$id';
  String _inactiveKey(int id) => '$inactivePrefix$id';

  /// Records a new delivery. Returns false when it could not be persisted.
  Future<bool> put(NotificationInboxEntry entry) async {
    try {
      await _prefs.remove(_readKey(entry.id));
      await _prefs.remove(_inactiveKey(entry.id));
      await _prefs.setString(_key(entry.id), jsonEncode(entry.toJson()));
      if (entry.read) await _prefs.setBool(_readKey(entry.id), true);
      if (!entry.active) await _prefs.setBool(_inactiveKey(entry.id), true);
    } catch (error) {
      Log.w('NotificationInbox', 'Inbox put failed ($error)');
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
      final raw = await _prefs.getString(_key(id));
      if (raw == null) return null;
      return await _withMarkers(
        NotificationInboxEntry.tryParse(
          jsonDecode(raw) as Map<String, dynamic>,
        ),
      );
    } catch (error) {
      Log.w('NotificationInbox', 'Could not read entry $id ($error)');
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
      await _remove(id);
    } else {
      await _prefs.setBool(_inactiveKey(id), true);
    }
  });

  Future<void> cancelAll() => _guard('cancelAll', () async {
    final now = clock.now();
    for (final entry in await _all()) {
      if (entry.createdAt.isAfter(now)) {
        await _remove(entry.id);
      } else if (entry.active) {
        await _prefs.setBool(_inactiveKey(entry.id), true);
      }
    }
  });

  /// The user answered one of the notification's actions.
  Future<void> resolve(int id) => _guard('resolve', () async {
    if (await _prefs.getString(_key(id)) == null) return;
    await _prefs.setBool(_inactiveKey(id), true);
    await _prefs.setBool(_readKey(id), true);
  });

  Future<void> markRead(Iterable<int> ids) => _guard('markRead', () async {
    for (final id in ids) {
      if (await _prefs.getString(_key(id)) == null) continue;
      await _prefs.setBool(_readKey(id), true);
    }
  });

  /// Clears the visible history. Scheduled entries are kept so they still
  /// appear once they fire.
  Future<void> clear() => _guard('clear', () async {
    for (final entry in await visible()) {
      await _remove(entry.id);
    }
  });

  Future<void> _remove(int id) async {
    await _prefs.remove(_key(id));
    await _prefs.remove(_readKey(id));
    await _prefs.remove(_inactiveKey(id));
  }

  Future<NotificationInboxEntry?> _withMarkers(
    NotificationInboxEntry? entry,
  ) async {
    if (entry == null) return null;
    final read = await _prefs.getBool(_readKey(entry.id)) ?? false;
    final inactive = await _prefs.getBool(_inactiveKey(entry.id)) ?? false;
    return entry.copyWith(read: read, active: !inactive);
  }

  Future<List<NotificationInboxEntry>> _all() async {
    try {
      final keys = await _prefs.getKeys();
      final entries = <NotificationInboxEntry>[];
      for (final key in keys) {
        if (!key.startsWith(keyPrefix)) continue;
        final raw = await _prefs.getString(key);
        if (raw == null) continue;
        NotificationInboxEntry? entry;
        try {
          entry = NotificationInboxEntry.tryParse(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        } on FormatException {
          entry = null;
        }
        if (entry == null) {
          await _prefs.remove(key);
          continue;
        }
        entries.add((await _withMarkers(entry))!);
      }
      return entries;
    } catch (error) {
      Log.w('NotificationInbox', 'Could not read inbox ($error)');
      return const [];
    }
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
        await _remove(entry.id);
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
