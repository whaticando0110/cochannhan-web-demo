import { restoreRun, serializeRun } from './roguelike.mjs';

const key = 'cochannhan.roguelike.v1';
const stores = [() => sessionStorage, () => localStorage];

export function readRun() {
  if (location.hash.startsWith('#run=')) {
    try {
      const run = restoreRun(decodeURIComponent(location.hash.slice(5)));
      if (run) return run;
    } catch {
      // A malformed link can still resume the saved run.
    }
  }
  for (const storage of stores) {
    try {
      const run = restoreRun(storage().getItem(key));
      if (run) return run;
    } catch {
      // Session storage may still be available when persistent storage is disabled.
    }
  }
  return null;
}

export function writeRun(run) {
  const data = serializeRun(run);
  let saved = false;
  for (const storage of stores) {
    try {
      storage().setItem(key, data);
      saved = true;
    } catch {
      // Keep the active state in memory if the browser blocks storage.
    }
  }
  return saved;
}

export function newSeed() {
  return crypto.getRandomValues(new Uint32Array(1))[0];
}

export function runUrl(page, run, saved) {
  return saved ? page : `${page}#run=${encodeURIComponent(serializeRun(run))}`;
}
