import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class RefreshTestController extends MealDecisionRemoteController {
  @override
  MealDecisionRemoteInbox build() => const MealDecisionRemoteInbox();
}

void main() {
  test('concurrent refresh callers wait through the coalesced fetch', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final beganFirst = Completer<void>();
    final beganSecond = Completer<void>();
    var count = 0;
    final client = MockClient((request) {
      if (++count == 1) {
        beganFirst.complete();
        return first.future;
      }
      beganSecond.complete();
      return second.future;
    });
    final container = ProviderContainer(
      overrides: [
        googleAccountProvider.overrideWith(
          (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
        ),
        authenticatedFamilyTransportProvider.overrideWithValue(
          AuthenticatedCallableTransport(
            client: client,
            projectId: 'test',
            currentUid: () => 'parent',
            identity: () async =>
                const CallableIdentity('parent', 'id-token', 'app-check'),
          ),
        ),
        mealDecisionRemoteControllerProvider.overrideWith(
          RefreshTestController.new,
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      client.close();
    });
    final subscription = container.listen(googleAccountProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(googleAccountProvider.future);
    final controller = container.read(
      mealDecisionRemoteControllerProvider.notifier,
    );
    var completed = false;
    final a = controller.refresh().then((_) => completed = true);
    await beganFirst.future;
    final b = controller.refresh();
    first.complete(http.Response('{"result":{"requests":[]}}', 200));
    await beganSecond.future;
    expect(completed, isFalse);
    second.complete(http.Response('{"result":{"requests":[]}}', 200));
    await Future.wait([a, b]);
    expect(count, 2);
    expect(completed, isTrue);
    expect(
      container.read(mealDecisionRemoteControllerProvider).failed,
      isFalse,
    );
  });
}
