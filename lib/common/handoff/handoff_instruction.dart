import 'handoff_step.dart';

/// Presentation data shared by meal, carbohydrate and other external app flows.
class HandoffInstruction {
  HandoffInstruction({
    required this.title,
    required this.closeLabel,
    required List<HandoffStep> steps,
  }) : steps = List.unmodifiable(steps) {
    if (title.trim().isEmpty ||
        closeLabel.trim().isEmpty ||
        steps.isEmpty ||
        steps.length > 3 ||
        steps.any((step) => step.actionId.trim().isEmpty)) {
      throw ArgumentError('Invalid handoff instruction');
    }
  }

  final String title;
  final String closeLabel;
  final List<HandoffStep> steps;
}
