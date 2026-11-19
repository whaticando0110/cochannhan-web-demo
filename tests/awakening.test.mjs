import test from 'node:test';
import assert from 'node:assert/strict';
import {
  aptitude, baseStepMs, createCeremony, finalDepth, hopeCells, minAwakeningDepth,
  move, routeTo, seaEssenceLabel, seaEssenceRatio, stepPace, width,
} from '../dist/awakening-rules.mjs';

function go(state, x, y) {
  return routeTo(state, x, y).reduce((current, [col, row]) => move(current, col, row), state);
}

test('ceremony aptitude follows the novel thresholds at each boundary', () => {
  assert.deepEqual([0, 9, 10, 19, 20, 27, 29, 30, 39, 40, 43, 49].map(aptitude), [
    'Chưa khai khiếu', 'Chưa khai khiếu', 'Đinh đẳng', 'Đinh đẳng', 'Bính đẳng',
    'Bính đẳng', 'Bính đẳng', 'Ất đẳng', 'Ất đẳng', 'Giáp đẳng', 'Giáp đẳng', 'Giáp đẳng',
  ]);
});

test('the ford connects the banks, lateral moves do not add depth and hope is gathered once', () => {
  const starting = createCeremony({ limit: 27 });
  assert.deepEqual(routeTo(starting, 4, 3), []);
  const bank = go(starting, 6, 4);
  assert.equal(bank.depth, 0);
  const hope = go(bank, 8, 4);
  assert.equal(hope.depth, 2);
  const sideways = move(hope, 8, 3);
  assert.equal(sideways.depth, 2);
  const revisit = move(sideways, 8, 4);
  assert.equal(revisit.gathered.length, 1);
  assert.equal(move(revisit, 7, 4).depth, 2);
});

test('walking gradually slows down approaching the random awakening limit and halts', () => {
  const state = createCeremony({ limit: 27 });
  assert.equal(stepPace(state, 10), baseStepMs);
  assert.equal(stepPace(state, 6 + 22), baseStepMs);
  assert.ok(stepPace(state, 6 + 23) > baseStepMs);
  assert.ok(stepPace(state, 6 + 25) > stepPace(state, 6 + 24));
  assert.ok(stepPace(state, 6 + 27) > stepPace(state, 6 + 26));

  const halted = go(state, 6 + 27, 4);
  assert.equal(halted.finished, true);
  assert.equal(halted.depth, 27);
  assert.equal(aptitude(halted.depth), 'Bính đẳng');
  assert.strictEqual(move(halted, 6 + 28, 4), halted);
});

test('random ceremony roll opens an aperture and sea essence matches canonical tiers', () => {
  for (let i = 0; i < 40; i++) {
    const rolled = createCeremony();
    assert.ok(rolled.limit >= minAwakeningDepth && rolled.limit <= finalDepth);
  }
  const full = go(createCeremony({ limit: finalDepth }), 6 + finalDepth, 4);
  assert.equal(full.finished, true);
  assert.equal(aptitude(full.depth), 'Giáp đẳng');
  assert.ok(seaEssenceRatio(15) >= 0.2 && seaEssenceRatio(15) < 0.4);
  assert.ok(seaEssenceRatio(27) >= 0.4 && seaEssenceRatio(27) < 0.6);
  assert.ok(seaEssenceRatio(35) >= 0.6 && seaEssenceRatio(35) < 0.8);
  assert.ok(seaEssenceRatio(49) >= 0.8 && seaEssenceRatio(49) < 1.0);
  assert.match(seaEssenceLabel(27), /thành/);
  assert.equal(hopeCells.length, 7);
});
