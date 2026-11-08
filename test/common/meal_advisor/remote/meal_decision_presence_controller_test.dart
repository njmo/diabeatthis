import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_presence_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'background and resume publish without rendering or changing step',
    (tester) async {
      final events = <(String, bool)>[];
      final presence = MealDecisionPresenceController((stage, present) async {
        events.add((stage, present));
      });
      presence.start();
      presence.update(enabled: true, stage: 'context');
      await presence.queue;
      events.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await presence.queue;
      expect(events, [('context', false)]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await presence.queue;
      expect(events, [('context', false), ('context', true)]);
      presence.update(enabled: true, stage: 'decision');
      await presence.queue;
      expect(events.last, ('decision', true));
      presence.dispose();
      await presence.queue;
      expect(events.last, ('decision', false));
    },
  );

  testWidgets('disabled presence does not publish lifecycle changes', (
    tester,
  ) async {
    var calls = 0;
    final presence = MealDecisionPresenceController((_, _) async => calls++);
    presence.start();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await presence.queue;
    expect(calls, 0);
    presence.dispose();
  });
}
