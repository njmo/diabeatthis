'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {compactShortenings} = require('../common/chat_retention.cjs');
const {createChatService, DAY} = require('../common/chat_service.cjs');
const {MemoryStore} = require('./memory_store.cjs');

test('compaction preserves the exact deadline for every message revision across long policy histories', () => {
  const service = createChatService({store: new MemoryStore()});
  let random = 12345;
  const changes = [];
  for (let revision = 1; revision <= 600; revision++) {
    random = (Math.imul(random, 1664525) + 1013904223) >>> 0;
    changes.push({revision, days: [1, 7, 30][random % 3], at: revision * DAY});
    const compacted = compactShortenings(changes);
    assert.ok(compacted.length <= 3);
    for (let policyRevision = 0; policyRevision <= revision; policyRevision++) {
      for (const expiresAt of [null, 2 * DAY, 8 * DAY, 31 * DAY]) {
        const message = {policyRevision, sentAt: DAY, expiresAt};
        assert.equal(service.expiresAt(message, {shortenings: compacted}),
          service.expiresAt(message, {shortenings: changes}));
      }
    }
    // Incremental compaction has the same semantics as keeping all history.
    assert.deepEqual(compactShortenings([...compactShortenings(changes.slice(0, -1)), changes.at(-1)]), compacted);
  }
});

test('older tighter periods survive later extensions and wider shortenings', () => {
  const changes = [{revision: 1, days: 1}, {revision: 3, days: 7}, {revision: 5, days: 30}];
  assert.deepEqual(compactShortenings(changes), changes);
  const input = [...changes, {revision: 7, days: 7}];
  assert.deepEqual(compactShortenings(input), [changes[0], input[3]]);
  assert.equal(input.length, 4);
  assert.deepEqual(compactShortenings([...input, {revision: 9, days: 1}]), [{revision: 9, days: 1}]);
});

test('corrupt ledger is rejected instead of silently extending expiry', () => {
  for (const value of [null, {}, [{revision: 0, days: 1}], [{revision: 1, days: 0}], [{revision: 1, days: 2}], [{revision: 1.5, days: 7}]]) {
    assert.throws(() => compactShortenings(value), error => error.code === 'failed-precondition');
  }
});
