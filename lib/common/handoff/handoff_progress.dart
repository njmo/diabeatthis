/// Domain owners supply confirmations; a window never decides what evidence means.
class HandoffProgress {
  HandoffProgress(Map<String, bool> actions)
    : actions = Map.unmodifiable(actions);

  final Map<String, bool> actions;

  bool get isComplete => actions.isNotEmpty && actions.values.every((v) => v);

  List<bool> completedRows(Iterable<String> actionIds) => [
    for (final id in actionIds) actions[id] == true,
  ];
}
