class TaskRuntime {
  TaskRuntime({
    this.lastTickAt,
    this.nextTickAt,
    this.isRunning = false,
  });

  DateTime? lastTickAt;
  DateTime? nextTickAt;

  bool isRunning;
}
