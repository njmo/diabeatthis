import 'package:diabeatthis/common/meal_advisor/notifications/meal_decision_notification_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'notification eligibility follows the last observed account and state',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final status = MealDecisionNotificationEligibility();
      expect(await status.allows('one'), isFalse);
      await status.set('one', true);
      expect(await status.allows('one'), isTrue);
      expect(await status.allows('two'), isFalse);
      expect(await status.allows(null), isFalse);
      await status.set('one', false);
      expect(await status.allows('one'), isFalse);
    },
  );
}
