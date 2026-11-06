import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';

/// A simulated scanner never opens the camera or requests camera permission.
class SetupPairingCodePreview extends StatelessWidget {
  const SetupPairingCodePreview({
    super.key,
    required this.scanning,
    required this.code,
  });

  final bool scanning;
  final String code;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        scanning ? Icons.qr_code_scanner : Icons.qr_code_2,
        size: 120,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 8),
      if (!scanning)
        Text(
          code,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      Text(
        scanning ? context.lang.setupScanChildDemo : context.lang.setupQrDemo,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
