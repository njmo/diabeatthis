import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/load_firebase_callable_identity.dart';
import '../backend/authenticated_callable_transport.dart';
import 'firebase_family_repository.dart';
import 'secure_family_repository.dart';

final authenticatedFamilyTransportProvider =
    Provider.autoDispose<AuthenticatedCallableTransport>((ref) {
      final client = http.Client();
      ref.onDispose(client.close);
      return AuthenticatedCallableTransport(
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
          return loadFirebaseCallableIdentity();
        },
      );
    });

final secureFamilyRepositoryProvider =
    Provider.autoDispose<SecureFamilyRepository>((ref) {
      final repository = FirebaseFamilyRepository(
        ref.watch(authenticatedFamilyTransportProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });
