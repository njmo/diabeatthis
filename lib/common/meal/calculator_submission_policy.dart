import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../treatments/calculator_submission.dart';

/// A calculator entry can advance a main meal independently of the insulin
/// record. Both AAPS and Nightscout can report that record before delivery ends.
class CalculatorSubmissionPolicy {
  const CalculatorSubmissionPolicy();

  bool acceptsCalculatorEntry(CalculatorSubmission submission) =>
      submission.isValid &&
      !submission.hasUnresolvedDelivery &&
      !submission.wizard.hasUnresolvedDelivery &&
      submission.recommendedInsulin.isFinite &&
      submission.recommendedInsulin > 0;
}

final calculatorSubmissionPolicyProvider = Provider<CalculatorSubmissionPolicy>(
  (_) => const CalculatorSubmissionPolicy(),
);
