export const width = 57;
export const height = 9;
export const start = Object.freeze({ x: 1, y: 4 });
export const flowerBank = 6;
export const finalDepth = 49;
export const initialResolve = 27;
export const hopeGain = 5;

// The flowers nearest the river and the spring bend leave a clear middle lane.
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

export function createCeremony() {
  return { ...start, depth: 0, resolve: initialResolve, gathered: [], finished: false };
}

export function move(state, x, y) {
  if (state.finished || !Number.isInteger(x) || !Number.isInteger(y) ||
      Math.abs(state.x - x) + Math.abs(state.y - y) !== 1 || !canWalk(x, y)) return state;

  const depth = Math.max(state.depth, x - flowerBank);
  const id = cellId(x, y);
  const gather = hopeCells.includes(id) && !state.gathered.includes(id);
  const cost = x > flowerBank ? 1 : 0;
  const resolve = Math.min(initialResolve, state.resolve - cost + (gather ? hopeGain : 0));
  return { x, y, depth, resolve, gathered: gather ? [...state.gathered, id] : state.gathered,
    finished: resolve <= 0 || depth === finalDepth };
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
