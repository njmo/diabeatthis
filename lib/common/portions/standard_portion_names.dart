import '../l10n/language.dart';

const standardPiecePortionName = 'piece';
const standardPortionWeightUnit = 'g';
const piecePortionAliases = ['piece', 'sztuka'];
const genericPortionAliases = ['portion', 'porcja'];

String localizedPortionName(String name, AppLocalizations lang) {
  final normalized = name.trim().toLowerCase();
  if (piecePortionAliases.contains(normalized)) {
    return lang.commonPieceUnit(1);
  }
  if (genericPortionAliases.contains(normalized)) {
    return lang.commonPortionUnit(1);
  }
  return name;
}

/// Stored standard names remain searchable after changing the UI language.
List<String> portionSearchTerms(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const [''];
  final terms = <String>{normalized};
  for (final aliases in [piecePortionAliases, genericPortionAliases]) {
    if (aliases.any((name) => name.contains(normalized))) {
      terms.addAll(aliases);
    }
  }
  return terms.toList(growable: false);
}

bool namesMatchPortionSuggestion(String existingName, String suggestedName) {
  final existing = existingName.trim().toLowerCase();
  final suggested = suggestedName.trim().toLowerCase();
  if (existing == suggested) return true;
  return [
    piecePortionAliases,
    genericPortionAliases,
  ].any((aliases) => aliases.contains(existing) && aliases.contains(suggested));
}
