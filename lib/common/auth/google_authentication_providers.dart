import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_google_authentication_repository.dart';
import 'google_account.dart';
import 'google_authentication_repository.dart';

final googleAuthenticationRepositoryProvider =
    Provider<GoogleAuthenticationRepository>(
      (ref) => FirebaseGoogleAuthenticationRepository(),
    );
final googleAccountProvider = StreamProvider<GoogleAccount?>(
  (ref) => ref.watch(googleAuthenticationRepositoryProvider).watchAccount(),
);
