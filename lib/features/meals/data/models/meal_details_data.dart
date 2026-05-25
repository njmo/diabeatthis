import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart' as domain;

class MealDetailsData {
  final MealRecordData meal;
  final MealAdvisorDecisionData? advisorDecision;
  final List<MealIngredientDetailsData> ingredients;
  final MealSnapshotDetailsData? plannedSnapshot;
  final MealSnapshotDetailsData? consumedSnapshot;
  final List<MealStatusHistoryEntryData> statusHistory;
  final MealCopySourceData? copySource;
  final List<MealCopyUsageData> copyUsages;
  final List<MealLowTreatmentDetailsData> lowTreatments;

  const MealDetailsData({
    required this.meal,
    required this.advisorDecision,
    required this.ingredients,
    required this.plannedSnapshot,
    required this.consumedSnapshot,
    required this.statusHistory,
    this.copySource,
    this.copyUsages = const [],
    this.lowTreatments = const [],
  });

  MealDetailsData copyWith({
    MealRecordData? meal,
    MealAdvisorDecisionData? advisorDecision,
    List<MealIngredientDetailsData>? ingredients,
    MealSnapshotDetailsData? plannedSnapshot,
    MealSnapshotDetailsData? consumedSnapshot,
    List<MealStatusHistoryEntryData>? statusHistory,
    MealCopySourceData? copySource,
    List<MealCopyUsageData>? copyUsages,
    List<MealLowTreatmentDetailsData>? lowTreatments,
  }) {
    return MealDetailsData(
      meal: meal ?? this.meal,
      advisorDecision: advisorDecision ?? this.advisorDecision,
      ingredients: ingredients ?? this.ingredients,
      plannedSnapshot: plannedSnapshot ?? this.plannedSnapshot,
      consumedSnapshot: consumedSnapshot ?? this.consumedSnapshot,
      statusHistory: statusHistory ?? this.statusHistory,
      copySource: copySource ?? this.copySource,
      copyUsages: copyUsages ?? this.copyUsages,
      lowTreatments: lowTreatments ?? this.lowTreatments,
    );
  }

  bool get hasConsumedData => consumedSnapshot != null;

  bool get isCopied =>
      meal.basedOnMealId != null || meal.mealTemplateId != null;

  MealSnapshotDetailsData? get preferredSummarySnapshot {
    return consumedSnapshot ?? plannedSnapshot;
  }

  double get totalInsulinUnits {
    return advisorDecision?.recommendedInsulinUnits ?? 0;
  }

  bool get hasAddOn {
    return meal.hasAddOnStatus ||
        ingredients.any((ingredient) => ingredient.hasAddOnAmount);
  }

  double get addOnNetCarbsG {
    return ingredients.fold(0.0, (sum, ingredient) {
      return sum + ingredient.addOnNetCarbsContribution;
    });
  }

  bool get hasLowTreatments => lowTreatments.isNotEmpty;

  double get lowTreatmentNetCarbsG {
    return lowTreatments.fold(0.0, (sum, treatment) {
      return sum + treatment.totalNetCarbsG;
    });
  }

  List<MealStatusTimelineEntryData> get statusTimeline {
    final entries = statusHistory.map((history) {
      return MealStatusTimelineEntryData(
        status: history.status,
        timestamp: history.createdAt,
        isCurrent: false,
      );
    }).toList();

    final current = MealStatusTimelineEntryData(
      status: meal.status,
      timestamp: meal.currentStatusTimestamp,
      isCurrent: true,
    );
    final hasExactCurrent = entries.any(
      (entry) =>
          entry.status == current.status &&
          entry.timestamp == current.timestamp,
    );
    if (!hasExactCurrent) {
      entries.add(current);
    } else {
      final index = entries.lastIndexWhere(
        (entry) =>
            entry.status == current.status &&
            entry.timestamp == current.timestamp,
      );
      entries[index] = current;
    }

    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  List<MealStatusTransitionData> get statusTransitions {
    final entries = statusTimeline;
    if (entries.isEmpty) return const [];

    final transitions = <MealStatusTransitionData>[];
    MealStatusTimelineEntryData? previous;
    for (final entry in entries) {
      if (previous == null) {
        transitions.add(
          MealStatusTransitionData(
            fromStatus: null,
            toStatus: entry.status,
            timestamp: entry.timestamp,
            isCurrent: entry.isCurrent,
          ),
        );
      } else if (previous.status != entry.status || entry.isCurrent) {
        transitions.add(
          MealStatusTransitionData(
            fromStatus: previous.status,
            toStatus: entry.status,
            timestamp: entry.timestamp,
            isCurrent: entry.isCurrent,
          ),
        );
      }
      previous = entry;
    }
    return transitions;
  }
}

class MealLowTreatmentDetailsData {
  final MealRecordData meal;
  final LowTreatmentContext context;
  final List<MealIngredientDetailsData> ingredients;

