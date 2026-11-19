import assert from 'node:assert/strict';
import test from 'node:test';
import { neighbors } from '../dist/combat.mjs';
import atlas from '../dist/assets/rampart/atlas.mjs';
import { chooseRampartFrame, EAST_CORNER, RAMPART_EDGE, RAMPART_GUARD, RAMPART_WOLVES, STAIRS } from '../dist/rampart.mjs';
import {
  CONTINUE, GATE, MAP, SPAWN, TERRAIN, TRAIL_ENTRY, WOLF,
  advanceHunt, clearShot, createWorld, findPath, hitHunt, insideHunt, isWalkable, locationOf, retryEncounter, toCell, toPoint, walk, TRAINING_POST,
} from '../dist/world.mjs';

function enterHunt() {
  let world = createWorld();
  for (const tile of findPath(world, TRAIL_ENTRY)) world = walk(world, tile);
  return world;
}

test('wolves approach the clear strip to the west of the palisade', () => {
  const world = createWorld();
  for (const { col, row, startCol } of RAMPART_WOLVES) {
    assert.ok(startCol < col);
    assert.equal(TERRAIN[toCell(col, row)].rampart.family, 'mud');
    assert.equal(TERRAIN[toCell(col - 1, row)].rampart.ornaments.length, 0);
    assert.equal(isWalkable(toCell(col + 1, row)), false);
    assert.equal(TERRAIN[toCell(col + 2, row)].rampart.elevation, 1);
    assert.deepEqual(findPath(world, toCell(col, row)), []);
  }
});

test('the west palisade runs longer than the north palisade and joins the south wall', () => {
  const westCol = RAMPART_WOLVES[0].col + 1;
  const southRow = MAP.rows - 3;
  assert.ok(southRow - 4 > RAMPART_EDGE - westCol);
  for (let row = 5; row < southRow; row++) {
    assert.equal(TERRAIN[toCell(westCol, row)].rampart.ornaments[0].frame, 'palisade-west');
    assert.equal(isWalkable(toCell(westCol, row)), false);
  }
  for (let col = westCol; col <= RAMPART_EDGE; col++) {
    assert.equal(isWalkable(toCell(col, southRow)), false);
  }
});

test('the guard occupies the raised west deck and leaves room to walk past', () => {
  const { col, row } = RAMPART_GUARD;
  const guardCell = toCell(col, row);
  assert.equal(TERRAIN[guardCell].rampart.elevation, 1);
  assert.equal(isWalkable(guardCell), false);
  assert.equal(isWalkable(toCell(col + 1, row)), true);
  const world = createWorld();
  const beforePost = { ...world, player: { ...world.player, cell: toCell(col, row - 1) } };
  const route = findPath(beforePost, toCell(col, row + 1));
  assert.ok(route.includes(toCell(col + 1, row)));
  assert.ok(!route.includes(guardCell));
});

test('the path across the village gate leads through the forest on the same large grid', () => {
  let world = createWorld();
  const path = findPath(world, TRAIL_ENTRY);
  assert.equal(TERRAIN.length, 42 * 26);
  assert.equal(world.player.cell, SPAWN);
  assert.ok(path.includes(GATE));
  assert.ok(path.every(isWalkable));
  for (const cell of path.slice(0, -1)) {
    assert.ok(neighbors(world.player.cell, MAP).includes(cell));
    world = walk(world, cell);
    assert.equal(world.mode, 'explore');
  }
  assert.equal(locationOf(world.player.cell), 'Đường rừng');
  assert.equal(toPoint(world.player.cell).col, 27);
});

test('walls block direct movement, and the village has space to explore off the road', () => {
  const world = createWorld();
  const atGateside = { ...world, player: { ...world.player, cell: toCell(13, 8) } };
  const wall = toCell(14, 8);
  assert.equal(isWalkable(wall), false);
  assert.strictEqual(walk(atGateside, wall), atGateside);
  assert.deepEqual(findPath(atGateside, wall), []);
  assert.ok(findPath(world, toCell(8, 7)).length > 0);
  assert.strictEqual(walk(world, CONTINUE), world);
});

test('the northeast timber return forms a continuous outer wall and leaves the east gate open', () => {
  for (let row = 4; row <= 8; row++) {
    const wall = toCell(EAST_CORNER, row);
    assert.equal(isWalkable(wall), false);
    const [ornament] = TERRAIN[wall].rampart.ornaments;
    assert.equal(ornament.frame, row === 4 || row === 8 ? 'palisade-corner-nw' : 'palisade-west');
  }
  for (const row of [4, 8]) assert.equal(isWalkable(toCell(RAMPART_EDGE, row)), false);
  assert.ok(isWalkable(toCell(RAMPART_EDGE, 6)));
  assert.ok(isWalkable(toCell(EAST_CORNER, 10)));
  const world = createWorld();
  assert.equal(walk(world, toCell(8, 10)).player.cell, toCell(8, 10));
  assert.ok(findPath(world, TRAIL_ENTRY).includes(GATE));
});

