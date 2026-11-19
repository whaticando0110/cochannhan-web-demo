import { ACTIONS, createBattle, neighbors, playTurn } from './combat.mjs';
import { RAMPART_EDGE, rampartTile, stairConnects } from './rampart.mjs';

export const MAP = Object.freeze({ columns: 42, rows: 26 });
export const toCell = (col, row) => row * MAP.columns + col;
export const toPoint = (cell) => ({ col: cell % MAP.columns, row: Math.floor(cell / MAP.columns) });
export const SPAWN = toCell(9, 10);
const gateRow = 10;
export const GATE = toCell(RAMPART_EDGE, gateRow);
export const TRAIL_ENTRY = toCell(28, 10);
export const WOLF = toCell(31, 10);
export const CONTINUE = toCell(38, 10);

const huntingGround = Object.freeze({ left: 28, right: 39, top: 5, bottom: 14 });
const clearingRocks = new Set([toCell(30, 8), toCell(33, 12), toCell(36, 9), toCell(34, 6)]);

function terrainAt(cell) {
  const { col, row } = toPoint(cell);
  if (col <= RAMPART_EDGE) return { rampart: rampartTile(col, row, MAP.rows, gateRow) };
  const boundary = col === 0 || row === 0 || col === MAP.columns - 1 || row === MAP.rows - 1;
  const variant = (Math.imul(col + 13, 31) ^ Math.imul(row + 3, 17)) >>> 0;
  if (boundary) return { ground: 'mulch', prop: 'thicket', variant };
  if (col === 27 && (row < 7 || row > 13)) return { ground: 'mulch', prop: 'thicket', variant };
  if (col >= huntingGround.left) {
    const outside = row < huntingGround.top || row > huntingGround.bottom;
    const prop = outside ? 'thicket' : clearingRocks.has(cell) ? 'rock' : null;
    const ground = !outside && row >= 7 && row <= 13 ? 'trail' : 'mulch';
    return { ground, prop, variant };
  }
  const path = Math.abs(row - (col >= 20 && col <= 23 ? 11 : 10)) <= 1;
  const prop = !path && variant % 7 < 2 ? (variant % 2 ? 'thicket' : 'bamboo') : null;
  return { ground: path ? 'trail' : 'mulch', prop, variant };
}

export const TERRAIN = Object.freeze(Array.from({ length: MAP.columns * MAP.rows }, (_, cell) => terrainAt(cell)));
const obstacles = new Set(TERRAIN.flatMap(({ prop, rampart }, cell) => prop || rampart?.blocked ? [cell] : []));
export const ARENA = Object.freeze({ ...MAP, bounds: huntingGround, rocks: obstacles });

export const FIELD_ACTIONS = Object.freeze({
  move: ACTIONS.move,
  strike: ACTIONS.strike,
  moon: ACTIONS.moon,
  guard: Object.freeze({ ...ACTIONS.guard, name: 'Thủ thế', reduction: 0.5 }),
});

const wolf = Object.freeze({
  name: 'Sói rừng',
  heavyName: 'Vồ mồi', heavyEvery: 3, heavyRange: 4, heavyDamage: 17,
  strikeName: 'Cắn', strikeDamage: 11, pace: 2,
  victory: 'Sói rừng đã gục. Bạn có thể tiếp tục khám phá.',
  defeat: 'Bạn đã gục ở bãi săn.',
});

export function insideHunt(cell) {
  const { col, row } = toPoint(cell);
  return col >= huntingGround.left && col <= huntingGround.right &&
    row >= huntingGround.top && row <= huntingGround.bottom;
}

export function locationOf(cell) {
  const { col } = toPoint(cell);
  if (col <= RAMPART_EDGE) return 'Cổ Nguyệt Sơn Trại';
  if (col < 28) return 'Đường rừng';
  return 'Bãi săn Thanh Mao';
}

export function createWorld({ seed = 29 } = {}) {
  return {
    mode: 'explore',
    player: { cell: SPAWN, hp: 48, maxHp: 48, qi: 4, maxQi: 6 },
    battle: null,
    checkpoint: null,
    seed,
    cleared: false,
    reached: false,
    notice: 'Qua cổng phía đông, rồi theo lối mòn tới bãi săn.',
  };
}

export function isWalkable(cell) {
  return Number.isInteger(cell) && cell >= 0 && cell < TERRAIN.length && !obstacles.has(cell);
}

function canExploreStep(from, to) {
  if (!isWalkable(from) || !isWalkable(to)) return false;
  const source = TERRAIN[from].rampart;
  const target = TERRAIN[to].rampart;
  const a = source?.stair;
  const b = target?.stair;
  if (a && b) return a === b;
  if (a) return stairConnects(a, toPoint(from), toPoint(to), target?.elevation ?? 0);
  if (b) return stairConnects(b, toPoint(to), toPoint(from), source?.elevation ?? 0);
  return (source?.elevation ?? 0) === (target?.elevation ?? 0);
}

export function findPath(state, target) {
  const from = state.player.cell;
  if (state.mode !== 'explore' || !isWalkable(target) || from === target) return [];

  const queue = [from];
  const previous = new Map([[from, null]]);
  for (let at = 0; at < queue.length; at++) {
    for (const next of neighbors(queue[at], MAP)) {
      if (previous.has(next) || !canExploreStep(queue[at], next)) continue;
      previous.set(next, queue[at]);
      if (next === target) {
        const path = [];
        for (let cell = target; cell !== from; cell = previous.get(cell)) path.push(cell);
        return path.reverse();
      }
      queue.push(next);
    }
  }
  return [];
}

export function walk(state, target) {
  if (state.mode !== 'explore' || !neighbors(state.player.cell, MAP).includes(target) || !canExploreStep(state.player.cell, target)) return state;
  const player = { ...state.player, cell: target };
  if (!state.cleared && insideHunt(target)) {
    const battle = createBattle({
      arena: ARENA, opponent: wolf, actions: FIELD_ACTIONS, player,
      rival: { cell: WOLF, hp: 47, maxHp: 47 },
    });
    return { ...state, player, battle, checkpoint: battle, mode: 'battle', notice: 'Một con sói xuất hiện. Đọc vùng đỏ trước khi hành động.' };
  }
  const reached = state.cleared && (state.reached || target === CONTINUE);
  return {
    ...state, player, reached,
    notice: reached ? 'Bạn đã đi tới cuối đoạn thử.' : state.notice,
  };
}

export function fight(state, action, target) {
  if (state.mode !== 'battle') return { state, error: 'Chưa có cuộc chạm trán.' };
  const { state: battle, error } = playTurn(state.battle, action, target);
  if (error) return { state, error };
  const next = { ...state, player: battle.player, battle };
  if (battle.result === 'win') {
    return { state: { ...next, mode: 'explore', cleared: true, notice: wolf.victory }, error: '' };
  }
  if (battle.result === 'loss') {
    return { state: { ...next, mode: 'defeat', notice: wolf.defeat }, error: '' };
  }
  return { state: next, error: '' };
}

export function retryEncounter(state) {
  if (state.mode !== 'defeat' || !state.checkpoint) return state;
  const battle = state.checkpoint;
  return { ...state, mode: 'battle', battle, player: battle.player, notice: 'Thử lại từ lúc sói xuất hiện.' };
}
