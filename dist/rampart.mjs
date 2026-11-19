import atlas from './assets/rampart/atlas.mjs';

export const RAMPART_EDGE = 14;
export const STAIRS = Object.freeze([
  {
    frame: 'stairs-up-north', col: 9, row: 7, width: 3, height: 2, uphill: 'north',
  },
  {
    frame: 'stairs-up-west', col: 6, row: 11, width: 2, height: 3, uphill: 'west',
  },
]);

const fenceCol = 3;
const fenceRow = 4;
const deckBottom = 6;
const deckRight = 5;

export const RAMPART_FOREST_WIDTH = 5;
export const RAMPART_WOLVES = Object.freeze([
  { col: fenceCol - 1, row: 7, startCol: -2.6, startRow: 6.1 },
  { col: fenceCol - 1, row: 10, startCol: -2, startRow: 10.2 },
  { col: fenceCol - 1, row: 13, startCol: -3.3, startRow: 14.2 },
]);

export function westForestFamily(col, row) {
  const distance = Math.abs(row - 11);
  const fringe = distance < 4 ? -3 : distance <= 7 ? -1 : 2;
  return col < fringe ? 'bamboo' : 'mud';
}

function stairAt(col, row) {
  return STAIRS.find(stair =>
    col >= stair.col && col < stair.col + stair.width && row >= stair.row && row < stair.row + stair.height
  );
}

export function rampartTile(col, row, mapRows, gateRow) {
  const entrance = Math.abs(row - gateRow) <= 1;
  const boundary = row === 0 || row === mapRows - 1 || col === 0;
  const southWall = mapRows - 3;
  const westFace = col < fenceCol && row > fenceRow && row < southWall;
  const canopy = westFace ? westForestFamily(col, row) === 'bamboo' : col <= 1 || row <= 1 || row === mapRows - 1;
  const inside = row > fenceRow && row < southWall && col > fenceCol;
  const stair = stairAt(col, row);
  const rail = stair && (stair.uphill === 'north' ? col !== stair.col + 1 : row !== stair.row + 1);
  const wolfAtRest = RAMPART_WOLVES.some(wolf => col === wolf.col && row === wolf.row);
  let family = inside ? 'stone' : canopy ? 'bamboo' : 'mud';
  let elevation = 0;
  let blocked = boundary || canopy || wolfAtRest;
  const ornaments = [];

  if ((row === fenceRow || row === southWall) && col >= fenceCol) {
    const corner = col === fenceCol || col === RAMPART_EDGE;
    ornaments.push({
      frame: corner ? 'palisade-corner-nw' : 'palisade-north',
      flip: col === RAMPART_EDGE, flipY: row === southWall,
    });
    blocked = true;
  } else if (col === fenceCol && row > fenceRow && row < southWall) {
    ornaments.push({ frame: 'palisade-west' });
    blocked = true;
  } else if (col === RAMPART_EDGE && row > fenceRow && row < southWall && !entrance) {
    ornaments.push({ frame: 'palisade-west', flip: true });
    blocked = true;
  } else if (inside && !boundary && col < RAMPART_EDGE) {
    if (row <= deckBottom || col <= deckRight) {
      family = row <= deckBottom ? 'deck-east' : 'deck-south';
      elevation = 1;
    } else if (!stair || rail) {
      if (row === deckBottom + 1) ornaments.push({ frame: 'platform-edge-south' });
      if (col === deckRight + 1) ornaments.push({ frame: 'platform-edge-east' });
    }
  }

  if (!inside && !canopy) {
    if (row === 2) ornaments.push({ frame: 'bamboo-edge-south' });
    if (col === 2 && (!westFace || westForestFamily(col - 1, row) === 'bamboo')) {
      ornaments.push({ frame: 'bamboo-edge-east' });
    }
  }
  if (stair && stair.col === col && stair.row === row) ornaments.push(stair);
  if (boundary && !westFace) family = 'bamboo';
  if (col === RAMPART_EDGE && entrance) family = 'stone';
  return { family, elevation, blocked: blocked || Boolean(rail), stair, ornaments };
}

export function chooseRampartFrame(family, cell, seed) {
  const list = atlas.families[family];
  const value = Math.imul(cell + 1, 0x45d9f3b) ^ seed;
  const shuffled = Math.imul(value ^ (value >>> 15), 0x7feb352d) >>> 0;
  return list[(shuffled >>> 9) % list.length];
}

export function stairConnects(stair, stairPoint, flatPoint, elevation) {
  if (stair.uphill === 'north' && stairPoint.col === flatPoint.col) {
    return (flatPoint.row === stair.row - 1 && elevation === 1) ||
      (flatPoint.row === stair.row + stair.height && elevation === 0);
  }
  if (stair.uphill === 'west' && stairPoint.row === flatPoint.row) {
    return (flatPoint.col === stair.col - 1 && elevation === 1) ||
      (flatPoint.col === stair.col + stair.width && elevation === 0);
  }
  return false;
}
