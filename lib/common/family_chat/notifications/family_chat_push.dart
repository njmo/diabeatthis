import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../core/firebase/firebase_app_check_provider.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/family_chat_notification.dart';
import '../../../features/low_treatment/application/resolve_low_treatment_upload_status_use_case.dart';
import '../../../features/low_treatment/application/snooze_aaps_carbs_request.dart';
import '../../../features/low_treatment/data/providers/low_treatment_upload_provider.dart';
import '../../../firebase_options.dart';
import '../../auth/load_firebase_callable_identity.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../../identifiers/create_uuid.dart';
import '../../l10n/language.dart';
import '../application/confirm_family_treatment.dart';
import '../application/family_chat_background.dart';
import '../application/family_chat_consumption_action.dart';
import '../application/family_treatment_aaps_handoff.dart';
import '../application/family_treatment_adapter.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_remote.dart';
import '../domain/family_treatment_authorization.dart';
import 'family_chat_presenter.dart';
import 'family_chat_presenter_provider.dart';
import 'family_chat_registration.dart';

final familyChatOpenEvents = StreamController<void>.broadcast();
Map<String, dynamic>? familyChatNotificationPayload(String? raw) {
  if (raw == null || raw.length > 4096) return null;
  try {
    final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return value['type'] == 'familyChat' ? value : null;
  } catch (_) {
    return null;
  }
}

Future<bool?> revalidateFamilyTreatmentRetry(
  FamilyChatNotificationEvent event,
) async {
  bool? allowed;
  await _withWorker((worker, _, _) async {
    allowed = await worker.canRetryTreatment(
      Map<String, dynamic>.from(event.payload),
    );
  });
  return allowed;
}

Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _withWorker(
  Future<void> Function(
    FamilyChatBackground,
    FamilyChatDatabase,
    AndroidFamilyChatPresenter,
  )
  operation, {
  bool Function(String)? shouldPresent,
  AndroidFamilyChatPresenter? presenter,
}) async {
  await _initialize();
  final auth = FirebaseAuth.instance,
      uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    final db = FamilyChatDatabase();
    try {
      await disableFamilyChatRollout(db);
    } catch (_) {
      /* Keep revocations durable for foreground recovery. */
    } finally {
      await db.close();
    }
    return;
  }
  final client = http.Client();
  final db = FamilyChatDatabase();
  final api = FamilyChatRemote(
    AuthenticatedCallableTransport(
      client: client,
      projectId: Firebase.app().options.projectId,
      identity: () async {
        await activateFamilyAppCheck();
        return loadFirebaseCallableIdentity();
      },
      currentUid: () => auth.currentUser?.uid,
    ),
    uid,
  );
  try {
    await withFamilyChatPresenter(
      (presenter) => operation(
        FamilyChatBackground(
          db: db,
          api: api,
          currentUid: () => auth.currentUser?.uid,
          presenter: presenter,
          shouldPresent: shouldPresent,
        ),
        db,
        presenter,
      ),
      presenter: presenter,
    );
  } catch (error) {
    // Outbox/ACKs remain in the private DB. Never log notification contents.
    Log.w(
      'FamilyChatPush',
      'Notification worker failed (${error.runtimeType})',
    );
  } finally {
    client.close();
    await db.close();
  }
}

Future<void> showFamilyChatPush(
  RemoteMessage message, {
  bool Function(String)? shouldPresent,
  AndroidFamilyChatPresenter? presenter,
}) => _withWorker(
  (worker, _, _) async {
    await worker.receive(Map<String, dynamic>.from(message.data));
  },
  shouldPresent: shouldPresent,
  presenter: presenter,
);

Future<void> _queueConversationOpen(
  Map<String, dynamic> payload, {
  required bool reviewAaps,
}) async {
  await _initialize();
  final uid = payload['uid'];
  final scope = payload['scope'];
  final messageId = payload['messageId'];
  final generation = payload['historyGeneration'] ?? 0;
  if (uid is! String ||
      FirebaseAuth.instance.currentUser?.uid != uid ||
      scope is! String ||
      messageId is! String ||
      generation is! int) {
    return;
  }
  final db = FamilyChatDatabase();
  try {
    // The foreground runtime revalidates admission before routing the action.
    await db.setMetadata('chatOpen', {
      'uid': uid,
      'scope': scope,
      'messageId': messageId,
      'historyGeneration': generation,
      'intentId': createUuid(),
      if (reviewAaps) ...{'reviewAaps': true, 'stamp': payload['stamp']},
    });
    familyChatOpenEvents.add(null);
  } catch (error) {
    Log.w(
      'FamilyChatPush',
      'Could not queue conversation (${error.runtimeType})',
    );
  } finally {
    await db.close();
  }
}

