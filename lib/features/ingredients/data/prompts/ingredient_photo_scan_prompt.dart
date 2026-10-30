const ingredientPhotoScanPrompt = '''
You extract nutrition data from two product photos:
1. front package photo with product name and brand,
2. nutrition label photo with macronutrients.

Return only one JSON object. Do not wrap it in Markdown. Do not add comments.
Use English JSON keys exactly as described below.

Return "recognized" only when the product name and all macronutrients per 100g
are readable. Brand and portions are optional.

If the front photo is unreadable, the nutrition label is unreadable, or the
photos do not show a food product, return "needsRetake".

If you can read some values but not all required fields, still return
"recognized" with the fields you can read. The app will ask the user whether
to continue with a draft or retry the photos.

Recognized schema:
{
  "status": "recognized",
  "name": "Product name",
  "brand": "Brand name or null",
  "barcode": "Visible EAN/UPC/GTIN barcode digits or null",
  "nutritionPer100g": {
    "carbs": 62.3,
    "fat": 20.1,
    "protein": 6.4,
    "fiber": 3.2
  },
  "portions": [
    {
      "name": "2 cookies",
      "unitHint": "cookies",
      "grams": 25,
      "source": "nutrition_label"
    }
  ]
}

Retake schema:
{
  "status": "needsRetake",
  "photo": "front | nutritionLabel | both",
  "reason": "blurry_or_incomplete | not_food_product | missing_nutrition_label",
  "message": "Short user-facing explanation in Polish."
}

Rules:
- Use numbers for grams when possible. Strings like "12,5 g" are allowed only
  when the image clearly shows a unit and parsing as a number is uncertain.
- Use null for optional unknown fields.
- Do not infer missing macronutrients from kcal.
- Do not translate product or brand names.
- Return product and brand names in lowercase.
- If a barcode is clearly visible, copy only its digits into barcode.
- Use null for barcode when the digits are incomplete, blurry, or uncertain.
- For nutritionPer100g, use values per 100 g only.
- Put package serving sizes in portions only when explicitly visible.
''';
