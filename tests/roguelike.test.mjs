import assert from 'node:assert/strict';
import { test } from 'node:test';
import { moveTargets } from '../dist/combat.mjs';
import {
  advanceRun, canSkipAwakening, FLOORS, rebirthProfile, restoreRun, serializeRun, startRun,
} from '../dist/roguelike.mjs';

const profile = rebirthProfile('huyen-bao', 12);

function apply(run, action, target) {
  const next = advanceRun(run, action, target);
  assert.equal(next.error, '');
  return next.run;
}

function findVictory(run) {
  const queue = [{ run, steps: [] }];
  const seen = new Set();
  for (let index = 0; index < queue.length; index++) {
    const { run, steps } = queue[index];
    const { player, rival, turn } = run.battle;
    const key = [player.cell, player.hp, player.qi, rival.cell, rival.hp, turn % 2].join('|');
    if (seen.has(key) || steps.length >= 16) continue;
    seen.add(key);
    for (const command of [['moon'], ['strike'], ['guard'], ...moveTargets(run.battle).map(cell => ['move', cell])]) {
      const next = advanceRun(run, ...command);
      if (next.error || next.run.phase === 'death') continue;
      const path = [...steps, command];
      if (next.run.phase !== 'battle') return path;
      queue.push({ run: next.run, steps: path });
    }
  }
  return null;
}

test('the outcome from Khai Khiếu sets the initial primeval essence capacity', () => {
  assert.deepEqual([12, 20, 30, 40].map(depth => startRun(rebirthProfile('ao-reu', depth), 1).battle.player.maxQi),
    [4, 5, 6, 7]);
  assert.equal(rebirthProfile('ao-reu', 0), null);
  assert.equal(rebirthProfile('unknown', 27), null);
});

test('each room changes terrain by seed and the seed is reproducible on reload', () => {
  assert.notDeepEqual(startRun(profile, 0).battle.arena.rocks, startRun(profile, 1).battle.arena.rocks);
  const run = apply(startRun(profile, 5), 'moon');
  assert.deepEqual(restoreRun(serializeRun(run)), run);
  assert.equal(restoreRun('corrupt'), null);
  assert.equal(restoreRun(JSON.stringify({ version: 1, hero: 'huyen-bao', depth: 12, seed: 0, log: [['medicine']] })), null);
});

test('all 27 terrain combinations can be cleared at the lowest aptitude', () => {
  const variants = FLOORS.reduce((count, floor) => count * floor.layouts.length, 1);
  for (let seed = 0; seed < variants; seed++) {
    let run = startRun(profile, seed);
    for (const [index, floor] of FLOORS.entries()) {
      assert.equal(run.floor, index);
      assert.equal(run.battle.rival.hp, floor.hp);
      const path = findVictory(run);
      assert.ok(path, `room ${index + 1} is winnable at seed ${seed}`);
      for (const command of path) run = apply(run, ...command);
      if (index === FLOORS.length - 1) break;
      assert.equal(run.phase, 'reward');
      const { hp, maxQi } = run.battle.player;
      run = apply(run, 'stone');
      assert.equal(run.battle.player.hp, hp);
      assert.equal(run.battle.player.qi, maxQi + 1);
      assert.equal(run.battle.turn, 1);
    }
    assert.equal(run.phase, 'victory');
    assert.equal(canSkipAwakening(run), false);
    assert.equal(restoreRun(serializeRun(run)).phase, 'victory');
  }
});

test('only a defeated run unlocks a fresh run with the saved awakening outcome', () => {
  let run = startRun(profile, 2);
  assert.equal(canSkipAwakening(null), false);
  assert.equal(canSkipAwakening(run), false);
  for (let turn = 0; turn < 40 && run.phase === 'battle'; turn++) run = apply(run, 'guard');
  assert.equal(run.phase, 'death');
  run = restoreRun(serializeRun(run));
  assert.equal(canSkipAwakening(run), true);
  const reborn = startRun(run.profile, 3);
  assert.equal(reborn.battle.player.hp, 48);
  assert.equal(reborn.battle.player.qi, profile.maxQi);
  assert.equal(reborn.floor, 0);
  assert.equal(reborn.moonBonus, 0);
  assert.deepEqual(reborn.log, []);
  assert.equal(canSkipAwakening(reborn), false);
});
