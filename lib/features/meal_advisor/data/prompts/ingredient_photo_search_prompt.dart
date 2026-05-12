const ingredientPhotoSearchPrompt = '''
You identify a food product from one front/package/plate photo.

Return only one JSON object. Do not wrap it in Markdown. Do not add comments.
Use English JSON keys exactly as described below.

Schema:
{
  "names": ["product name", "alternative generic name"],
  "brand": "brand name or null"
}

Rules:
- Return product and brand names in lowercase.
- Do not translate visible product or brand names.
- If the photo shows an unpackaged food, return generic Polish names that can
  help search a local food database, for example ["ziemniaki", "ziemniak"].
- If the photo shows packaged food, include the visible product name first and
  generic alternatives after it.
- Keep names short and searchable.
- Return at most 5 names.
- Use null for unknown brand.
''';
