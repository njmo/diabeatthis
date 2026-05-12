class DebugIngredientPhotoScanClient {
  const DebugIngredientPhotoScanClient();

  Future<String> scan() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return debugIngredientPhotoScanResponse;
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