/// [presenter] is the app's own presenter when the answer came from an in-app
/// banner, so its follow-up status is shown in-app as well.
Future<void> handleFamilyChatNotificationResponse(
  NotificationResponse response, {
  AndroidFamilyChatPresenter? presenter,
}) async {
  final payload = familyChatNotificationPayload(response.payload);
  if (payload == null) return;
  if (response.actionId == null ||
      response.actionId!.isEmpty ||
      response.actionId == 'family_chat_open_request') {
    await _queueConversationOpen(
      payload,
      reviewAaps:
          payload[FamilyChatNotificationEvent.reviewAapsPayloadKey] == true,
    );
    return;
  }
  await _withWorker(presenter: presenter, (worker, db, presenter) async {
    if (FirebaseAuth.instance.currentUser?.uid != payload['uid']) return;
    if (response.actionId == 'family_chat_consume') {
      DatabaseImpl? medical;
      ProviderContainer? container;
      ProviderSubscription<ConfirmFamilyTreatment>? subscription;
      ConfirmFamilyTreatment executor(Map<String, dynamic> guard) {
        if (subscription == null) {
          medical = DatabaseImpl();
          container = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(medical!)],
          );
          final provider = Provider(
            (ref) => createFamilyTreatmentExecutor(
              ref,
              chatDb: db,
              api: worker.api,
              currentUid: worker.currentUid,
              expectedGuard: guard,
              observedAuthorization: () =>
                  parseFamilyTreatmentAuthorization(payload['authorization']),
            ),
          );
          subscription = container!.listen(provider, (_, _) {});
        }
        return subscription!.read();
      }

      try {
        await handleFamilyChatConsumption(
          db: db,
          api: worker.api,
          payload: payload,
          currentUid: worker.currentUid,
          confirm: (id, guard) => executor(guard).confirm(id),
          lookup: (id, guard) => executor(guard).lookup(id),
          show: (notice, state, mealId) async {
            double? manualCarbs;
            String? deliveryStatus;
            try {
              if (mealId != null && container != null) {
                final providers = container!;
                final upload = await providers
                    .read(lowTreatmentUploadRepositoryProvider)
                    .find(mealId);
                if (upload != null) {
                  final settings = await providers.read(
                    nightscoutLowTreatmentSettingsLoaderProvider,
                  )();
                  deliveryStatus =
                      switch (const ResolveLowTreatmentUploadStatusUseCase()(
                        state: upload.state,
                        sourceKey: upload.sourceKey,
                        settings: settings,
                      )) {
                        LowTreatmentUploadDisplayStatus.queued =>
                          lang.lowTreatmentUploadQueued,
                        LowTreatmentUploadDisplayStatus.verifying =>
                          lang.lowTreatmentUploadVerifying,
                        LowTreatmentUploadDisplayStatus.sent =>
                          lang.lowTreatmentUploadSent,
                        LowTreatmentUploadDisplayStatus.cancelled =>
                          lang.lowTreatmentUploadCancelled,
                        LowTreatmentUploadDisplayStatus.paused =>
                          lang.lowTreatmentUploadPaused,
                      };
                } else {
                  final pending = await providers
                      .read(familyTreatmentAapsHandoffProvider)
                      .pendingFor(mealId);
                  manualCarbs = pending?.expectedCarbs;
                }
              }
            } catch (error) {
              Log.w(
                'FamilyChatPush',
                'Could not load treatment delivery details (${error.runtimeType})',
              );
            }
            await presenter.consumptionStatus(
              notice,
              payload,
              state,
              manualCarbs: manualCarbs,
              deliveryStatus: deliveryStatus,
            );
          },
          cancel: presenter.cancel,
        );
      } finally {
        subscription?.close();
        container?.dispose();
        await medical?.close();
      }
    } else if (response.actionId == 'family_chat_treatment_unavailable') {
      await worker.reply(payload, 'Nie mam', treatmentUnavailable: true);
    } else if (response.actionId == 'family_chat_treatment_feels_well') {
      await worker.reply(
        payload,
        'Czuję się dobrze',
        treatmentUnavailable: true,
        onReplyQueued: snoozeAapsCarbsRequest,
      );
    } else if (response.actionId == 'family_chat_reply' &&
        response.input != null) {
      await worker.reply(payload, response.input!);
    } else if (response.actionId case final id?
        when id.startsWith(FamilyChatNotificationEvent.answerActionPrefix)) {
      final index = int.tryParse(
        id.substring(FamilyChatNotificationEvent.answerActionPrefix.length),
      );
      if (index != null) await worker.reply(payload, '', answerIndex: index);
    }
  });
}
