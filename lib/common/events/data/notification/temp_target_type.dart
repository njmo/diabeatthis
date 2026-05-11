class TempTargetType {
  static const meal = 'meal';
  static const activity = 'activity';

  static String displayName(String targetType) {
    return switch (targetType) {
      meal => 'Meal',
      activity => 'Activity',
      _ => targetType,
    };
  }
}
