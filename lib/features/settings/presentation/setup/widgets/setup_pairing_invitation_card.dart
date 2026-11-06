import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_wizard_controller.dart';
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
    final compact = phase == SetupPairingPhase.compact;
    final success = phase == SetupPairingPhase.success;
    final motionDisabled = MediaQuery.disableAnimationsOf(context);
    final addLabel = state.mode == SetupDeviceMode.patient
        ? context.lang.setupAddCaregiver
        : context.lang.setupAddChild;
    final content = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              FilledButton.icon(
                onPressed: controller.generatePairingInvitation,
                icon: const Icon(Icons.person_add_alt),
                label: Text(addLabel),
              )
            else ...[
              Text(
                context.lang.setupPairingCodeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: motionDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: success
                    ? const SetupPairingSuccess(
                        key: ValueKey('pairing-success'),
                      )
                    : state.generatingInvitation
                    ? const Center(
                        key: ValueKey('pairing-loading'),
                        child: CircularProgressIndicator(),
                      )
                    : state.pairingInvitation != null
                    ? Column(
                        key: ValueKey(state.pairingInvitation!.id),
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 120,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.pairingInvitation!.code,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            context.lang.setupQrDemo,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              if (!success &&
                  !state.generatingInvitation &&
                  (state.pairingInvitation == null || state.invitationFailed))
                FilledButton.icon(
                  onPressed: controller.generatePairingInvitation,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(addLabel),
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
