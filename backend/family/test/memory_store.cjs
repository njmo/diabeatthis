'use strict';
class MemoryStore {
  constructor() { this.values = new Map(); this.queue = Promise.resolve(); }
  doc(path) { return {path, id: path.split('/').at(-1), collection: name => this.collection(path + '/' + name)}; }
  collection(path) { return {path, query: true, doc: id => this.doc(path + '/' + id)}; }
  runTransaction(action) {
    const run = this.queue.then(async () => {
      const working = new Map(structuredClone([...this.values]));
      const snap = (path, value) => ({id: path.split('/').at(-1), exists: value !== undefined, data: () => structuredClone(value)});
      const tx = {
        get: async ref => ref.query ? {docs: [...working].filter(([key]) => key.startsWith(ref.path + '/') && key.split('/').length === ref.path.split('/').length + 1).map(([key, value]) => snap(key, value))} : snap(ref.path, working.get(ref.path)),
        set: (ref, value) => working.set(ref.path, structuredClone(value)),
        update: (ref, value) => working.set(ref.path, {...working.get(ref.path), ...structuredClone(value)}),
        delete: ref => working.delete(ref.path),
      };
      const result = await action(tx); this.values = working; return result;
    });
    this.queue = run.catch(() => {}); return run;
  }
}
module.exports = {MemoryStore};
