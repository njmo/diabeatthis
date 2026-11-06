import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../setup/domain/setup_feature.dart';
import '../../widgets/scroll_to_widget_after_layout.dart';
import '../family_pairing_invitation.dart';
import '../family_pairing_member.dart';
import '../family_status.dart';
import '../secure_family_repository.dart';
import 'family_account_avatar.dart';
import 'family_pairing_qr_card.dart';
import 'family_pending_request_card.dart';
import 'family_qr_scanner_page.dart';

class SecureFamilyPanel extends StatefulWidget {
  const SecureFamilyPanel({
    super.key,
    required this.repository,
    required this.mode,
  });
  final SecureFamilyRepository repository;
  final SetupDeviceMode mode;
  @override
  State<SecureFamilyPanel> createState() => SecureFamilyPanelState();
}

class SecureFamilyPanelState extends State<SecureFamilyPanel> {
  late Stream<FamilyStatus> updates;
  FamilyPairingInvitation? invitation;
  static const layoutAnimationDuration = Duration(milliseconds: 240);
  final invitationAnchor = GlobalKey();
  final approvalAnchor = GlobalKey();
  String? revealedRequestId;
  int revealRevision = 0;
  Timer? revealTimer;
  VoidCallback? cancelReveal;
  Timer? expiry;
  Timer? successTimer;
  bool celebrating = false;
  bool invitationEnded = false;
  bool reducedMotion = false;
  bool busy = false;
  bool failed = false;
  bool requested = false;
  @override
  void initState() {
    super.initState();
    updates = widget.repository.watchStatus().map(observeStatus);
  }

  @override
  void dispose() {
    expiry?.cancel();
    revealRevision++;
    revealTimer?.cancel();
    cancelReveal?.call();
    successTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  FamilyStatus observeStatus(FamilyStatus value) {
    final invite = invitation;
    if (invite != null && !celebrating) {
      if (value.members.any((member) => member.invitationId == invite.id)) {
        expiry?.cancel();
        if (reducedMotion) {
          invitation = null;
        } else {
          celebrating = true;
          successTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                invitation = null;
                celebrating = false;
              });
            }
          });
        }
      } else if (value.activeInvitationId != null &&
          value.activeInvitationId != invite.id &&
          value.activeInvitationRevision > invite.revision) {
        expiry?.cancel();
        invitation = null;
        invitationEnded = true;
      } else if (value.activeInvitationId == invite.id &&
          {
            'rejected',
            'expired',
            'cancelled',
          }.contains(value.invitationState)) {
        expiry?.cancel();
        invitation = null;
        invitationEnded = true;
      }
    }
    final pendingId = value.pending?.id;
    if (pendingId != null && pendingId != revealedRequestId) {
      revealedRequestId = pendingId;
      revealAfterExpansion(approvalAnchor);
    }
    return value;
  }

  void revealAfterExpansion(GlobalKey anchor) {
    final revision = ++revealRevision;
    revealTimer?.cancel();
    cancelReveal?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != revealRevision) return;
      revealTimer = Timer(
        reducedMotion
            ? Duration.zero
            : layoutAnimationDuration + const Duration(milliseconds: 16),
        () {
          if (!mounted || revision != revealRevision) return;
          cancelReveal = scrollToWidgetAfterLayout(
            anchor,
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
          WidgetsBinding.instance.scheduleFrame();
        },
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() => run(() async {
    if (widget.mode == SetupDeviceMode.patient) {
      final next = await widget.repository.createInvitation(widget.mode);
      if (!mounted) return;
      expiry?.cancel();
      setState(() {
        invitation = next;
        invitationEnded = false;
      });
      revealAfterExpansion(invitationAnchor);
      expiry = Timer(const Duration(minutes: 5), () {
        if (mounted) {
          setState(() {
            invitation = null;
            invitationEnded = true;
          });
        }
      });
    } else {
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const FamilyQrScannerPage()),
      );
      if (code == null || !mounted) return;
      await widget.repository.requestJoin(code);
      if (mounted) setState(() => requested = true);
    }
  });
  Future<void> disconnect(String memberId) => run(() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          memberId == 'self'
              ? context.lang.familyLeaveTitle
              : context.lang.familyDisconnectTitle,
        ),
        content: Text(
          memberId == 'self'
              ? context.lang.familyLeaveExplanation
              : context.lang.familyDisconnectExplanation,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.lang.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.lang.familyDisconnect),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.repository.disconnect(memberId);
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<FamilyStatus>(
    stream: updates,
    builder: (context, snapshot) {
      // On an authorization/network error, no stale roster or action remains visible.
      final current = snapshot.hasError ? null : snapshot.data;
      final used =
          invitation != null &&
          (current?.members.any(
                (member) => member.invitationId == invitation!.id,
              ) ??
              false);
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.lang.familySecureExplanation),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: busy || celebrating ? null : add,
            icon: Icon(
              widget.mode == SetupDeviceMode.patient
                  ? Icons.person_add_alt
                  : Icons.qr_code_scanner,
            ),
            label: Text(
              widget.mode == SetupDeviceMode.patient
                  ? context.lang.setupAddCaregiver
                  : context.lang.setupScanChildTitle,
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (failed || snapshot.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.lang.familyOperationFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (invitation != null && !used && !celebrating)
            FamilyPairingQrCard(key: invitationAnchor, code: invitation!.code),
          if (used || celebrating)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(context.lang.familyConnected),
                ],
              ),
            ),
          if (invitationEnded) Text(context.lang.familyRequestEnded),
          if (current != null &&
              (requested || current.joinState != null) &&
              current.members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                current.joinState == null || current.joinState == 'pending'
                    ? context.lang.familyWaitingApproval
                    : context.lang.familyRequestEnded,
              ),
            ),
          if (current?.pending case final pending?)
            FamilyPendingRequestCard(
              key: approvalAnchor,
              request: pending,
              busy: busy,
              onDecide: (approve) => run(
                () => widget.repository.decide(pending.id, approve: approve),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            context.lang.setupLinkedAccounts,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final member in current?.members ?? const [])
            if (!celebrating || member.invitationId != invitation?.id)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: FamilyAccountAvatar(photoUrl: member.photoUrl),
                title: Text(member.displayName),
                trailing: member.canDisconnect
                    ? IconButton(
                        tooltip: member.role == FamilyMemberRole.child
                            ? context.lang.familyLeave
                            : context.lang.familyDisconnect,
                        onPressed: busy
                            ? null
                            : () => disconnect(
                                member.role == FamilyMemberRole.child
                                    ? 'self'
                                    : member.id,
                              ),
                        icon: const Icon(Icons.link_off),
                      )
                    : const Icon(Icons.lock_outline),
              ),
          if (current?.canLeave == true &&
              !current!.members.any(
                (member) => member.role == FamilyMemberRole.child,
              ))
            TextButton(
              onPressed: busy ? null : () => disconnect('self'),
              child: Text(context.lang.familyLeave),
            ),
        ],
      );
      return reducedMotion
          ? content
          : AnimatedSize(duration: layoutAnimationDuration, child: content);
    },
  );
}
