import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../setup_wizard_controller.dart';

class SetupPairingInvitationCard extends StatelessWidget {
  const SetupPairingInvitationCard({super.key, required this.controller});
  final SetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.lang.setupPairingCodeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (state.generatingInvitation)
              const Center(child: CircularProgressIndicator())
            else if (state.pairingInvitation != null) ...[
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: state.generatingInvitation
                  ? null
                  : controller.generatePairingInvitation,
              icon: const Icon(Icons.refresh),
              label: Text(context.lang.setupGeneratePairingCode),
            ),
            if (state.pairingInvitation != null && !controller.invitationUsed)
              FilledButton.tonal(
                onPressed: state.generatingInvitation
                    ? null
                    : controller.simulatePairing,
                child: Text(context.lang.setupSimulatePair),
              ),
            if (controller.invitationUsed)
              Text(context.lang.setupPaired, textAlign: TextAlign.center),
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
  }
}
