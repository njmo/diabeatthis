import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/ingredient_barcode_scanner_sheet.dart';

final ingredientBarcodeScannerProvider = Provider<IngredientBarcodeScanner>(
  (ref) => const IngredientBarcodeScanner(),
);

class IngredientBarcodeScanner {
  const IngredientBarcodeScanner();

  Future<String?> scan(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => const IngredientBarcodeScannerSheet(),
    );
  }
}
