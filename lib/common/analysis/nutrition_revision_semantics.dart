/// Only included when a document actually contains ingredient revisions.
String nutritionRevisionSemantics(bool hasRevisions) => hasRevisions
    ? '''Nutrition revisions compare later ingredient data at the SAME recorded quantity.
Use recorded macros for historical outcomes, never current values. Higher nutrition confidence
means reported estimate quality, not proven accuracy or better glucose outcomes; it does not
increase quantity confidence. Unknown change_basis does not imply label verification, weighing
or successful calibration. Missing historical values remain unknown. For a planned meal, apply
comparisons only to matching ingredient identities and compare quantities separately.'''
    : '';
