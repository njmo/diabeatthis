'use strict';
class MemoryStore {
  constructor() { this.values = new Map(); this.queue = Promise.resolve(); }
  doc(path) { return {path, id: path.split('/').at(-1), collection: name => this.collection(path + '/' + name)}; }
  collectionGroup(name) { return this.collection('', [], null, Infinity, null, name); }
  collection(path, filters = [], ordering = null, count = Infinity, cursor = null, group = null) {
    return {path, group, query: true, filters, ordering, count, cursor, doc: id => this.doc(path + '/' + id),
      where: (field, operator, value) => this.collection(path, [...filters, {field, operator, value}], ordering, count, cursor, group),
      orderBy: (field, direction = 'asc') => this.collection(path, filters, {field, direction}, count, cursor, group),
      startAfter: value => this.collection(path, filters, ordering, count, value, group),
      limit: limit => this.collection(path, filters, ordering, limit, cursor, group)};
  }
  runTransaction(action) {
    const run = this.queue.then(async () => {
      const working = new Map(structuredClone([...this.values]));
      const snap = (path, value) => ({id: path.split('/').at(-1), ref: this.doc(path), exists: value !== undefined, data: () => structuredClone(value)});
      const tx = {
        get: async ref => {
          if (!ref.query) return snap(ref.path, working.get(ref.path));
          const field = (value, name) => name.split('.').reduce((v, key) => v?.[key], value);
          let rows = [...working].filter(([key, value]) => (ref.group ? key.split('/').at(-2) === ref.group : key.startsWith(ref.path + '/') && key.split('/').length === ref.path.split('/').length + 1) && (ref.filters ?? []).every(filter => {
            const actual = field(value, filter.field);
            if (filter.operator === '==') return actual === filter.value;
            if (filter.operator === '>') return actual > filter.value;
            if (filter.operator === '<') return actual < filter.value;
            if (filter.operator === '<=') return actual <= filter.value;
            if (filter.operator === 'in') return filter.value.includes(actual);
            if (filter.operator === 'array-contains') return Array.isArray(actual) && actual.includes(filter.value);
            throw new Error('Unsupported test query operator: ' + filter.operator);
          }));
          if (ref.ordering?.field === '__name__') {
            rows.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0);
            if (ref.cursor) rows = rows.filter(([key]) => typeof ref.cursor === 'object' ? key > ref.cursor.path : key.split('/').at(-1) > ref.cursor);
          } else if (ref.ordering) rows.sort((a, b) => (field(a[1], ref.ordering.field) - field(b[1], ref.ordering.field)) * (ref.ordering.direction === 'desc' ? -1 : 1));
          return {docs: rows.slice(0, ref.count ?? Infinity).map(([key, value]) => snap(key, value))};
        },
        set: (ref, value, options) => working.set(ref.path, options?.merge
          ? {...working.get(ref.path), ...structuredClone(value)} : structuredClone(value)),
        update: (ref, value) => working.set(ref.path, {...working.get(ref.path), ...structuredClone(value)}),
        delete: ref => working.delete(ref.path),
      };
      const result = await action(tx); this.values = working; return result;
    });
    this.queue = run.catch(() => {}); return run;
  }
}
module.exports = {MemoryStore};
