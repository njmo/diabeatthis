import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../backend/authenticated_callable_transport.dart';
import 'firebase_family_repository.dart';
import 'secure_family_repository.dart';

final secureFamilyRepositoryProvider =
    Provider.autoDispose<SecureFamilyRepository>((ref) {
      final client = http.Client();
      final repository = FirebaseFamilyRepository(
        AuthenticatedCallableTransport(
          client: client,
          projectId: Firebase.apps.isEmpty
              ? ''
              : Firebase.app().options.projectId,
          currentUid: () => Firebase.apps.isEmpty
              ? null
              : FirebaseAuth.instance.currentUser?.uid,
          identity: () async {
            if (Firebase.apps.isEmpty) {
              throw const CallableFailure('unauthenticated');
            }
            final user = FirebaseAuth.instance.currentUser;
            if (user == null ||
                !user.providerData.any(
                  (provider) => provider.providerId == 'google.com',
                )) {
              throw const CallableFailure('unauthenticated');
            }
            final idToken = await user.getIdToken();
            final appToken = await FirebaseAppCheck.instance.getToken();
            return CallableIdentity(user.uid, idToken ?? '', appToken ?? '');
          },
        ),
      );
      ref.onDispose(() {
        repository.dispose();
        client.close();
      });
      return repository;
    });
