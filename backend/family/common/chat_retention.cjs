'use strict';
const {FamilyError} = require('./security.cjs');

// A later shortening with an equal or smaller period applies to every message
// covered by the earlier one (and possibly more). Its deadline dominates it.
// This preserves expiry without backfilling messages or restoring old content.
function compactShortenings(changes) {
  if (!Array.isArray(changes) || changes.some(change =>
    !change || !Number.isSafeInteger(change.revision) || change.revision < 1 ||
    ![1, 7, 30].includes(change.days))) {
    throw new FamilyError('failed-precondition');
  }
  const frontier = [];
  let minimum = Infinity;
  for (const change of [...changes].sort((a, b) => b.revision - a.revision || a.days - b.days)) {
    if (change.days < minimum) {
      frontier.push(change);
      minimum = change.days;
    }
  }
  return frontier.reverse();
}

module.exports = {compactShortenings};
