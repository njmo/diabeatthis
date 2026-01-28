import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_controller_provider.g.dart';

@riverpod
class ParentModeNotifier extends _$ParentModeNotifier {
  @override
  bool build() {
    return false;
  }

  void setParentModeEnabled(bool enabled) {
    state = enabled;
  }

  void setParentModeDisabled() {
    state = false;
  }

  void toggleParentMode()
  {
    state = !state;
  }
}