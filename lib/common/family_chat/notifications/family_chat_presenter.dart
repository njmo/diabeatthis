import '../../../core/notifications/base/notifications_controller.dart';
import '../../../core/notifications/domain/events/family_chat_notification.dart';
import '../../l10n/language.dart';
import '../application/family_chat_background.dart';
import '../application/family_chat_consumption_action.dart';
import '../data/family_chat_database.dart';
import '../presentation/family_treatment_text.dart';

class AndroidFamilyChatPresenter implements FamilyChatPushPresenter {
  AndroidFamilyChatPresenter({
    required this.controller,
    required this._prepare,
  });

  /// Shared delivery: an in-app banner while the app is on screen, otherwise
  /// a system notification, mirrored into the notification inbox either way.
  final NotificationsController controller;

  /// Sets up language and channels without replaying an app-launch action.
  final Future<void> Function() _prepare;

  static FamilyChatNotificationEvent messageEvent(FamilyChatPushView view) {
    final uid = view.guard['uid'] as String;
    final members = view.config['members'] as List;
    final own = members.where((member) => member['uid'] == uid).first as Map;
    final sender = view.message['senderUid'] as String;
    final name =
        view.message['names']?[sender] as String? ??
        lang.familyChatRecipientFamily;
    final treatment = view.message['kind'] == 'lowTreatment';
    final treatmentConfirmed =
        own['role'] == 'managingCaregiver' &&
        view.message['kind'] == 'treatmentResult' &&
        view.message['replyTo'] is String;
    final actionable =
        own['role'] == 'child' &&
        treatment &&
        (view.remainingLifetime ?? 0) > 0 &&
        view.message['treatmentResult'] == null &&
        (view.message['treatment']?['validUntil'] as int? ?? 0) >
            (view.config['serverTime'] as int);
    final answers = own['role'] == 'child' && !treatment
        ? List<String>.from(view.message['answers'] as List? ?? [])
        : <String>[];
    return FamilyChatNotificationEvent(
      id: view.notice.id,
      tag: view.notice.tag,
      title: treatmentConfirmed
          ? lang.familyChatChildTreatmentConfirmed(name)
          : lang.familyChatTitle,
      body: treatmentConfirmed
          ? ''
          : (treatment
                    ? familyTreatmentSnapshotText(
                        view.message['treatment'],
                        lang,
                        compact: true,
                      )
                    : null) ??
                view.message['text'] as String,
      payload: view.payload,
      timeoutAfter: view.remainingLifetime?.clamp(1, 2147483647),
      message: (
        recipientId: uid,
        recipientName:
            own['displayName'] as String? ?? lang.familyChatRecipientSelf,
        senderId: sender,
        senderName: name,
        conversationTitle: view.target == 'family'
            ? lang.familyChatRecipientFamily
            : name,
        groupConversation: view.target == 'family',
        sentAt: DateTime.fromMillisecondsSinceEpoch(
          view.message['sentAt'] as int,
        ),
      ),
      replyChoices: answers,
      allowConsumption: actionable,
      lowTreatment: treatment,
      openRequest: treatmentConfirmed,
    );
  }

  @override
  Future<void> show(FamilyChatPushView view) async {
    await _prepare();
    if (view.remainingLifetime == 0) {
      await cancel(view.notice);
      return;
    }
    await _show(messageEvent(view));
    if (view.remainingLifetime == 0) await cancel(view.notice);
  }

  @override
  Future<void> cancel(FamilyChatNotice notice) =>
      controller.cancel(notice.id, tag: notice.tag);

  static FamilyChatNotificationEvent replyCompletedEvent(
    FamilyChatNotice notice,
    FamilyChatPushView view,
  ) => FamilyChatNotificationEvent(
    id: notice.id,
    tag: notice.tag,
    title: lang.familyChatReplySent,
    body: '',
    payload: view.payload,
    silent: true,
    timeoutAfter: familyChatReplyAcknowledgmentTimeoutMs,
    transient: true,
  );

  @override
  Future<void> replyCompleted(
    FamilyChatNotice notice,
    FamilyChatPushView view,
  ) async {
    await _prepare();
    await _show(replyCompletedEvent(notice, view));
  }

  static FamilyChatNotificationEvent consumptionEvent(
    FamilyChatNotice notice,
    Map<String, dynamic> payload,
    FamilyConsumptionNotice state,
  ) {
    final completed =
        state == FamilyConsumptionNotice.recorded ||
        state == FamilyConsumptionNotice.completedElsewhere;
    final title = switch (state) {
      FamilyConsumptionNotice.recorded ||
      FamilyConsumptionNotice.recordedAwaitingAck =>
        lang.familyChatTreatmentRecorded,
      FamilyConsumptionNotice.completedElsewhere =>
        lang.familyChatTreatmentAlreadyConfirmed,
      FamilyConsumptionNotice.anotherDevice =>
        lang.familyChatTreatmentOtherDeviceTitle,
      _ => lang.familyChatTreatmentNotRecorded,
    };
    final body = switch (state) {
      FamilyConsumptionNotice.recorded => '',
      FamilyConsumptionNotice.recordedAwaitingAck =>
        lang.familyChatNotificationAwaitingAckBody,
      FamilyConsumptionNotice.completedElsewhere =>
        lang.familyChatNotificationCompletedElsewhereBody,
      FamilyConsumptionNotice.pending =>
        lang.familyChatNotificationConsumptionPendingBody,
      FamilyConsumptionNotice.anotherDevice =>
        lang.familyChatNotificationOtherDeviceBody,
      FamilyConsumptionNotice.unavailable =>
        lang.familyChatNotificationUnavailableBody,
    };
    return FamilyChatNotificationEvent(
      id: notice.id,
      tag: notice.tag,
      title: title,
      body: body,
      payload: payload,
      silent: true,
      timeoutAfter: completed
          ? 5000
          : state == FamilyConsumptionNotice.pending
          ? 30000
          : 86400000,
      transient: completed,
    );
  }

  Future<void> consumptionStatus(
    FamilyChatNotice notice,
    Map<String, dynamic> payload,
    FamilyConsumptionNotice state,
  ) async {
    await _prepare();
    await _show(consumptionEvent(notice, payload, state));
  }

  @override
  Future<void> pending(
    FamilyChatPushView view, {
    required bool needsTicket,
  }) async {
    await _prepare();
    await _show(
      FamilyChatNotificationEvent(
        id: view.notice.id,
        tag: view.notice.tag,
        title: needsTicket
            ? lang.familyChatNotificationReplyNotSent
            : lang.familyChatNotificationReplyPending,
        body: needsTicket
            ? lang.familyChatNotificationReplyCheckBody
            : lang.familyChatNotificationReplyQueuedBody,
        payload: view.payload,
      ),
    );
  }

  Future<void> _show(FamilyChatNotificationEvent event) =>
      controller.show(event);
}
