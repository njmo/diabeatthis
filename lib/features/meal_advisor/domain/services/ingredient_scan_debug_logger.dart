import '../../../../core/logger/logger.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';

class IngredientScanDebugLogger with Logging {
  const IngredientScanDebugLogger();

  void logRawResponse(String response) {
    logD('Raw ingredient scan response: $response');
  }

  void logRecognizedPortions(List<RecognizedPortion> portions) {
    if (portions.isEmpty) {
      logD('No ingredient portions recognized.');
      return;
    }

    final formattedPortions = portions.map(_formatPortion).join('; ');
    logD('Recognized ingredient portions: $formattedPortions');
  }

  String _formatPortion(RecognizedPortion portion) {
    final name = portion.name ?? 'unknown';
    final grams = portion.grams?.toString() ?? 'unknown';
    final unitHint = portion.unitHint ?? 'unknown';
    final source = portion.source ?? 'unknown';
    return 'name=$name, grams=$grams, unitHint=$unitHint, source=$source';
  }
}
