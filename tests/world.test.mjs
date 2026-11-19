import assert from 'node:assert/strict';
import test from 'node:test';
import { moveTargets, neighbors } from '../dist/combat.mjs';
import {
  CONTINUE, GATE, MAP, SPAWN, TERRAIN, TRAIL_ENTRY, WOLF,
  createWorld, fight, findPath, insideHunt, isWalkable, locationOf, retryEncounter, toCell, toPoint, walk,
} from '../dist/world.mjs';

function enterHunt() {
  let world = createWorld();
  for (const tile of findPath(world, TRAIL_ENTRY)) world = walk(world, tile);
  return world;
}

test('the path across the village gate leads through the forest on the same large grid', () => {
  let world = createWorld();
  const path = findPath(world, TRAIL_ENTRY);
  assert.equal(TERRAIN.length, 42 * 20);
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

test('entering the encounter preserves the arrival cell and uses terrain from the same map', () => {
  const world = enterHunt();
  assert.equal(world.mode, 'battle');
  assert.equal(world.player.cell, TRAIL_ENTRY);
  assert.equal(world.battle.player.cell, TRAIL_ENTRY);
  assert.equal(world.battle.rival.cell, WOLF);
  assert.equal(world.battle.intent.name, 'Vồ mồi');
  assert.ok(world.battle.intent.cells.includes(world.player.cell));
  const targets = moveTargets(world.battle);
  assert.ok(targets.every(cell => insideHunt(cell) && isWalkable(cell) && cell !== WOLF));
  assert.strictEqual(walk(world, targets[0]), world);
  const valid = targets.find(cell => !world.battle.intent.cells.includes(cell));
  const dodge = fight(world, 'move', valid);
  assert.equal(dodge.error, '');
  assert.equal(dodge.state.player.hp, world.player.hp);
});

test('defeating the wolf resumes free movement and crossing the clearing again stays neutral', () => {
  const world = enterHunt();
  const opening = fight(world, 'moon');
  assert.equal(opening.error, '');
  assert.equal(opening.state.battle.rival.hp, 21);
  const victory = fight(opening.state, 'moon').state;
  assert.equal(victory.mode, 'explore');
  assert.equal(victory.cleared, true);
  assert.equal(victory.player.cell, TRAIL_ENTRY);
  assert.equal(victory.player.qi, 0);
  assert.equal(victory.player.hp, 31);
  let onward = victory;
  for (const tile of findPath(onward, CONTINUE)) onward = walk(onward, tile);
  assert.equal(onward.reached, true);
  assert.equal(onward.mode, 'explore');
  for (const tile of findPath(onward, TRAIL_ENTRY)) onward = walk(onward, tile);
  assert.equal(onward.mode, 'explore');
  assert.equal(onward.player.cell, TRAIL_ENTRY);
});

test('retry restores the encounter without walking from the village again', () => {
  const initial = enterHunt();
  let world = initial;
  for (let turn = 0; turn < 20 && world.mode === 'battle'; turn++) world = fight(world, 'guard').state;
  assert.equal(world.mode, 'defeat');
  const retry = retryEncounter(world);
  assert.equal(retry.mode, 'battle');
  assert.equal(retry.battle.turn, 1);
  assert.deepEqual(retry.player, initial.player);
  assert.equal(retry.battle.rival.hp, 47);
});
