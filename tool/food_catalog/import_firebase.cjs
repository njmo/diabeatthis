'use strict';

// Disposable create-only import. Does not deploy rules, indexes or app changes.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { isDeepStrictEqual } = require('node:util');
const { encode, authenticatedClient, listDocuments } = require('./common/firestore.cjs');

const project = 'diabeatthis-e634c';
const database = '(default)';
const collection = 'common/ingredients/items';
const dataDir = path.join(__dirname, 'data');

function loadReviewedCatalog() {
  const audit = spawnSync('python3', [path.join(__dirname, 'audit.py')], { encoding: 'utf8' });
  if (audit.status !== 0) throw new Error('Local catalog audit failed: ' + audit.stderr);
  const manifest = JSON.parse(fs.readFileSync(path.join(dataDir, 'manifest.json'), 'utf8'));
  const bytes = fs.readFileSync(path.join(dataDir, 'ready.jsonl'));
  const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
  if (sha256 !== manifest.files['ready.jsonl'].sha256) throw new Error('Ready file checksum mismatch');
  const documents = bytes.toString('utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  if (documents.length !== manifest.statuses.ready) throw new Error('Ready count mismatch');
  const seen = new Set();
  for (const document of documents) {
    if (!/^usda_[1-9][0-9]*$/.test(document.id) || seen.has(document.id)) throw new Error('Invalid or duplicate ID');
    seen.add(document.id);
  }
  return { documents, sha256, audit: JSON.parse(audit.stdout) };
}

function compareExisting(expected, actual, requireAll) {
  const wanted = new Map(expected.map(document => [document.id, document]));
  for (const [id, document] of actual) {
    if (!wanted.has(id)) throw new Error('Unexpected existing target document: ' + id);
    if (!isDeepStrictEqual(document, wanted.get(id))) throw new Error('Existing target differs; no overwrite allowed: ' + id);
  }
  if (requireAll && actual.size !== wanted.size) throw new Error('Remote catalog count differs from local export');
  return expected.filter(document => !actual.has(document.id));
}

async function main() {
  const action = process.argv[2] || 'dry-run';
  if (!['dry-run', 'check', 'upload', 'verify'].includes(action)) throw new Error('Use dry-run, check, upload or verify');
  const catalog = loadReviewedCatalog();
  const summary = { project, database, collection, expectedRecords: catalog.documents.length, sha256: catalog.sha256, localAudit: catalog.audit };
  if (action === 'dry-run') {
    console.log(JSON.stringify({ ...summary, cloudWrites: 0 }, null, 2));
    return;
  }
  const client = await authenticatedClient(project, path.join(dataDir, 'firebase-context'));
  const base = `projects/${project}/databases/${database}`;
  const resource = `${base}/documents/${collection}`;
  const metadata = await client.get('/' + base);
  if (metadata.body.name !== base || metadata.body.type !== 'FIRESTORE_NATIVE') throw new Error('Unexpected database target');
  const existing = await listDocuments(client, resource);
  const missing = compareExisting(catalog.documents, existing, action === 'verify');
  if (action === 'check') {
    fs.writeFileSync(path.join(dataDir, 'firebase-preflight.json'), JSON.stringify({ ...summary, location: metadata.body.locationId, existingMatching: existing.size, missing: missing.length, cloudWrites: 0 }, null, 2) + '\n');
    console.log(JSON.stringify({ ...summary, existingMatching: existing.size, missing: missing.length, cloudWrites: 0 }, null, 2));
    return;
  }
  let created = 0;
  if (action === 'upload') {
    // Save only the catalog snapshot; credentials never enter these reports.
    fs.writeFileSync(path.join(dataDir, 'firebase-before-import.json'), JSON.stringify(Object.fromEntries(existing), null, 2) + '\n');
    for (let offset = 0; offset < missing.length; offset += 200) {
      const batch = missing.slice(offset, offset + 200);
      const writes = batch.map(document => ({ update: { name: `${resource}/${document.id}`, fields: encode(document).mapValue.fields }, currentDocument: { exists: false } }));
      await client.post(`/${base}/documents:commit`, { writes });
      created += batch.length;
      console.log(`Created ${created}/${missing.length} ingredient documents`);
    }
  }
  // Read back every field of every record, not just a sample or a count.
  const after = await listDocuments(client, resource);
  compareExisting(catalog.documents, after, true);
  const report = { ...summary, location: metadata.body.locationId, created, existingMatching: existing.size, verifiedRecords: after.size, fieldComparison: 'exact_match', verifiedAt: new Date().toISOString() };
  fs.writeFileSync(path.join(dataDir, 'firebase-import-report.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
}

if (require.main === module) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { compareExisting };
