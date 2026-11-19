import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { moveTargets, playTurn } from '../dist/combat.mjs';
import {
  FOREST_BOUNDS, FOREST_FOLLOW, FOREST_TALK, atForestAlert, atForestReveal, forestCheckpoint, startForestBattle,
} from '../dist/forest-encounter.mjs';
import { createWorld, findPath, isWalkable, toCell, walk } from '../dist/world.mjs';

test('the forest chapter reveals the team before the alert and bypasses the real-time encounter', () => {
  const world = createWorld();
  world.player.cell = toCell(27, 10);
  assert.equal(atForestReveal(world.player.cell), true);
  assert.equal(atForestAlert(world.player.cell), false);
  const next = walk(world, toCell(28, 10), 0, { hunt: false });
  assert.equal(next.mode, 'explore');
  assert.equal(atForestAlert(FOREST_FOLLOW), true);
  assert.equal(walk(world, toCell(28, 10)).mode, 'battle');
});

test('every entry row gives the player a safe first move and access to the regroup point', () => {
  const world = createWorld();
  for (let row = FOREST_BOUNDS.top; row <= FOREST_BOUNDS.bottom; row++) {
    const cell = toCell(29, row);
    assert.equal(isWalkable(cell), true);
    const battle = startForestBattle({ ...world.player, cell });
    assert.equal(battle.intent.type, 'heavy');
    const safe = moveTargets(battle).find(target => !battle.intent.cells.includes(target));
    assert.notEqual(safe, undefined, `row ${row}`);
    assert.equal(playTurn(battle, 'move', safe).state.player.hp, world.player.hp);
    assert.equal(findPath({ ...world, player: { ...world.player, cell } }, FOREST_TALK).at(-1), FOREST_TALK);
  }
});

test('the tutorial supports a win, a loss, and a clean retry from the original player snapshot', () => {
  const player = { ...createWorld().player, cell: FOREST_FOLLOW, qi: 6 };
  const initial = startForestBattle(player);
  let state = playTurn(initial, 'move', toCell(30, 9)).state;
  state = playTurn(state, 'moon').state;
  state = playTurn(state, 'moon').state;
  assert.equal(state.result, 'win');
  assert.equal(state.rival.hp, 0);
  assert.equal(state.player.hp, player.hp);
  state = startForestBattle({ ...player, hp: 1 });
  assert.equal(playTurn(state, 'guard').state.result, 'loss');
  assert.deepEqual(startForestBattle(player), initial);
  assert.equal(forestCheckpoint('ao-reu:45|forest-regroup', 'ao-reu:45'), 'regroup');
  assert.equal(forestCheckpoint('ao-reu:45|forest-done', 'ao-reu:45'), 'done');
  assert.equal(forestCheckpoint('ao-reu:45|forest-done', 'huyen-bao:45'), null);
});

test('the deployed team manifest resolves all three runtime sprite atlases', () => {
  const base = new URL('../dist/assets/forest-support/', import.meta.url);
  const metadata = JSON.parse(readFileSync(new URL('team-motion.json', base), 'utf8'));
  assert.deepEqual(Object.keys(metadata).sort(), ['moon', 'pine', 'raiment']);
  for (const actor of Object.values(metadata)) {
    const png = readFileSync(new URL(actor.file, base));
    assert.deepEqual([png.readUInt32BE(16), png.readUInt32BE(20)], [512, 384]);
    const clip = actor.clips.skill;
    assert.equal(clip.frames[clip.times.indexOf(clip.releaseAt)], clip.releaseFrame);
  }
});
