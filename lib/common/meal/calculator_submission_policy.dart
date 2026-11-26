import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../treatments/calculator_submission.dart';

/// A calculator entry with a positive recommendation advances a meal
/// independently of the insulin record: AAPS decides the dose, and a recorded,
/// missing, ambiguous or cancelled delivery only informs the meal card.
class CalculatorSubmissionPolicy {
  const CalculatorSubmissionPolicy();

  bool acceptsCalculatorEntry(CalculatorSubmission submission) =>
      submission.isValid &&
      submission.recommendedInsulin.isFinite &&
      submission.recommendedInsulin > 0;
}

final calculatorSubmissionPolicyProvider = Provider<CalculatorSubmissionPolicy>(
  (_) => const CalculatorSubmissionPolicy(),
);
