const assert = require('node:assert/strict');
const {Timestamp} = require('firebase-admin/firestore');
function sosStore() {
  const values = new Map(); let sequence = 0; let queue = Promise.resolve();
  const normalize = (value, previous) => {
    if (value?.constructor?.name === 'ServerTimestampTransform') return Timestamp.now();
    if (value?.constructor?.name === 'ArrayUnionTransform') return [...new Set([...(previous || []), ...value.elements])];
    if (value instanceof Timestamp || value instanceof Date) return value;
    if (Array.isArray(value)) return value.map((v) => normalize(v));
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalize(v, previous?.[k])]));
    return value;
  };
  const snapshot = (path) => ({id: path.split('/').pop(), ref: ref(path), exists: values.has(path), data: () => normalize(values.get(path))});
  const ref = (path) => ({path, id: path.split('/').pop(), get: async () => snapshot(path),
    create: async (data) => {assert(!values.has(path)); values.set(path, normalize(data));},
    set: async (data, options) => values.set(path, options?.merge ? {...values.get(path), ...normalize(data, values.get(path))} : normalize(data)),
    update: async (data) => {assert(values.has(path)); values.set(path, {...values.get(path), ...normalize(data, values.get(path))});},
    delete: async () => values.delete(path),
  });
  const query = (name, clauses = [], cap = Infinity, sort) => ({name, clauses, cap, sort,
    where: (field, op, value) => query(name, [...clauses, [field, op, value]], cap, sort),
    limit: (value) => query(name, clauses, value, sort),
    orderBy: (field, direction = 'asc') => query(name, clauses, cap, [field, direction]),
    get: async () => read(query(name, clauses, cap, sort)),
  });
  function read(target) {
    if (target.path) return snapshot(target.path);
    let docs = [...values.keys()].filter((path) => path.startsWith(`${target.name}/`) && target.clauses.every(([key, op, v]) => {
      const value = values.get(path)[key];
      return op === '==' ? value === v : op === 'in' ? v.includes(value) : op === 'array-contains' ? Array.isArray(value) && value.includes(v) : Array.isArray(value) && value.some((x) => v.includes(x));
    })).map(snapshot);
    if (target.sort) {const [field, direction] = target.sort; docs.sort((a, b) => (a.data()[field].toMillis() - b.data()[field].toMillis()) * (direction === 'desc' ? -1 : 1));}
    docs = docs.slice(0, target.cap);
    return {docs, size: docs.length, empty: docs.length === 0};
  }
  return {values, collection: (name) => ({...query(name), doc: (id) => ref(`${name}/${id || `auto-${++sequence}`}`)}),
    runTransaction(fn) {
      const work = queue.then(async () => {
        const writes = [];
        const tx = {get: async (target) => {assert.equal(writes.length, 0, 'all reads precede writes'); return read(target);}};
        for (const kind of ['create', 'set', 'update', 'delete']) tx[kind] = (...args) => writes.push([kind, args]);
        const result = await fn(tx);
        for (const [kind, [target, ...args]] of writes) await target[kind](...args);
        return result;
      });
      queue = work.catch(() => {}); return work;
    },
  };
}
module.exports = {sosStore};
