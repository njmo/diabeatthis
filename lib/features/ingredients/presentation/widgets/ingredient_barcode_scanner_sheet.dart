import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/utils/ingredient_barcode_validator.dart';

final ingredientBarcodeValidatorProvider = Provider<IngredientBarcodeValidator>(
  (ref) => const IngredientBarcodeValidator(),
);

final ingredientBarcodeScannerControllerProvider =
    Provider.autoDispose<MobileScannerController>((ref) {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [
          BarcodeFormat.ean8,
          BarcodeFormat.ean13,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
        autoZoom: true,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final ingredientBarcodeScannerCloseStateProvider =
    Provider.autoDispose<IngredientBarcodeScannerCloseState>(
      (ref) => IngredientBarcodeScannerCloseState(),
    );

class IngredientBarcodeScannerCloseState {
  bool isClosing = false;
}

class IngredientBarcodeScannerSheet extends ConsumerWidget {
  const IngredientBarcodeScannerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final colors = Theme.of(context).colorScheme;
    final controller = ref.watch(ingredientBarcodeScannerControllerProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) => handleDetect(context, ref, capture),
            ),
            const IngredientBarcodeScanFrame(),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: lang.commonCloseTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.ingredientScanBarcodeTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    lang.ingredientScanBarcodeInstruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleDetect(
    BuildContext context,
    WidgetRef ref,
    BarcodeCapture capture,
  ) async {
    final closeState = ref.read(ingredientBarcodeScannerCloseStateProvider);
    if (closeState.isClosing) {
      return;
    }

    String? code;
    final validator = ref.read(ingredientBarcodeValidatorProvider);
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null) {
        continue;
      }

      final normalized = validator.normalizeValidBarcode(value);
      if (normalized != null) {
        code = normalized;
        break;
      }
    }
    if (code == null) {
      return;
    }

    closeState.isClosing = true;
    final controller = ref.read(ingredientBarcodeScannerControllerProvider);
    await controller.stop();
    if (context.mounted) {
      Navigator.of(context).pop(code);
    }
  }
}

class IngredientBarcodeScanFrame extends StatelessWidget {
  const IngredientBarcodeScanFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
