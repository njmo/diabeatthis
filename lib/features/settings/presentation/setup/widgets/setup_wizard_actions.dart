import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/form_action_bar.dart';

class SetupWizardActions extends StatelessWidget {
  const SetupWizardActions({
    super.key,
    required this.onNext,
    required this.label,
    this.onPreviousFeature,
    this.onSkip,
    this.saving = false,
  });
  final VoidCallback? onNext;
  final VoidCallback? onPreviousFeature;
  final VoidCallback? onSkip;
  final String label;
  final bool saving;
  @override
  Widget build(BuildContext context) => FormActionBar(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSkip != null)
          TextButton(
            onPressed: saving ? null : onSkip,
            child: Text(context.lang.setupSkip),
          ),
        Row(
          children: [
            if (onPreviousFeature != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onPreviousFeature,
                  child: Text(
                    context.lang.setupPreviousFeature,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: saving ? null : onNext,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward, size: 19),
                label: Text(label, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
