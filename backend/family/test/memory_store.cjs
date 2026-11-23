'use strict';
class MemoryStore {
  constructor() { this.values = new Map(); this.queue = Promise.resolve(); }
  doc(path) { return {path, id: path.split('/').at(-1), collection: name => this.collection(path + '/' + name)}; }
  collectionGroup(name) { return this.collection('', [], null, Infinity, null, name); }
  collection(path, filters = [], ordering = null, count = Infinity, cursor = null, group = null, projection = null) {
    return {path, group, query: true, filters, ordering, count, cursor, projection, doc: id => this.doc(path + '/' + id),
      where: (field, operator, value) => this.collection(path, [...filters, {field, operator, value}], ordering, count, cursor, group, projection),
      orderBy: (field, direction = 'asc') => this.collection(path, filters, {field, direction}, count, cursor, group, projection),
      startAfter: value => this.collection(path, filters, ordering, count, value, group, projection),
      limit: limit => this.collection(path, filters, ordering, limit, cursor, group, projection),
      select: (...fields) => this.collection(path, filters, ordering, count, cursor, group, fields)};
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
            if (filter.operator === '>=') return actual >= filter.value;
            if (filter.operator === '<') return actual < filter.value;
            if (filter.operator === '<=') return actual <= filter.value;
            if (filter.operator === 'in') return filter.value.includes(actual);
            if (filter.operator === 'array-contains') return Array.isArray(actual) && actual.includes(filter.value);
            throw new Error('Unsupported test query operator: ' + filter.operator);
          }));
          if (ref.ordering?.field === '__name__') {
            rows.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0);
            if (ref.cursor) rows = rows.filter(([key]) => typeof ref.cursor === 'object' ? key > ref.cursor.path : key.split('/').at(-1) > ref.cursor);
          } else if (ref.ordering) {
            const {field: name, direction} = ref.ordering;
            const compare = (a, b) => (a < b ? -1 : a > b ? 1 : 0) * (direction === 'desc' ? -1 : 1);
            rows.sort((a, b) => compare(field(a[1], name), field(b[1], name)));
            if (ref.cursor !== null) rows = rows.filter(([, value]) => compare(field(value, name), ref.cursor) > 0);
          }
          return {docs: rows.slice(0, ref.count).map(([key, value]) => {
            if (!ref.projection) return snap(key, value);
            const projected = {};
            for (const name of ref.projection) {
              const selected = field(value, name);
              if (selected === undefined) continue;
              const path = name.split('.');
              const leaf = path.pop();
              const parent = path.reduce((object, part) => (object[part] ??= {}), projected);
              parent[leaf] = selected;
            }
            return snap(key, projected);
          })};
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
