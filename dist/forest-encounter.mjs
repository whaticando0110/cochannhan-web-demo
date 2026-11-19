import { ACTIONS, createBattle, distance } from './combat.mjs';
import { MAP, isWalkable, toCell, toPoint } from './world.mjs';

export const FOREST_REVEAL = toCell(27, 10);
export const FOREST_FOLLOW = toCell(29, 10);
export const FOREST_SCOUT = toCell(34, 9);
export const FOREST_BOUNDS = Object.freeze({ left: 27, right: 34, top: 5, bottom: 14 });
export const FOREST_PACK = [[34, 7], [37, 8], [38, 10], [34, 12]].map(([col, row]) => toCell(col, row));
export const FOREST_TEAM = [
  { id: 'pine', cell: toCell(35, 8), cast: 570 },
  { id: 'moon', cell: toCell(35, 10), cast: 750 },
  { id: 'raiment', cell: toCell(36, 11), cast: 430 },
];
export const FOREST_ACTIONS = {
  move: ACTIONS.move,
  moon: ACTIONS.moon,
  strike: ACTIONS.strike,
  guard: { ...ACTIONS.guard, name: 'Thủ thế' },
};

export function atForestReveal(cell) {
  const { col, row } = toPoint(cell);
  return col >= 27 && row >= FOREST_BOUNDS.top && row <= FOREST_BOUNDS.bottom;
}

export function atForestAlert(cell) {
  return atForestReveal(cell) && toPoint(cell).col >= 29;
}

const forestArena = {
  ...MAP,
  bounds: FOREST_BOUNDS,
  rocks: new Set(Array.from({ length: MAP.columns * MAP.rows }, (_, cell) => cell).filter(cell => !isWalkable(cell))),
};

const scout = {
  name: 'Điện Lang',
  heavyName: 'Vồ mồi',
  heavyEvery: 2,
  heavyRange: 5,
  heavyDamage: 18,
  strikeName: 'Cắn xé',
  strikeDamage: 10,
  pace: 2,
  victory: 'Điện Lang cuối cùng đã gục.',
  defeat: 'Bạn đã gục trước Điện Lang.',
};

export function startForestBattle(player) {
  const { row } = toPoint(player.cell);
  const candidates = [row, row + 1, row - 1].map(next => toCell(32, next));
  const cell = candidates.find(candidate => {
    const { row } = toPoint(candidate);
    return row >= FOREST_BOUNDS.top && row <= FOREST_BOUNDS.bottom && isWalkable(candidate) &&
      distance(candidate, player.cell, MAP.columns) >= 2;
  }) ?? toCell(33, row);
  return createBattle({
    arena: forestArena, opponent: scout, actions: FOREST_ACTIONS, player,
    rival: { cell, hp: 52, maxHp: 52 },
  });
}

export function forestCheckpoint(value, identity) {
  return value === identity + '|forest-done' || value === identity + '|forest-regroup' ? 'done' : null;
}
