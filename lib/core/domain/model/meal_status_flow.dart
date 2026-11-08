const mealStatusesBlockingAnotherMealActivation = {
  'eating',
  'eating-extra',
  'eating-then-bolus',
  'waiting-for-bolus',
  'bolused-waiting',
  'waited-eating',
  'bolused-eating',
};

bool mealStatusBlocksAnotherMealActivation(String? status) {
  return mealStatusesBlockingAnotherMealActivation.contains(status);
}

bool mealStatusReadyToSummarize(String? status) {
  return status == 'eaten' ||
      status == 'eaten-extra' ||
      status == 'eaten-bolused';
}

const mealStatusesStartingEating = {
  'eating',
  'eating-then-bolus',
  'bolused-eating',
  'waited-eating',
};

/// Terminal meals remain in history, while actionable meals stay on the dashboard.
bool mealStatusAppearsOnDashboard(String? status) =>
    status == 'planned' ||
    mealStatusBlocksAnotherMealActivation(status) ||
    mealStatusReadyToSummarize(status);