  const MealLowTreatmentDetailsData({
    required this.meal,
    required this.context,
    required this.ingredients,
  });

  double get totalCarbsG {
    return ingredients.fold(0.0, (sum, ingredient) {
      return sum + ingredient.consumedCarbsContribution;
    });
  }

  double get totalNetCarbsG {
    return ingredients.fold(0.0, (sum, ingredient) {
      return sum + ingredient.consumedNetCarbsContribution;
    });
  }
}

class MealCopySourceData {
  final int id;
  final String name;

  const MealCopySourceData({required this.id, required this.name});
}

class MealCopyUsageData {
  final int id;
  final String name;
  final DateTime plannedAt;
  final String status;
  final String sourceType;

  const MealCopyUsageData({
    required this.id,
    required this.name,
    required this.plannedAt,
    required this.status,
    required this.sourceType,
  });
}

class MealRecordData {
  final int id;
  final String name;
  final String purpose;
  final String status;
  final DateTime plannedAt;
  final DateTime? summarizedAt;
  final int? mealTemplateId;
  final int? basedOnMealId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const MealRecordData({
    required this.id,
    required this.name,
    this.purpose = 'meal',
    required this.status,
    required this.plannedAt,
    required this.summarizedAt,
    required this.mealTemplateId,
    required this.basedOnMealId,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  DateTime get analysisTime => summarizedAt ?? plannedAt;

  DateTime get currentStatusTimestamp {
    if (summarizedAt != null &&
        (status == 'summarized' || status.startsWith('eaten'))) {
      return summarizedAt!;
    }
    return updatedAt;
  }

  bool get isEaten {
    return status == 'eaten' ||
        status == 'eaten-extra' ||
        status == 'eaten-bolused' ||
        status == 'summarized';
  }

  bool get hasAddOnStatus {
    return status == 'eating-extra' || status == 'eaten-extra';
  }

  bool get isLowTreatment {
    return purpose == 'lowTreatment';
  }

  domain.Meal toDomainTreatment() {
    return domain.Meal(
      id: id,
      name: name,
      plannedAt: plannedAt,
      eatenAt: summarizedAt,
      status: status,
      notes: notes,
      mealTemplateId: mealTemplateId,
    );
  }
}

class MealAdvisorDecisionData {
  final String result;
  final int initialWaitTime;
  final int finalWaitTime;
  final bool waitTimeIgnored;
  final int extendedCarbsGrams;
  final String? extendedCarbsDeliveryMode;
  final int? extendedCarbsDelayMinutes;
  final int? extendedCarbsDurationMinutes;
  final String? decisionReason;
  final int version;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealAdvisorDecisionData({
    required this.result,
    required this.initialWaitTime,
    required this.finalWaitTime,
    required this.waitTimeIgnored,
    required this.extendedCarbsGrams,
    required this.extendedCarbsDeliveryMode,
    required this.extendedCarbsDelayMinutes,
    required this.extendedCarbsDurationMinutes,
    required this.decisionReason,
    required this.version,
    required this.isSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  double? get recommendedInsulinUnits => null;
}

class MealIngredientDetailsData {
  final int mealIngredientId;
  final int ingredientId;
  final String ingredientName;
  final String entryType;
  final String portionLabel;
  final double plannedAmount;
  final double? consumedAmount;
  final double quantityConfidence;
  final double? consumedConfidence;
  final double plannedTotalGrams;
  final double consumedTotalGrams;
  final String? prepMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final IngredientNutritionData currentNutrition;
  final IngredientNutritionData plannedNutrition;
  final IngredientNutritionData consumedNutrition;
  final bool plannedNutritionDiffersFromCurrent;
  final bool consumedNutritionDiffersFromCurrent;
  final bool historicalNutritionUnavailable;

  const MealIngredientDetailsData({
    required this.mealIngredientId,
    required this.ingredientId,
    required this.ingredientName,
    required this.entryType,
    required this.portionLabel,
    required this.plannedAmount,
    required this.consumedAmount,
    required this.quantityConfidence,
    required this.consumedConfidence,
    required this.plannedTotalGrams,
    required this.consumedTotalGrams,
    required this.prepMethod,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.currentNutrition,
    required this.plannedNutrition,
    required this.consumedNutrition,
    required this.plannedNutritionDiffersFromCurrent,
    required this.consumedNutritionDiffersFromCurrent,
    required this.historicalNutritionUnavailable,
  });

  bool get isExtra => entryType == 'extra';

  bool get hasAddOnAmount {
    return isExtra || addOnNetCarbsContribution.abs() >= 0.5;
  }

  bool get usesHistoricalNutrition {
    return plannedNutritionDiffersFromCurrent ||
        consumedNutritionDiffersFromCurrent ||
        historicalNutritionUnavailable;
  }

  double get effectiveConsumedAmount {
    if (isExtra) {
      return consumedAmount ?? 0;
    }
    return consumedAmount ?? plannedAmount;
  }

  double get plannedCarbsContribution {
    return plannedTotalGrams * plannedNutrition.carbsPer100g / 100;
  }

  double get consumedCarbsContribution {
    return consumedTotalGrams * consumedNutrition.carbsPer100g / 100;
  }

  double get plannedNetCarbsContribution {
    return plannedTotalGrams * plannedNutrition.safeNetCarbsPer100g / 100;
  }

  double get consumedNetCarbsContribution {
    return consumedTotalGrams * consumedNutrition.safeNetCarbsPer100g / 100;
  }

  double get addOnNetCarbsContribution {
    if (isExtra) {
      return consumedNetCarbsContribution;
    }
    return consumedNetCarbsContribution - plannedNetCarbsContribution;
  }

  double get consumedFatContribution {
    return consumedTotalGrams * consumedNutrition.fatPer100g / 100;
  }

  double get consumedProteinContribution {
    return consumedTotalGrams * consumedNutrition.proteinPer100g / 100;
  }

  double get consumedCaloriesContribution {
    return consumedTotalGrams * consumedNutrition.kcalPer100g / 100;
  }

  double get consumedWbtKcalContribution {
    return consumedTotalGrams * consumedNutrition.wbtKcalPer100g / 100;
  }
}

class MealStatusTimelineEntryData {
  final String status;
  final DateTime timestamp;
  final bool isCurrent;

  const MealStatusTimelineEntryData({
    required this.status,
    required this.timestamp,
    required this.isCurrent,
  });
}

class MealStatusTransitionData {
  final String? fromStatus;
  final String toStatus;
  final DateTime timestamp;
  final bool isCurrent;

  const MealStatusTransitionData({
    required this.fromStatus,
    required this.toStatus,
    required this.timestamp,
    required this.isCurrent,
  });
}

class IngredientNutritionData {
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double proteinPer100g;
  final double nutritionConfidence;
  final DateTime? effectiveAt;

  const IngredientNutritionData({
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.proteinPer100g,
    required this.nutritionConfidence,
    required this.effectiveAt,
  });

  double get kcalPer100g {
    return proteinPer100g * 4 + carbsPer100g * 4 + fatPer100g * 9;
  }

  double get wbtKcalPer100g {
    return proteinPer100g * 4 + fatPer100g * 9;
  }

  double get safeNetCarbsPer100g {
    final netCarbs = carbsPer100g - fiberPer100g;
    return netCarbs < 0 ? 0 : netCarbs;
  }

  bool differsFrom(IngredientNutritionData other) {
    return carbsPer100g != other.carbsPer100g ||
        fatPer100g != other.fatPer100g ||
        fiberPer100g != other.fiberPer100g ||
        proteinPer100g != other.proteinPer100g ||
        nutritionConfidence != other.nutritionConfidence;
  }
}

class MealSnapshotDetailsData {
  final int id;
  final int mealId;
  final String snapshotType;
  final double totalGrams;
  final double totalCarbsG;
  final double totalFiberG;
  final double totalNetCarbsG;
  final double totalFatG;
  final double totalProteinG;
  final double totalCaloriesKcal;
  final int ingredientsCount;
  final double? avgQuantityConfidence;
  final double? minQuantityConfidence;
  final double? carbWeightedQuantityConfidence;
  final double? wbtWeightedQuantityConfidence;
  final double? carbWeightedNutritionConfidence;
  final double? wbtWeightedNutritionConfidence;
  final double? carbWeightedEffectiveConfidence;
  final double? wbtWeightedEffectiveConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const MealSnapshotDetailsData({
    required this.id,
    required this.mealId,
    required this.snapshotType,
    required this.totalGrams,
    required this.totalCarbsG,
    required this.totalFiberG,
    required this.totalNetCarbsG,
    required this.totalFatG,
    required this.totalProteinG,
    required this.totalCaloriesKcal,
    required this.ingredientsCount,
    required this.avgQuantityConfidence,
    required this.minQuantityConfidence,
    required this.carbWeightedQuantityConfidence,
    required this.wbtWeightedQuantityConfidence,
    required this.carbWeightedNutritionConfidence,
    required this.wbtWeightedNutritionConfidence,
    required this.carbWeightedEffectiveConfidence,
    required this.wbtWeightedEffectiveConfidence,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  double get wbtKcal {
    return totalProteinG * 4 + totalFatG * 9;
  }
}

class MealStatusHistoryEntryData {
  final int id;
  final int mealId;
  final String status;
  final DateTime createdAt;

  const MealStatusHistoryEntryData({
    required this.id,
    required this.mealId,
    required this.status,
    required this.createdAt,
  });
}
