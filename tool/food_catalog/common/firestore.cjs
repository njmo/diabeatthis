'use strict';

const path = require('node:path');
const os = require('node:os');

function encode(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Number.isSafeInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (value && typeof value === 'object') {
    return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item)])) } };
  }
  throw new Error('Unsupported Firestore value');
}

function decode(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  if ('mapValue' in value) return Object.fromEntries(Object.entries(value.mapValue.fields || {}).map(([key, item]) => [key, decode(item)]));
  throw new Error('Unexpected Firestore field type');
}

async function authenticatedClient(project, context) {
  const directory = process.env.FIREBASE_TOOLS_LIB || path.join(os.homedir(), '.cache/firebase/tools/lib/node_modules/firebase-tools/lib');
  const auth = require(path.join(directory, 'auth.js'));
  const { requireAuth } = require(path.join(directory, 'requireAuth.js'));
  const { Client } = require(path.join(directory, 'apiv2.js'));
  const account = auth.getProjectDefaultAccount(context);
  if (!account) throw new Error('Firebase CLI login is required');
  // The installed CLI handles its own credentials. Never print or persist them.
  await requireAuth({ project, user: account.user, tokens: account.tokens });
  return new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
}

async function listDocuments(client, resource) {
  const documents = new Map();
  let token;
  do {
    const queryParams = { pageSize: 300 };
    if (token) queryParams.pageToken = token;
    const response = await client.get('/' + resource, { queryParams });
    for (const document of response.body.documents || []) {
      const id = document.name.split('/').at(-1);
      if (documents.has(id)) throw new Error('Repeated document in pagination');
      documents.set(id, decode({ mapValue: { fields: document.fields || {} } }));
    }
    token = response.body.nextPageToken;
  } while (token);
  return documents;
}

module.exports = { encode, decode, authenticatedClient, listDocuments };
