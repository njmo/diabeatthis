import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/ingredient_provider.dart';
import '../../domain/utils/ingredient_barcode_validator.dart';
import '../services/ingredient_barcode_scanner.dart';

const int _ingredientBarcodeMaxLength = 14;
const _ingredientBarcodeValidator = IngredientBarcodeValidator();

class IngredientBarcodeFormField extends ConsumerStatefulWidget {
  const IngredientBarcodeFormField({super.key});

  @override
  ConsumerState<IngredientBarcodeFormField> createState() =>
      IngredientBarcodeFormFieldState();
}

class IngredientBarcodeFormFieldState
    extends ConsumerState<IngredientBarcodeFormField> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: ref.read(ingredientDraftProvider).barcode ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final draft = ref.read(ingredientDraftProvider.notifier);
    final barcode = ref.watch(ingredientDraftProvider).barcode;
    final barcodeScanner = ref.read(ingredientBarcodeScannerProvider);
    ref.listen(
      ingredientDraftProvider.select((draft) => draft.barcode),
      (_, barcode) => setBarcodeText(barcode ?? ''),
    );

    return TextFormField(
      controller: controller,
      maxLength: _ingredientBarcodeMaxLength,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: draft.setBarcode,
      validator: _validateOptionalBarcode,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.qr_code_2_outlined),
        suffixIcon: IconButton(
          tooltip: lang.ingredientScanBarcodeTooltip,
          onPressed: () async {
            final scannedBarcode = await barcodeScanner.scan(context);
            if (scannedBarcode == null) {
              return;
            }
            if (!context.mounted) {
              return;
            }
            setBarcodeText(scannedBarcode);
            draft.setBarcode(scannedBarcode);
          },
          icon: const Icon(Icons.qr_code_scanner_outlined),
        ),
        labelText: lang.ingredientBarcodeFieldLabel,
        helperText: _barcodeHelperText(barcode),
        border: const OutlineInputBorder(),
      ),
    );
  }

  void setBarcodeText(String barcode) {
    if (controller.text == barcode) {
      return;
    }

    controller.text = barcode;
    controller.selection = TextSelection.collapsed(offset: barcode.length);
  }
}

String? _validateOptionalBarcode(String? value) {
  final barcode = value?.trim() ?? '';
  if (barcode.isEmpty) {
    return null;
  }
  if (_ingredientBarcodeValidator.normalizeValidBarcode(barcode) == null) {
    return lang.ingredientBarcodeInvalid;
  }
  return null;
}

String? _barcodeHelperText(String? barcode) {
  final normalized = barcode?.trim();
  if (normalized == null || normalized.isEmpty) {
    return lang.ingredientBarcodeManualOrScan;
  }
  return lang.ingredientBarcodeSaved(normalized);
}
