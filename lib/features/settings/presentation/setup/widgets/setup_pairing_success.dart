import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';

class SetupPairingSuccess extends StatelessWidget {
  const SetupPairingSuccess({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 120,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          context.lang.setupPaired,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
