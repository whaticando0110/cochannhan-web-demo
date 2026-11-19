import { neighbors } from './combat.mjs';
import { RAMPART_EDGE, isRampartTile, rampartTile, stairConnects } from './rampart.mjs';

export const MAP = Object.freeze({ columns: 42, rows: 26 });
export const toCell = (col, row) => row * MAP.columns + col;
export const toPoint = (cell) => ({ col: cell % MAP.columns, row: Math.floor(cell / MAP.columns) });
export const SPAWN = toCell(9, 10);
const gateRow = 10;
export const GATE = toCell(RAMPART_EDGE, gateRow);
export const TRAIL_ENTRY = toCell(28, 10);
export const WOLF = toCell(31, 10);
export const CONTINUE = toCell(38, 10);
export const TRAINING_POST = toCell(5, 12);
export const MOONLIGHT = Object.freeze({ damage: 26, cost: 2, cooldown: 720, range: 5 });

const huntingGround = Object.freeze({ left: 28, right: 39, top: 5, bottom: 14 });
const clearingRocks = new Set([toCell(30, 8), toCell(33, 12), toCell(36, 9), toCell(34, 6)]);

function terrainAt(cell) {
  const { col, row } = toPoint(cell);
  if (isRampartTile(col, row, gateRow)) return { rampart: rampartTile(col, row, MAP.rows, gateRow) };
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
const huntWolf = Object.freeze({ cell: WOLF, hp: 52, maxHp: 52 });

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

export function findPath(state, target, avoidCell) {
  const from = state.player.cell;
  if (state.mode === 'defeat') return [];
  return pathBetween(from, target, (from, to) => to !== avoidCell && canWalk(state, from, to));
}

function pathBetween(from, target, canStep) {
  if (!isWalkable(target) || from === target) return [];

  const queue = [from];
  const previous = new Map([[from, null]]);
  for (let at = 0; at < queue.length; at++) {
    for (const next of neighbors(queue[at], MAP)) {
      if (previous.has(next) || !canStep(queue[at], next)) continue;
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

function canWalk(state, from, to) {
  return canExploreStep(from, to)
    && (state.mode !== 'battle' || (insideHunt(to) && to !== state.battle.rival.cell));
}

function startBattle(now) {
  return { rival: huntWolf, nextAt: now + 950, intent: null };
}

export function walk(state, target, now = 0) {
  if (state.mode === 'defeat' || !neighbors(state.player.cell, MAP).includes(target)
    || !canWalk(state, state.player.cell, target)) return state;
  const player = { ...state.player, cell: target };
  if (!state.cleared && !state.battle && insideHunt(target)) {
    return { ...state, player, battle: startBattle(now), checkpoint: player, mode: 'battle',
      notice: 'Điện Lang xuất hiện. Bắn lúc có tầm và rời ô đỏ trước khi sói vồ.' };
  }
  const reached = state.cleared && (state.reached || target === CONTINUE);
  return {
    ...state, player, reached,
    notice: reached ? 'Bạn đã đi tới cuối đoạn thử.' : state.notice,
  };
}

export function cellDistance(from, to) {
  const a = toPoint(from);
  const b = toPoint(to);
  return Math.hypot(a.col - b.col, a.row - b.row);
}

export function clearShot(from, to) {
  const a = toPoint(from);
  const b = toPoint(to);
  const sampleCount = Math.max(Math.abs(b.col - a.col), Math.abs(b.row - a.row)) * 4;
  for (let i = 1; i < sampleCount; i++) {
    const col = Math.round(a.col + (b.col - a.col) * i / sampleCount);
    const row = Math.round(a.row + (b.row - a.row) * i / sampleCount);
    if (!isWalkable(toCell(col, row))) return false;
  }
  return true;
}

// At contact the wolf strikes the marked ground, even if its target moved.
export function advanceHunt(state, now) {
  if (state.mode !== 'battle' || now < state.battle.nextAt) return { state };
  const { battle, player } = state;
  const { rival, intent } = battle;
  if (intent) {
    const damage = intent.cells.includes(player.cell) ? 13 : 0;
    const hp = Math.max(0, player.hp - damage);
    const notice = hp === 0 ? 'Bạn đã gục ở bãi săn.' : damage ? 'Điện Lang vồ trúng.' : 'Bạn đã né được cú vồ.';
    return { state: { ...state, player: { ...player, hp },
      battle: { ...battle, intent: null, nextAt: now + 850 },
      mode: hp ? 'battle' : 'defeat', notice }, event: { type: 'pounce', target: intent.target } };
  }
  if (cellDistance(rival.cell, player.cell) <= 2.25) {
    const cells = [player.cell, ...neighbors(player.cell, MAP).filter(cell => insideHunt(cell) && isWalkable(cell))];
    return { state: { ...state, battle: { ...battle, intent: { target: player.cell, cells }, nextAt: now + 950 },
      notice: 'Điện Lang lấy đà. Rời vùng đỏ.' }, event: { type: 'windup' } };
  }
  const [to] = pathBetween(rival.cell, player.cell, (a, b) => insideHunt(b) && canExploreStep(a, b));
  const next = { ...battle, nextAt: now + 550 };
  if (to === undefined || to === player.cell) return { state: { ...state, battle: next } };
  return { state: { ...state, battle: { ...next, rival: { ...rival, cell: to } } },
    event: { type: 'move', from: rival.cell, to } };
}

export function hitHunt(state, aimedCell, damage) {
  if (state.mode !== 'battle' || state.battle.rival.cell !== aimedCell) return state;
  const hp = Math.max(0, state.battle.rival.hp - damage);
  const battle = { ...state.battle, rival: { ...state.battle.rival, hp } };
  if (hp) return { ...state, battle, notice: `Điện Lang mất ${damage} sinh lực.` };
  return { ...state, battle, mode: 'explore', cleared: true, notice: 'Điện Lang đã gục. Tiếp tục về phía đông.' };
}

export function retryEncounter(state, now = 0) {
  if (state.mode !== 'defeat' || !state.checkpoint) return state;
  return { ...state, mode: 'battle', battle: startBattle(now), player: state.checkpoint,
    notice: 'Thử lại từ lúc Điện Lang xuất hiện.' };
}
