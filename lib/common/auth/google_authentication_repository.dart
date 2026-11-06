import 'google_account.dart';

abstract interface class GoogleAuthenticationRepository {
  bool get isSupported;
  Stream<GoogleAccount?> watchAccount();
  Future<GoogleAccount?> signIn();
  Future<void> signOut();
}
