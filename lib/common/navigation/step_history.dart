/// Back navigation history for a multi-step flow.
class StepHistory<T extends Object> {
  StepHistory({required this.root});

  final T root;
  final List<T> _steps = [];

  void reset() {
    _steps.clear();
    _steps.add(root);
  }

  void push(T step) {
    if (_steps.isNotEmpty && _steps.last == step) return;
    _steps.add(step);
  }

  T pop() => _steps.isEmpty ? root : _steps.removeLast();
}
