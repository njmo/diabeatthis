import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../core/firebase/firebase_app_check_provider.dart';
import '../../firebase_options.dart';
import '../auth/load_firebase_callable_identity.dart';
import '../backend/authenticated_callable_transport.dart';
import 'publish_family_mirror_use_case.dart';

/// Optional networking never delays or authorizes local monitoring operations.
class FamilyMirrorBackgroundRuntime {
  FamilyMirrorBackgroundRuntime(this.db);
  final DatabaseImpl db;
  final client = http.Client();
  Timer? timer;
  StreamSubscription<User?>? accountSubscription;
  bool disposed = false;
  bool running = false;
  Future<void>? initialization;
  bool wakePending = false;

  void requestSync() {
    if (running) {
      wakePending = true;
    } else {
      unawaited(tick());
    }
  }

  void start() {
    timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(tick()),
    );
    unawaited(tick());
  }

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: await createAndroidAppCheckProvider(),
    );
    if (!disposed) {
      accountSubscription ??= FirebaseAuth.instance.idTokenChanges().listen(
        (_) {},
        onError: (Object error) {},
      );
    }
  }

  Future<void> tick() async {
    if (disposed || running) return;
    running = true;
    try {
      final settings = await db
          .customSelect(
            'SELECT enabled,enabled_revision FROM family_sync_identity WHERE singleton=1',
          )
          .getSingle();
      if (settings.read<int>('enabled') != 1 || disposed) return;
      final queue = FamilyMirrorOutbox(db);
      if ((await queue.pending(limit: 1)).isEmpty) return;
      await db.customStatement(
        'UPDATE family_sync_runtime SET requested=0,active_until=? WHERE singleton=1',
        [DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch],
      );
      initialization ??= initialize()
          .timeout(const Duration(seconds: 15))
          .catchError((Object error) {
            initialization = null;
            throw error;
          });
      await initialization;
      if (disposed) return;
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: Firebase.app().options.projectId,
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        identity: loadFirebaseCallableIdentity,
      );
      final consent = settings.read<int>('enabled_revision');
      final published = await PublishFamilyMirrorUseCase(
        outbox: queue,
        transport: transport,
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        canSend: () async {
          if (disposed || !await queue.enabledAt(consent)) return false;
          await db.customStatement(
            'UPDATE family_sync_runtime SET active_until=? WHERE singleton=1',
            [
              DateTime.now()
                  .add(const Duration(minutes: 2))
                  .millisecondsSinceEpoch,
            ],
          );
          return true;
        },
      )();
      if (!disposed) {
        await db.customStatement(
          'UPDATE family_sync_identity SET last_error=NULL WHERE singleton=1',
        );
        if (published > 0) {
          await db.customStatement(
            'UPDATE family_sync_identity SET last_success=? WHERE singleton=1',
            [DateTime.now().millisecondsSinceEpoch],
          );
        }
      }
    } catch (_) {
      if (!disposed) {
        try {
          await db.customStatement(
            "UPDATE family_sync_identity SET last_error='sync-unavailable' WHERE singleton=1",
          );
        } catch (_) {}
      }
    } finally {
      try {
        await db.customStatement(
          'UPDATE family_sync_runtime SET active_until=0 WHERE singleton=1',
        );
      } catch (_) {}
      running = false;
      if (wakePending && !disposed) {
        wakePending = false;
        unawaited(tick());
      }
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    unawaited(accountSubscription?.cancel());
    client.close();
  }
}
