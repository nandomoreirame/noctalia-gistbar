.pragma library

// cached: { id: updatedAt } read from the cache directory.
function plan(list, cached) {
  const have = cached || {};
  const listed = {};
  const fetch = [];
  for (const g of list) {
    listed[g.id] = true;
    if (have[g.id] !== g.updatedAt) fetch.push(g.id);
  }
  const drop = Object.keys(have).filter((id) => !listed[id]);
  return { fetch: fetch, drop: drop };
}

function createQueue() {
  return { pending: [], running: [] };
}

function enqueue(q, ids) {
  const pending = q.pending.slice();
  for (const id of ids) if (pending.indexOf(id) < 0 && q.running.indexOf(id) < 0) pending.push(id);
  return { pending: pending, running: q.running.slice() };
}

function nextJobs(q, limit) {
  const free = Math.max(0, limit - q.running.length);
  const start = q.pending.slice(0, free);
  return { start: start, queue: { pending: q.pending.slice(free), running: q.running.concat(start) } };
}

function finish(q, id) {
  return { pending: q.pending.slice(), running: q.running.filter((x) => x !== id) };
}
