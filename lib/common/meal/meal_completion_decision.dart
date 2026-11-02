import 'dart:convert';

enum MealCarbsCorrectionChoice { withoutCorrection, correctionRequested }

/// A recorded app choice, not evidence of an AAPS entry or insulin delivery.
class MealCompletionDecision {
  const MealCompletionDecision({
    required this.choice,
    required this.recordedAt,
    required this.eatingEndedAt,
    required this.reportedCarbs,
    required this.consumedCarbs,
    required this.proposedCorrectionCarbs,
  });

  final MealCarbsCorrectionChoice choice;
  final DateTime recordedAt;
  final DateTime eatingEndedAt;
  final double reportedCarbs;
  final double consumedCarbs;
  final int proposedCorrectionCarbs;

  String encode() => jsonEncode({
    'version': 1,
    'choice': choice.name,
    'recordedAt': recordedAt.millisecondsSinceEpoch,
    'eatingEndedAt': eatingEndedAt.millisecondsSinceEpoch,
    'reportedCarbs': reportedCarbs,
    'consumedCarbs': consumedCarbs,
    'proposedCorrectionCarbs': proposedCorrectionCarbs,
  });

  /// Older or malformed optional metadata must not prevent meal analysis.
  static MealCompletionDecision? decode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic> || data['version'] != 1) return null;
      final choice = MealCarbsCorrectionChoice.values
          .where((value) => value.name == data['choice'])
          .firstOrNull;
      final recorded = data['recordedAt'];
      final ended = data['eatingEndedAt'];
      final reported = data['reportedCarbs'];
      final consumed = data['consumedCarbs'];
      final correction = data['proposedCorrectionCarbs'];
      if (choice == null ||
          recorded is! int ||
          ended is! int ||
          reported is! num ||
          !reported.isFinite ||
          reported < 0 ||
          consumed is! num ||
          !consumed.isFinite ||
          consumed < 0 ||
          correction is! int ||
          correction > 0) {
        return null;
      }
      return MealCompletionDecision(
        choice: choice,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(recorded),
        eatingEndedAt: DateTime.fromMillisecondsSinceEpoch(ended),
        reportedCarbs: reported.toDouble(),
        consumedCarbs: consumed.toDouble(),
        proposedCorrectionCarbs: correction,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
