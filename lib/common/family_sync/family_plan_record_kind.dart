bool familyPlanTargetsKind(String type, String kind) => switch (kind) {
  'meals' => type.endsWith('Meal'),
  'activityOccurrences' => [
    'planActivity',
    'confirmActivity',
    'moveActivity',
    'skipActivity',
  ].contains(type),
  'activitySchedules' => type == 'setActivityScheduleEnabled',
  'activities' => [
    'createActivity',
    'updateActivity',
    'createActivitySchedule',
  ].contains(type),
  'activityLogs' => ['startActivity', 'logActivity'].contains(type),
  _ => false,
};

String? familyPlanResultKind(String type) => switch (type) {
  'createMeal' || 'updateMeal' => 'meals',
  'planActivity' ||
  'confirmActivity' ||
  'moveActivity' ||
  'skipActivity' => 'activityOccurrences',
  'createActivity' || 'updateActivity' => 'activities',
  'createActivitySchedule' ||
  'setActivityScheduleEnabled' => 'activitySchedules',
  'startActivity' || 'logActivity' => 'activityLogs',
  _ => null,
};

bool familyPlanLocksRecord(Map plan, String kind, int id) =>
    plan['status'] == 'pending' &&
    (plan['targetId'] == id &&
            familyPlanTargetsKind(plan['type'] as String, kind) ||
        plan['resultId'] == id &&
            familyPlanResultKind(plan['type'] as String) == kind);
