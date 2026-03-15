import 'runtime_context.dart';

abstract class WorkflowTask {
  const WorkflowTask();

  String get name => runtimeType.toString();

  Future<void> run(RuntimeContext context);
}