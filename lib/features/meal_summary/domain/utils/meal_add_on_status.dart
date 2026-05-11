String mealStatusAfterAddOn(String? status) {
  switch (status) {
    case 'eating-then-bolus':
      return 'eating-then-bolus';
    case 'bolused-eating':
      return 'bolused-eating';
    case 'waited-eating':
      return 'waited-eating';
    default:
      return 'eating-extra';
  }
}

String mealStatusAfterEatingConfirmation(String? status) {
  if (status == 'eating-extra') {
    return 'eaten-extra';
  }

  return 'eaten';
}

bool mealStatusHasReportedAddOn(String? status) {
  return status == 'eating-extra' || status == 'eaten-extra';
}

bool mealStatusCanRequestAddOn(String? status) {
  return !mealStatusHasReportedAddOn(status);
}
