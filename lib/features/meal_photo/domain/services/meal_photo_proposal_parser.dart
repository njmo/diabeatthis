import 'dart:convert';

import '../../../../common/nutrition/confidence_level.dart';
import '../../../../core/domain/model/carbs_label_mode.dart';
import '../models/meal_photo_candidate.dart';
import '../models/meal_photo_clarification_required.dart';
import '../models/meal_photo_item.dart';
import '../models/meal_photo_nutrition.dart';
import '../models/meal_photo_proposal.dart';

class MealPhotoProposalParser {
  const MealPhotoProposalParser();
  MealPhotoProposal parse(
    String raw, {
    Map<String, List<MealPhotoCandidate>> candidates = const {},
    Set<String>? expectedIds,
  }) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value['schema_version'] != 1) {
      throw const FormatException('Unsupported meal photo schema');
    }
    if (value['status'] == 'needs_clarification') {
      throwClarification(value, raw);
    }
    if ((value.containsKey('status') && value['status'] != 'proposal') ||
        value.containsKey('questions') ||
        value.containsKey('reason')) {
      throw const FormatException('Invalid meal photo response status');
    }
    final rows = value['itemized'];
    if (rows is! List || rows.isEmpty || rows.length > 30) {
      throw const FormatException('Invalid component count');
    }
    final items = rows
        .map((row) => item(row, candidates, whole: false))
        .toList();
    final ids = items.map((item) => item.id).toSet();
    if (ids.length != items.length ||
        (expectedIds != null &&
            (ids.length != expectedIds.length ||
                !ids.containsAll(expectedIds)))) {
      throw const FormatException('Component identities changed');
    }
    final reference = item(value['reference'], candidates, whole: true);
    if (ids.contains(reference.id)) {
      throw const FormatException('Reference identity duplicates a component');
    }
    return MealPhotoProposal(
      name: text(value['name']),
      itemized: items,
      reference: reference,
      rawResponse: raw,
    );
  }

  Never throwClarification(Map<String, dynamic> value, String raw) {
    const allowed = {'schema_version', 'status', 'reason', 'questions'};
    if (value.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException(
        'Clarification cannot include meal or nutrition proposals',
      );
    }
    final reason = switch (value['reason']) {
      'ambiguous_menu_item' => MealPhotoClarificationReason.ambiguousMenuItem,
      'unreadable_menu' => MealPhotoClarificationReason.unreadableMenu,
      'missing_menu' => MealPhotoClarificationReason.missingMenu,
      'conflicting_evidence' =>
        MealPhotoClarificationReason.conflictingEvidence,
      _ => throw const FormatException('Unsupported clarification reason'),
    };
    final questions = value['questions'];
    if (questions is! List ||
        questions.isEmpty ||
        questions.length > 3 ||
        questions.any(
          (question) =>
              question is! String ||
              question.trim().isEmpty ||
              question.length > 500,
        )) {
      throw const FormatException(
        'Clarification requires one to three bounded questions',
      );
    }
    throw MealPhotoClarificationRequired(
      reason: reason,
      questions: questions
          .cast<String>()
          .map((question) => question.trim())
          .toList(),
      rawResponse: raw,
    );
  }

  MealPhotoItem item(
    dynamic raw,
    Map<String, List<MealPhotoCandidate>> candidates, {
    required bool whole,
  }) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid component');
    }
    final id = text(raw['id']);
    final kind = switch (raw['kind']) {
      'matched' => MealPhotoItemKind.matched,
      'needs_assignment' => MealPhotoItemKind.needsAssignment,
      'proposed_reference' => MealPhotoItemKind.proposedReference,
      _ => throw const FormatException('Unknown assignment state'),
    };
    final key = raw['candidate_key'];
    MealPhotoCandidate? candidate;
    if (key != null) {
      final matching = (candidates[id] ?? const <MealPhotoCandidate>[])
          .where((candidate) => candidate.key == key)
          .toList();
      if (matching.length != 1 || kind != MealPhotoItemKind.matched) {
        throw const FormatException('Unknown candidate identity');
      }
      candidate = matching.single;
    }
    if (kind == MealPhotoItemKind.matched && candidate == null) {
      throw const FormatException(
        'Matched product requires a supplied identity',
      );
    }
    final nutrition = raw['reference_nutrition'] == null
        ? null
        : nutritionFromJson(raw['reference_nutrition']);
    if ((kind == MealPhotoItemKind.proposedReference) != (nutrition != null) ||
        (whole && kind != MealPhotoItemKind.proposedReference)) {
      throw const FormatException('Reference requires whole-portion nutrition');
    }
    final weight = raw['estimated_weight_grams'];
    if (weight != null &&
        (weight is! num ||
            !weight.toDouble().isFinite ||
            weight <= 0 ||
            weight > 20000)) {
      throw const FormatException('Invalid physical weight');
    }
    return MealPhotoItem(
      id: id,
      name: text(raw['name']),
      searchQuery: text(raw['search_query']),
      usdaFoodName: raw['usda_food_name'] == null
          ? null
          : text(raw['usda_food_name']),
      kind: kind,
      recognitionConfidence: confidence(raw['recognition_confidence']),
      quantityConfidence: confidence(raw['quantity_confidence']).clamp(0, .5),
      nutritionConfidence: candidate == null
          ? confidence(raw['nutrition_confidence'])
          : candidate.effectiveNutritionConfidence,
      estimatedWeightGrams: (weight as num?)?.toDouble(),
      candidate: candidate,
      referenceNutrition: nutrition,
      referenceScope: whole
          ? MealPhotoReferenceScope.wholeMeal
          : MealPhotoReferenceScope.component,
      reason: raw['reason'] is String ? raw['reason'] as String : '',
    );
  }

  MealPhotoNutrition nutritionFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid nutrition');
    }
    double number(String key) {
      final value = raw[key];
      if (value is! num) throw const FormatException('Missing nutrition');
      return value.toDouble();
    }

    final mode = switch (raw['carbs_label_mode']) {
      'eu' => CarbsLabelMode.eu,
      'non_eu' => CarbsLabelMode.nonEu,
      _ => throw const FormatException('Missing carbohydrate convention'),
    };
    final result = MealPhotoNutrition(
      carbs: number('carbs'),
      fiber: number('fiber'),
      fat: number('fat'),
      protein: number('protein'),
      carbsLabelMode: mode,
    );
    result.validate();
    return result;
  }

  String text(dynamic value) {
    if (value is! String || value.trim().isEmpty || value.length > 500) {
      throw const FormatException('Missing or oversized text');
    }
    return value.trim();
  }

  double confidence(dynamic value) {
    if (value is String) {
      final level = switch (value) {
        'low' => ConfidenceLevel.low,
        'medium' => ConfidenceLevel.medium,
        'high' => ConfidenceLevel.high,
        'certain' => ConfidenceLevel.certain,
        _ => throw const FormatException('Invalid confidence level'),
      };
      return level.toDouble01();
    }
    if (value is! num || !value.toDouble().isFinite || value < 0 || value > 1) {
      throw const FormatException('Invalid confidence');
    }
    return value.toDouble();
  }
}
