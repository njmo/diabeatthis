'use strict';
const {FamilyError,exact}=require('./security.cjs');
function validateActivitySchedule(v) {
  const fail=()=>{throw new FamilyError('invalid-argument');};
  exact(v,['weekdays','startMinute','durationMinutes','confirmationMode','previousDayMinute','validFrom','validUntil']);
  const minute=n=>Number.isInteger(n)&&n>=0&&n<1440;
  if(!Array.isArray(v.weekdays)||!v.weekdays.length||v.weekdays.length>7||new Set(v.weekdays).size!==v.weekdays.length||v.weekdays.some(n=>!Number.isInteger(n)||n<1||n>7)||
    !minute(v.startMinute)||!minute(v.previousDayMinute)||!['before','previous_day','automatic'].includes(v.confirmationMode)||
    (v.durationMinutes!==null&&(!Number.isInteger(v.durationMinutes)||v.durationMinutes<1||v.durationMinutes>1440))||
    !Number.isSafeInteger(v.validFrom)||v.validFrom<=0||v.validFrom>Date.now()+366*86400000||
    (v.validUntil!==null&&(!Number.isSafeInteger(v.validUntil)||v.validUntil<v.validFrom||v.validUntil>Date.now()+732*86400000)))fail();
}
module.exports={validateActivitySchedule};
