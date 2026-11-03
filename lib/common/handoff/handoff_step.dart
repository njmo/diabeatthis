/// A localized instruction row. Multiple rows can depend on the same action.
class HandoffStep {
  const HandoffStep({
    required this.label,
    required this.value,
    required this.actionId,
    this.showCheckbox = true,
  });

  final String label;
  final String value;
  final String actionId;
  final bool showCheckbox;
}
