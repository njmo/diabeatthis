import 'package:diabeatthis/common/meal_advisor/notifications/meal_decision_notification_intent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts only known notification payloads and actions', () {
    const payload = '{"type":"meal_decision","requestId":"abc123"}';
    expect(MealDecisionNotificationIntent.parse(payload, null)?.action, 'open');
    expect(
      MealDecisionNotificationIntent.parse(payload, 'claim')?.requestId,
      'abc123',
    );
    expect(
      MealDecisionNotificationIntent.parse(payload, 'decline')?.action,
      'decline',
    );
    expect(MealDecisionNotificationIntent.parse(payload, 'bad'), isNull);
    expect(
      MealDecisionNotificationIntent.parse(
        '{"type":"meal_decision","requestId":"../bad"}',
        null,
      ),
      isNull,
    );
    expect(
      MealDecisionNotificationIntent.parse('{"requestId":"abc123"}', null),
      isNull,
    );
    expect(MealDecisionNotificationIntent.parse('bad', null), isNull);
  });

  test('persists intents until they are handled', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = MealDecisionNotificationIntentStore();
    final intent = MealDecisionNotificationIntent.parse(
      '{"type":"meal_decision","requestId":"abc123"}',
      'delegate',
    )!;
    await store.add(intent);
    await store.add(intent);
    expect((await store.read()).single.action, 'delegate');
    await store.remove(intent);
    expect(await store.read(), isEmpty);
  });
  test(
    'concurrent arrival and removal preserve unrelated notification actions',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final first = MealDecisionNotificationIntentStore();
      final second = MealDecisionNotificationIntentStore();
      const a = MealDecisionNotificationIntent('one', 'claim');
      const b = MealDecisionNotificationIntent('two', 'delegate');
      await Future.wait([first.add(a), second.add(b)]);
      expect(
        (await first.read()).map((v) => v.requestId),
        containsAll(['one', 'two']),
      );
      const c = MealDecisionNotificationIntent('three', 'decline');
      await Future.wait([first.remove(a), second.add(c)]);
      expect(
        (await first.read()).map((v) => v.requestId),
        containsAll(['two', 'three']),
      );
      expect(
        (await first.read()).map((v) => v.requestId),
        isNot(contains('one')),
      );
    },
  );
}
