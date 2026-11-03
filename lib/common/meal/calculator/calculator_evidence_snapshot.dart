import '../../../core/domain/model/extended_carb.dart';
import '../../../core/domain/model/treat.dart';
import '../../treatments/calculator_submission.dart';

/// A snapshot of normalized evidence consumed by the foreground state owner.
class CalculatorEvidenceSnapshot {
  const CalculatorEvidenceSnapshot(
    this.submissions,
    this.extendedCarb, {
    this.carbCorrection,
  });

  final List<CalculatorSubmission> submissions;
  final ExtendedCarb? extendedCarb;
  final Treat? carbCorrection;

  Map<String, dynamic> toJson() => {
    'submissions': [
      for (final submission in submissions)
        {
          'at': submission.key.millisecondsSinceEpoch,
          'carbs': submission.carbs,
          'valid': submission.isValid,
          'complete': submission.isComplete,
        },
    ],
    if (carbCorrection case final carb?)
      'extendedCarb': {
        'id': carb.externalId,
        'at': carb.createdAt.millisecondsSinceEpoch,
        'carbs': carb.carbs,
        'duration': 0,
        'valid': carb.isValid,
      },
    if (extendedCarb case final carb?)
      'extendedCarb': {
        'id': carb.externalId,
        'at': carb.createdAt.millisecondsSinceEpoch,
        'carbs': carb.carbs,
        'duration': carb.duration,
        'valid': carb.isValid,
      },
  };
}
