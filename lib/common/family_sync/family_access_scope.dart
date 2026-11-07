import 'family_planning_controller.dart';

/// Pins an operation/view to the account, child and mirror source that opened it.
class FamilyAccessScope {
  FamilyAccessScope(this.family)
    : uid = family.uid,
      owner = family.owner,
      source = family.source;
  final FamilyPlanningController family;
  final String? uid;
  final String? owner;
  final String? source;
  bool get isCurrent =>
      !family.disposed &&
      !family.failed &&
      uid != null &&
      owner != null &&
      source != null &&
      family.uid == uid &&
      family.currentUid() == uid &&
      family.owner == owner &&
      family.source == source;
  void requireCurrent({bool complete = true}) {
    if (!isCurrent || (complete && !family.complete)) {
      throw StateError('Family scope changed');
    }
  }
}
