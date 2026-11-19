import 'package:clock/clock.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_entry.dart';
import 'package:diabeatthis/core/notifications/inbox/notification_inbox_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

NotificationInboxEntry _entry(int id, DateTime at) => NotificationInboxEntry(
  id: id,
  type: NotificationEventType.eatNow,
  title: 'title $id',
  body: 'body $id',
  data: {'mealId': id, 'minutes': 15},
  createdAt: at,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 18, 12);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('lists due entries newest first and hides scheduled ones', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore();
      await store.put(_entry(1, now.subtract(const Duration(minutes: 5))));
      await store.put(_entry(2, now.subtract(const Duration(minutes: 1))));
      await store.put(_entry(3, now.add(const Duration(minutes: 30))));

      final visible = await store.visible();
      expect(visible.map((e) => e.id), [2, 1]);
      expect(visible.first.data, {'mealId': 2, 'minutes': 15});
    });
  });

  test('re-posting the same notification replaces its entry', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore();
      await store.put(_entry(1, now.subtract(const Duration(minutes: 5))));
      await store.markRead([1]);
      await store.put(_entry(1, now));

      final visible = await store.visible();
      expect(visible, hasLength(1));
      expect(visible.single.read, isFalse);
      expect(visible.single.createdAt, now);
    });
  });

  test('cancel keeps delivered history but drops unsent schedules', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore();
      await store.put(_entry(1, now));
      await store.put(_entry(2, now.add(const Duration(minutes: 30))));

      await store.cancel(1);
      await store.cancel(2);

      expect((await store.get(1))!.active, isFalse);
      expect(await store.get(2), isNull);
    });
  });

  test('resolving an answered notification marks it read and inactive', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore();
      await store.put(_entry(1, now));
      await store.resolve(1);
      final entry = (await store.get(1))!;
      expect(entry.read, isTrue);
      expect(entry.active, isFalse);
    });
  });

  test('prunes old and excess entries', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore(
        maxEntries: 2,
        retention: const Duration(hours: 1),
      );
      await store.put(_entry(1, now.subtract(const Duration(hours: 2))));
      await store.put(_entry(2, now.subtract(const Duration(minutes: 3))));
      await store.put(_entry(3, now.subtract(const Duration(minutes: 2))));
      await store.put(_entry(4, now.subtract(const Duration(minutes: 1))));

      expect((await store.visible()).map((e) => e.id), [4, 3]);
    });
  });

  test('clear keeps scheduled entries for when they fire', () {
    return withClock(Clock.fixed(now), () async {
      final store = NotificationInboxStore();
      await store.put(_entry(1, now));
      await store.put(_entry(2, now.add(const Duration(minutes: 30))));
      await store.clear();
      expect(await store.visible(), isEmpty);
      expect(await store.get(2), isNotNull);
    });
  });
}
