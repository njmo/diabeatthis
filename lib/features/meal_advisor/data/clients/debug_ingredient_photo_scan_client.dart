enum DebugIngredientPhotoScanScenario {
  recognized,
  needsRetake,
  incompleteRecognized,
}

class DebugIngredientPhotoScanClient {
  final DebugIngredientPhotoScanScenario scenario;
  final Duration delay;

  const DebugIngredientPhotoScanClient({
    this.scenario = DebugIngredientPhotoScanScenario.recognized,
    this.delay = const Duration(seconds: 2),
  });

  Future<String> scan() async {
    await Future<void>.delayed(delay);
    return switch (scenario) {
      DebugIngredientPhotoScanScenario.recognized =>
        debugIngredientPhotoScanResponse,
      DebugIngredientPhotoScanScenario.needsRetake =>
        debugIngredientPhotoScanRetakeResponse,
      DebugIngredientPhotoScanScenario.incompleteRecognized =>
        debugIngredientPhotoScanIncompleteResponse,
    };
  }
}

const debugIngredientPhotoScanResponse = '''
{
  "status": "recognized",
  "name": "Testowy produkt",
  "brand": "Przykładowy producent",
  "nutritionPer100g": {
    "carbs": 62.3,
    "fat": 20.1,
    "protein": 6.4,
    "fiber": 3.2
  },
  "portions": [
    {
      "name": "2 ciastka",
      "unitHint": "ciastka",
      "grams": 25,
      "source": "nutrition_label"
    }
  ]
}
''';

const debugIngredientPhotoScanRetakeResponse = '''
{
  "status": "needsRetake",
  "photo": "nutritionLabel",
  "reason": "blurry_or_incomplete",
  "message": "Tabela wartości odżywczych jest niewyraźna. Zrób zdjęcie jeszcze raz."
}
''';

const debugIngredientPhotoScanIncompleteResponse = '''
{
  "status": "recognized",
  "name": "Testowy produkt",
  "brand": null,
  "nutritionPer100g": {
    "carbs": 62.3,
    "fat": null,
    "protein": 6.4,
    "fiber": null
  },
  "portions": []
}
''';
