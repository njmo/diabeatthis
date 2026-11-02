import 'dart:convert';

import 'wizard_carbohydrate_component.dart';

/// Durable submission evidence stored in the existing component metadata.
/// Ordinary carbohydrate JSON remains compatible with earlier records.
class WizardSubmissionEvidence {
  const WizardSubmissionEvidence({
    this.carbohydrates,
    this.hasUnresolvedDelivery = false,
  });

  final WizardCarbohydrateComponent? carbohydrates;
  final bool hasUnresolvedDelivery;

  factory WizardSubmissionEvidence.fromJson(String? encoded) {
    if (encoded == null) return const WizardSubmissionEvidence();
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return WizardSubmissionEvidence(
      carbohydrates: json['createdAt'] == null
          ? null
          : WizardCarbohydrateComponent.fromJson(encoded),
      hasUnresolvedDelivery: json['hasUnresolvedDelivery'] == true,
    );
  }

  String? toJson() {
    final component = carbohydrates;
    if (!hasUnresolvedDelivery) return component?.toJson();
    return jsonEncode({
      if (component != null)
        ...jsonDecode(component.toJson()) as Map<String, dynamic>,
      'hasUnresolvedDelivery': true,
    });
  }
}
