import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_wizard_controller.dart';
import 'setup_pairing_code_preview.dart';
import 'setup_pairing_phase.dart';
import 'setup_pairing_success.dart';

class SetupPairingInvitationCard extends StatelessWidget {
  const SetupPairingInvitationCard({
    super.key,
    required this.controller,
    this.phase = SetupPairingPhase.invitation,
  });
  final SetupWizardController controller;
  final SetupPairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final scanning = state.mode == SetupDeviceMode.caregiver;
    final compact = phase == SetupPairingPhase.compact;
    final success = phase == SetupPairingPhase.success;
    final motionDisabled = MediaQuery.disableAnimationsOf(context);
    if (state.pairingInvitation == null &&
        !state.generatingInvitation &&
        !state.invitationFailed) {
      return const SizedBox.shrink();
    }
    final content = Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text(
              scanning
                  ? context.lang.setupScanChildTitle
                  : context.lang.setupPairingCodeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: motionDisabled
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: success
                  ? const SetupPairingSuccess(key: ValueKey('pairing-success'))
                  : state.generatingInvitation
                  ? const Center(
                      key: ValueKey('pairing-loading'),
                      child: CircularProgressIndicator(),
                    )
                  : state.pairingInvitation != null
                  ? SetupPairingCodePreview(
                      key: ValueKey(state.pairingInvitation!.id),
                      scanning: scanning,
                      code: state.pairingInvitation!.code,
                    )
                  : const SizedBox.shrink(),
            ),
            if (!success &&
                state.pairingInvitation != null &&
                !controller.invitationUsed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.tonal(
                  onPressed: state.generatingInvitation
                      ? null
                      : controller.simulatePairing,
                  child: Text(context.lang.setupSimulatePair),
                ),
              ),
          ],
          if (state.invitationFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.lang.setupFamilyDataFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
    if (motionDisabled) return content;
    return AnimatedSize(
      duration: SetupPairingTiming.collapse,
      alignment: Alignment.topCenter,
      curve: Curves.easeInOutCubic,
      child: content,
    );
  }
}
