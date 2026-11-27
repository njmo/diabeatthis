import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../core/drift/database_impl.dart';
import '../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../core/firebase/initialize_family_firebase.dart';
import '../auth/load_firebase_callable_identity.dart';
import '../backend/authenticated_callable_transport.dart';
import '../backend/family_sync_diagnostics.dart';
import 'publish_family_mirror_use_case.dart';

/// Optional networking never delays or authorizes local monitoring operations.
class FamilyMirrorBackgroundRuntime {
  FamilyMirrorBackgroundRuntime(this.db);
  final DatabaseImpl db;
  final client = http.Client();
  Timer? timer;
  StreamSubscription? databaseSubscription;
  DateTime? retryAfter;
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
    databaseSubscription ??= db.tableUpdates().listen((_) => requestSync());
    unawaited(tick());
  }

  void scheduleRetry() {
    if (disposed) return;
    retryAfter = DateTime.now().add(const Duration(seconds: 15));
    timer?.cancel();
    timer = Timer(const Duration(seconds: 15), () {
      retryAfter = null;
      requestSync();
    });
  }

  Future<void> initialize() async {
    await initializeFamilyFirebase();
    if (!disposed) {
      accountSubscription ??= FirebaseAuth.instance.idTokenChanges().listen((
        _,
      ) {
        retryAfter = null;
        requestSync();
      }, onError: (Object error) => scheduleRetry());
    }
  }

  Future<void> tick() async {
    if (disposed || running || (retryAfter?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    running = true;
    try {
      final settings = await db
          .customSelect(
            'SELECT enabled,enabled_revision FROM family_sync_identity WHERE singleton=1',
          )
          .getSingle();
      if (settings.read<int>('enabled') != 1 || disposed) return;
      final queue = FamilyMirrorOutbox(db);
      if ((await queue.pending(limit: 1)).isEmpty &&
          await queue.publishableMealHeaderCompletion == null) {
        return;
      }
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
      if (FirebaseAuth.instance.currentUser == null) {
        familySyncDiag('mirror: no signed-in Firebase user');
        retryAfter = null;
        timer?.cancel();
        return;
      }
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
      if (published > 0 && (await queue.pending(limit: 1)).isNotEmpty) {
        wakePending = true;
      }
      if (!disposed) {
        retryAfter = null;
        timer?.cancel();
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
    } catch (error, stack) {
      familySyncDiag('mirror publish failed: ${familySyncDiagError(error)}');
      familySyncDiag(
        'mirror stack: ${stack.toString().split('\n').take(6).join(' | ')}',
      );
      scheduleRetry();
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
    unawaited(databaseSubscription?.cancel());
    unawaited(accountSubscription?.cancel());
    client.close();
  }
}
