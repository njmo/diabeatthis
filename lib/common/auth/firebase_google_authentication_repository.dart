import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_account.dart';
import 'google_authentication_repository.dart';

class FirebaseGoogleAuthenticationRepository
    implements GoogleAuthenticationRepository {
  FirebaseGoogleAuthenticationRepository({
    FirebaseAuth? auth,
    GoogleSignIn? google,
  }) : suppliedAuth = auth,
       google = google ?? GoogleSignIn.instance;
  final FirebaseAuth? suppliedAuth;
  FirebaseAuth get auth => suppliedAuth ?? FirebaseAuth.instance;
  final GoogleSignIn google;
  Future<void>? initialization;
  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  GoogleAccount? account(User? user) {
    if (user == null) return null;
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        return GoogleAccount(
          uid: user.uid,
          email: provider.email ?? user.email,
          displayName: provider.displayName ?? user.displayName,
          photoUrl: provider.photoURL ?? user.photoURL,
        );
      }
    }
    return null;
  }

  @override
  Stream<GoogleAccount?> watchAccount() =>
      isSupported ? auth.userChanges().map(account) : Stream.value(null);

  @override
  Future<GoogleAccount?> signIn() async {
    if (!isSupported) {
      throw UnsupportedError('Google sign-in is configured only for Android');
    }
    initialization ??= google.initialize();
    try {
      await initialization;
    } catch (_) {
      initialization = null;
      rethrow;
    }
    try {
      final selected = await google.authenticate();
      final token = selected.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw StateError('Google sign-in returned no identity token');
      }
      return account(
        (await auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        )).user,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!isSupported) return;
    await auth.signOut();
    if (!kIsWeb && initialization != null) await google.signOut();
  }
}
