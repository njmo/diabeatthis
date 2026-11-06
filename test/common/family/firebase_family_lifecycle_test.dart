import 'dart:async';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/firebase_family_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'family polling is shared, pauses with the app and stops without listeners',
    () {
      fakeAsync((time) {
        var calls = 0;
        final repository = FirebaseFamilyRepository(
          AuthenticatedCallableTransport(
            client: MockClient((_) async {
              calls++;
              return http.Response(
                '{"result":{"members":[],"pending":null}}',
                200,
              );
            }),
            projectId: 'test',
            currentUid: () => 'parent',
            identity: () async =>
                const CallableIdentity('parent', 'token', 'app-token'),
          ),
        );
        final first = repository.watchStatus().listen((_) {});
        final second = repository.watchStatus().listen((_) {});
        time.flushMicrotasks();
        expect(calls, 1);
        repository.didChangeAppLifecycleState(AppLifecycleState.paused);
        time.elapse(const Duration(seconds: 6));
        expect(calls, 1);
        repository.didChangeAppLifecycleState(AppLifecycleState.resumed);
        time.flushMicrotasks();
        expect(calls, 2);
        unawaited(first.cancel());
        unawaited(second.cancel());
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 6));
        expect(calls, 2);
        repository.dispose();
        time.flushMicrotasks();
        expect(time.nonPeriodicTimerCount, 0);
      });
    },
  );
}
