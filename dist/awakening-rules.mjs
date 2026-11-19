export const width = 57;
export const height = 9;
export const start = Object.freeze({ x: 1, y: 4 });
export const flowerBank = 6;
export const finalDepth = 49;
export const minAwakeningDepth = 12;
export const baseStepMs = 145;
export const awakeningStorageKey = 'cochannhan.awakening';

// The seven clusters trace a scenic winding route through the Moon Orchid sea.
const clusters = [[8, 4], [14, 3], [20, 3], [26, 4], [32, 5], [38, 5], [44, 4]];
export const cellId = (x, y) => y * width + x;
export const hopeCells = Object.freeze(clusters.map(([x, y]) => cellId(x, y)));
const directions = [[1, 0], [0, -1], [0, 1], [-1, 0]];

export function terrain(x, y) {
  if (x < 0 || x >= width || y < 2 || y > 6 || x > flowerBank + finalDepth) return 'rock';
  if (x >= 3 && x <= 5) return y === 4 ? 'ford' : 'water';
  if (x >= flowerBank) return 'garden';
  return 'bank';
}

function canWalk(x, y) {
  return !['rock', 'water'].includes(terrain(x, y));
}

export function aptitude(depth) {
  if (depth >= 40) return 'Giáp đẳng';
  if (depth >= 30) return 'Ất đẳng';
  if (depth >= 20) return 'Bính đẳng';
  if (depth >= 10) return 'Đinh đẳng';
  return 'Chưa khai khiếu';
}

export function rollAwakeningLimit(rng = Math.random) {
  const r = rng();
  // Weighted across real awakening tiers (min 12 steps so every run opens an aperture)
  if (r < 0.18) return 12 + Math.floor(rng() * 8);   // Đinh đẳng (12..19)
  if (r < 0.56) return 21 + Math.floor(rng() * 9);   // Bính đẳng (21..29)
  if (r < 0.84) return 31 + Math.floor(rng() * 9);   // Ất đẳng (31..39)
  return 41 + Math.floor(rng() * 9);                 // Giáp đẳng (41..49)
}

export function seaEssenceRatio(depth) {
  if (depth < 10) return 0;
  const clamped = Math.min(finalDepth, depth);
  const tier = clamped >= 40 ? 3 : clamped >= 30 ? 2 : clamped >= 20 ? 1 : 0;
  const tierFloor = 10 + tier * 10;
  const base = 0.2 + tier * 0.2;
  const span = ((clamped - tierFloor) / 9) * 0.17;
  return Math.min(0.98, Math.round((base + span) * 100) / 100);
}

export function seaEssenceLabel(depth) {
  const pct = Math.round(seaEssenceRatio(depth) * 100);
  if (pct <= 0) return 'Chưa ngưng tụ nguyên hải';
  const thanh = Math.floor(pct / 10);
  const le = pct % 10;
  return `${le === 0 ? `${thanh} thành` : `${thanh} thành ${le}`} (${pct}%)`;
}

export function stepPace(state, nextX) {
  const forward = Math.max(0, nextX - flowerBank);
  if (nextX <= flowerBank || forward < state.limit - 4) return baseStepMs;
  const remaining = Math.max(0, state.limit - forward);
  const slowdown = [860, 620, 440, 310, 220];
  return slowdown[remaining] ?? baseStepMs;
}

export function createCeremony({ limit, rng = Math.random } = {}) {
  const chosen = Number.isInteger(limit)
    ? Math.max(1, Math.min(finalDepth, limit))
    : rollAwakeningLimit(rng);
  return { ...start, depth: 0, limit: chosen, gathered: [], finished: false };
}

export function move(state, x, y) {
  if (state.finished || !Number.isInteger(x) || !Number.isInteger(y) ||
      Math.abs(state.x - x) + Math.abs(state.y - y) !== 1 || !canWalk(x, y)) return state;

  const forward = Math.max(0, x - flowerBank);
  if (forward > state.limit) return state;

  const depth = Math.max(state.depth, forward);
  const id = cellId(x, y);
  const gather = hopeCells.includes(id) && !state.gathered.includes(id);
  const reachedLimit = depth >= state.limit;

  return {
    x,
    y,
    depth,
    limit: state.limit,
    gathered: gather ? [...state.gathered, id] : state.gathered,
    finished: reachedLimit,
  };
}

export function routeTo(state, x, y) {
  if (!canWalk(x, y)) return [];
  const target = cellId(x, y);
  const first = cellId(state.x, state.y);
  const queue = [first];
  const previous = new Map([[first, null]]);
  for (const id of queue) {
    if (id === target) {
      const path = [];
      for (let next = id; next !== first; next = previous.get(next)) {
        path.push([next % width, Math.floor(next / width)]);
      }
      return path.reverse();
    }
    for (const [dx, dy] of directions) {
      const col = id % width + dx;
      const row = Math.floor(id / width) + dy;
      if (!canWalk(col, row)) continue;
      const next = cellId(col, row);
      if (previous.has(next)) continue;
      previous.set(next, id);
      queue.push(next);
    }
  }
  return [];
}
