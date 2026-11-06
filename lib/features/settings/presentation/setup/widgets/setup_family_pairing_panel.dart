import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../setup_wizard_controller.dart';
import 'setup_family_members_list.dart';
import 'setup_notice.dart';
import 'setup_pairing_invitation_card.dart';
import 'setup_pairing_phase.dart';

/// Presentation timing never delays the authoritative membership state.
class SetupFamilyPairingPanel extends StatefulWidget {
  const SetupFamilyPairingPanel({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  State<SetupFamilyPairingPanel> createState() =>
      SetupFamilyPairingPanelState();
}

class SetupFamilyPairingPanelState extends State<SetupFamilyPairingPanel> {
  Timer? holdTimer;
  Timer? revealTimer;
  String? pendingInvitation;
  final handledInvitations = <String>{};
  final visibleMembers = <String>{};
  final animatedMembers = <String>{};
  SetupPairingPhase phase = SetupPairingPhase.invitation;
  bool reducedMotion = false;

  @override
  void initState() {
    super.initState();
    restore();
    widget.controller.addListener(synchronize);
  }

  void cancelTimers() {
    holdTimer?.cancel();
    revealTimer?.cancel();
    holdTimer = null;
    revealTimer = null;
  }

  void restore() {
    visibleMembers.clear();
    animatedMembers.clear();
    handledInvitations.clear();
    visibleMembers.addAll(
      widget.controller.state.familyMembers.map((member) => member.id),
    );
    pendingInvitation = null;
    phase = widget.controller.invitationUsed
        ? SetupPairingPhase.compact
        : SetupPairingPhase.invitation;
    if (widget.controller.invitationUsed) {
      handledInvitations.add(widget.controller.state.pairingInvitation!.id);
    }
  }

  @override
  void didUpdateWidget(SetupFamilyPairingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(synchronize);
    cancelTimers();
    restore();
    widget.controller.addListener(synchronize);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && pendingInvitation != null) {
      cancelTimers();
      pendingInvitation = null;
      phase = SetupPairingPhase.compact;
      visibleMembers.addAll(
        widget.controller.state.familyMembers.map((member) => member.id),
      );
    }
  }

  void synchronize() {
    if (!mounted) return;
    final controller = widget.controller;
    final state = controller.state;
    final currentIds = state.familyMembers.map((member) => member.id).toSet();
    visibleMembers.retainAll(currentIds);
    animatedMembers.retainAll(currentIds);
    final invitation = state.pairingInvitation;
    if (!controller.invitationUsed ||
        state.generatingInvitation ||
        invitation == null) {
      cancelTimers();
      pendingInvitation = null;
      phase = SetupPairingPhase.invitation;
      visibleMembers.addAll(currentIds);
    } else if (!handledInvitations.contains(invitation.id)) {
      cancelTimers();
      handledInvitations.add(invitation.id);
      if (reducedMotion) {
        phase = SetupPairingPhase.compact;
        visibleMembers.addAll(currentIds);
      } else {
        phase = SetupPairingPhase.success;
        pendingInvitation = invitation.id;
        holdTimer = Timer(SetupPairingTiming.successHold, () {
          if (!mounted || pendingInvitation != invitation.id) return;
          setState(() => phase = SetupPairingPhase.compact);
          revealTimer = Timer(SetupPairingTiming.collapse, () {
            if (!mounted || pendingInvitation != invitation.id) return;
            setState(() {
              final ids = widget.controller.state.familyMembers
                  .map((member) => member.id)
                  .toSet();
              animatedMembers.addAll(ids.difference(visibleMembers));
              visibleMembers.addAll(ids);
              pendingInvitation = null;
            });
          });
        });
      }
    } else if (pendingInvitation == null) {
      phase = SetupPairingPhase.compact;
      visibleMembers.addAll(currentIds);
    } else {
      visibleMembers.addAll(
        state.familyMembers
            .where((member) => member.invitationId != pendingInvitation)
            .map((member) => member.id),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    cancelTimers();
    widget.controller.removeListener(synchronize);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.controller.state.familyMembers
        .where((member) => visibleMembers.contains(member.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupPairingInvitationCard(controller: widget.controller, phase: phase),
        if (widget.controller.state.familyMembersFailed) ...[
          const SizedBox(height: 16),
          SetupNotice(
            text: context.lang.setupFamilyMembersFailed,
            icon: Icons.sync_problem,
          ),
          TextButton(
            onPressed: widget.controller.refreshFamilyMembers,
            child: Text(context.lang.setupRefreshFamilyMembers),
          ),
        ],
        if (members.isNotEmpty) ...[
          const SizedBox(height: 16),
          SetupFamilyMembersList(
            members: members,
            animatedMemberIds: animatedMembers,
          ),
        ],
      ],
    );
  }
}
