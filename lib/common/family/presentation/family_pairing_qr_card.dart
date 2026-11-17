import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/language.dart';

/// Keeps a light quiet zone and dark modules so themed codes remain scannable.
class FamilyPairingQrCard extends StatelessWidget {
  const FamilyPairingQrCard({super.key, required this.code, this.shortCode});
  final String code;
  final String? shortCode;
  static const codeSize = 168.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paper = Color.lerp(Colors.white, colors.primary, .12)!;
    final ink = Color.lerp(const Color(0xFF071B24), colors.primary, .25)!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: QrImageView(
              data: code,
              size: codeSize,
              padding: const EdgeInsets.all(12),
              backgroundColor: paper,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: ink,
              ),
              semanticsLabel: context.lang.setupPairingCodeTitle,
            ),
          ),
          if (shortCode != null) ...[
            const SizedBox(height: 12),
            Text(
              shortCode!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(context.lang.familyCopyCode),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shortCode!));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.lang.familyCodeCopied)),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.lang.familyQrExpiration,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