test('both modeled stairs connect the ground and the rampart in both directions', () => {
  for (const stair of STAIRS) {
    const isNorth = stair.uphill === 'north';
    const lower = isNorth ? toCell(stair.col + 1, stair.row + stair.height) : toCell(stair.col + stair.width, stair.row + 1);
    const upper = isNorth ? toCell(stair.col + 1, stair.row - 1) : toCell(stair.col - 1, stair.row + 1);
    const world = createWorld();
    const start = { ...world, player: { ...world.player, cell: lower } };
    const climb = findPath(start, upper);
    assert.equal(climb.length, (isNorth ? stair.height : stair.width) + 1);
    let current = start;
    for (const cell of climb.slice(0, -1)) {
      assert.equal(TERRAIN[cell].rampart.stair, stair);
      current = walk(current, cell);
      const side = isNorth ? 1 : MAP.columns;
      for (const rail of [cell - side, cell + side]) {
        assert.equal(isWalkable(rail), false);
        assert.strictEqual(walk(current, rail), current);
        assert.deepEqual(findPath(world, rail), []);
      }
    }
    current = walk(current, upper);
    assert.equal(current.player.cell, upper);
    assert.equal(TERRAIN[upper].rampart.elevation, 1);
    for (const cell of findPath(current, lower)) current = walk(current, cell);
    assert.equal(current.player.cell, lower);
  }
});

test('a flat elevation edge and the side of a stair block direct steps', () => {
  const world = createWorld();
  const startingAt = cell => ({ ...world, player: { ...world.player, cell } });
  const besideDeck = startingAt(toCell(8, 7));
  assert.strictEqual(walk(besideDeck, toCell(8, 6)), besideDeck);
  const besideStair = startingAt(toCell(9, 8));
  assert.strictEqual(walk(besideStair, toCell(10, 8)), besideStair);
  const blockedFence = startingAt(toCell(7, 5));
  assert.strictEqual(walk(blockedFence, toCell(7, 4)), blockedFence);
  assert.ok(findPath(besideDeck, toCell(8, 6)).length > 2);
});

test('seeded texture variation is reproducible and runtime frames cover the complete atlas', () => {
  const world = createWorld({ seed: 123 });
  const choose = seed => TERRAIN.flatMap(({ rampart }, cell) =>
    rampart ? [chooseRampartFrame(rampart.family, cell, seed)] : []);
  assert.equal(Object.keys(atlas.sheets).length, 3);
  assert.equal(Object.keys(atlas.frames).length, 30);
  assert.deepEqual(choose(world.seed), choose(123));
  assert.notDeepEqual(choose(123), choose(991));
  for (const [, frame] of Object.entries(atlas.frames)) {
    const sheet = atlas.sheets[frame.sheet];
    assert.ok(frame.x + frame.width <= sheet.width);
    assert.ok(frame.y + frame.height <= sheet.height);
  }
});

test('the training post is on the upper deck and is reachable from the village spawn', () => {
  assert.equal(TERRAIN[TRAINING_POST].rampart.elevation, 1);
  assert.equal(findPath(createWorld(), TRAINING_POST).at(-1), TRAINING_POST);
});

test('the hunt advances on its own clock while the player is free to walk out of a pounce', () => {
  const initial = enterHunt();
  assert.equal(initial.mode, 'battle');
  assert.equal(initial.player.cell, TRAIL_ENTRY);
  assert.equal(initial.battle.rival.cell, WOLF);
  assert.strictEqual(advanceHunt(initial, 949).state, initial);
  const approach = advanceHunt(initial, 950);
  assert.equal(approach.event.type, 'move');
  const warn = advanceHunt(approach.state, 1500).state;
  assert.ok(warn.battle.intent.cells.includes(TRAIL_ENTRY));
  assert.strictEqual(advanceHunt(warn, 2449).state, warn);
  const step = toCell(28, 9);
  let dodging = walk(warn, step, 1700);
  dodging = walk(dodging, toCell(28, 8), 2150);
  assert.equal(dodging.player.cell, toCell(28, 8));
  assert.equal(advanceHunt(dodging, 2450).state.player.hp, initial.player.hp);
  assert.equal(advanceHunt(warn, 2450).state.player.hp, 35);
  assert.strictEqual(walk(warn, toCell(27, 10)), warn);
});

test('a projectile only hits the wolf if it still occupies the targeted cell', () => {
  const world = enterHunt();
  assert.equal(clearShot(world.player.cell, WOLF), true);
  assert.equal(clearShot(toCell(28, 8), toCell(31, 8)), false);
  const approaching = advanceHunt(world, 950).state;
  assert.strictEqual(hitHunt(approaching, WOLF, 26), approaching);
  const opening = hitHunt(world, WOLF, 26);
  assert.equal(opening.battle.rival.hp, 26);
  const victory = hitHunt(opening, WOLF, 26);
  assert.equal(victory.mode, 'explore');
  assert.equal(victory.cleared, true);
  let onward = victory;
  for (const tile of findPath(onward, CONTINUE)) onward = walk(onward, tile);
  assert.equal(onward.reached, true);
  assert.equal(onward.mode, 'explore');
  for (const tile of findPath(onward, TRAIL_ENTRY)) onward = walk(onward, tile);
  assert.equal(onward.mode, 'explore');
  assert.equal(onward.player.cell, TRAIL_ENTRY);
});

test('retry restores health, position and real-time deadlines from the hunt checkpoint', () => {
  const initial = enterHunt();
  let world = initial;
  for (let tick = 1; tick < 20 && world.mode === 'battle'; tick++) world = advanceHunt(world, tick * 2000).state;
  assert.equal(world.mode, 'defeat');
  const retry = retryEncounter(world, 20000);
  assert.equal(retry.mode, 'battle');
  assert.equal(retry.battle.nextAt, 20950);
  assert.equal(retry.battle.intent, null);
  assert.deepEqual(retry.player, initial.player);
  assert.equal(retry.battle.rival.hp, 52);
});