import 'package:diabeatthis/common/auth/load_firebase_callable_identity.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a token returned for another native account cannot impersonate the cached Dart user',
    () {
      expect(
        () => validateCallableTokenSubject(
          expectedUid: 'A',
          token: 'token-for-B',
          claims: {'sub': 'B'},
          appCheckToken: 'app',
        ),
        throwsA(isA<CallableFailure>()),
      );
      expect(
        validateCallableTokenSubject(
          expectedUid: 'A',
          token: 'token-for-A',
          claims: {'sub': 'A'},
          appCheckToken: 'app',
        ).uid,
        'A',
      );
      expect(
        () => validateCallableTokenSubject(
          expectedUid: 'A',
          token: 'token-for-A',
          claims: null,
          appCheckToken: 'app',
        ),
        throwsA(isA<CallableFailure>()),
      );
    },
  );
}
