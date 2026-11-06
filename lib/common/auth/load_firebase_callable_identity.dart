import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../backend/authenticated_callable_transport.dart';

/// Native SDK calls can outlive an account switch in a different Flutter isolate.
/// Bind the returned token's subject, not only the cached Dart User object.
CallableIdentity validateCallableTokenSubject({
  required String expectedUid,
  required String? token,
  required Map<String, dynamic>? claims,
  required String? appCheckToken,
}) {
  if (claims?['sub'] != expectedUid ||
      token == null ||
      token.isEmpty ||
      appCheckToken == null ||
      appCheckToken.isEmpty) {
    throw const CallableFailure('unauthenticated');
  }
  return CallableIdentity(expectedUid, token, appCheckToken);
}

Future<CallableIdentity> loadFirebaseCallableIdentity() async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null ||
      !user.providerData.any(
        (provider) => provider.providerId == 'google.com',
      )) {
    throw const CallableFailure('unauthenticated');
  }
  final result = await user.getIdTokenResult();
  final appCheckToken = await FirebaseAppCheck.instance.getToken();
  if (auth.currentUser?.uid != user.uid) {
    throw const CallableFailure('unauthenticated');
  }
  return validateCallableTokenSubject(
    expectedUid: user.uid,
    token: result.token,
    claims: result.claims,
    appCheckToken: appCheckToken,
  );
}
