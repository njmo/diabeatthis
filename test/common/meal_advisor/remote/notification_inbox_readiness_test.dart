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

class _Controller extends MealDecisionRemoteController {
  @override
  MealDecisionRemoteInbox build() => const MealDecisionRemoteInbox();
}

void main() {
  test(
    'malformed server response is not an authoritative empty inbox',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"result":{}}', 200),
      );
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
                  const CallableIdentity('parent', 'token', 'app'),
            ),
          ),
          mealDecisionRemoteControllerProvider.overrideWith(_Controller.new),
        ],
      );
      addTearDown(() {
        container.dispose();
        client.close();
      });
      final subscription = container.listen(googleAccountProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(googleAccountProvider.future);
      await container
          .read(mealDecisionRemoteControllerProvider.notifier)
          .refresh();
      final inbox = container.read(mealDecisionRemoteControllerProvider);
      expect(inbox.failed, isTrue);
      expect(inbox.canResolveNotificationFor('parent'), isFalse);
    },
  );

  test(
    'cold-start inbox cannot resolve a tap before a successful current-account fetch',
    () async {
      final response = Completer<http.Response>();
      final client = MockClient((_) => response.future);
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
                  const CallableIdentity('parent', 'token', 'app'),
            ),
          ),
          mealDecisionRemoteControllerProvider.overrideWith(_Controller.new),
        ],
      );
      addTearDown(() {
        container.dispose();
        client.close();
      });
      final subscription = container.listen(googleAccountProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(
        const MealDecisionRemoteInbox().canResolveNotificationFor(null),
        isFalse,
      );
      await container.read(googleAccountProvider.future);
      final controller = container.read(
        mealDecisionRemoteControllerProvider.notifier,
      );
      expect(
        container
            .read(mealDecisionRemoteControllerProvider)
            .canResolveNotificationFor('parent'),
        isFalse,
      );
      final pending = controller.refresh();
      expect(
        container
            .read(mealDecisionRemoteControllerProvider)
            .canResolveNotificationFor('parent'),
        isFalse,
      );
      response.complete(http.Response('{"result":{"requests":[]}}', 200));
      await pending;
      final inbox = container.read(mealDecisionRemoteControllerProvider);
      expect(inbox.canResolveNotificationFor('parent'), isTrue);
      expect(inbox.canResolveNotificationFor('other-account'), isFalse);
      expect(inbox.canResolveNotificationFor(null), isFalse);
      expect(inbox.byId('missing'), isNull);
    },
  );

  test('failed or loading reads cannot discard an intent', () {
    expect(
      const MealDecisionRemoteInbox(
        accountUid: 'parent',
        failed: true,
      ).canResolveNotificationFor('parent'),
      isFalse,
    );
    expect(
      const MealDecisionRemoteInbox(
        accountUid: 'parent',
        loading: true,
        authoritative: true,
      ).canResolveNotificationFor('parent'),
      isFalse,
    );
    expect(
      const MealDecisionRemoteInbox(
        accountUid: 'parent',
      ).canResolveNotificationFor('parent'),
      isFalse,
    );
  });
}
