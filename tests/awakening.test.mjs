import test from 'node:test';
import assert from 'node:assert/strict';
import { aptitude, createCeremony, finalDepth, hopeCells, move, routeTo, width } from '../dist/awakening-rules.mjs';

function go(state, x, y) {
  return routeTo(state, x, y).reduce((current, [col, row]) => move(current, col, row), state);
}

test('ceremony aptitude follows the novel thresholds at each boundary', () => {
  assert.deepEqual([0, 9, 10, 19, 20, 27, 29, 30, 39, 40, 43, 49].map(aptitude), [
    'Chưa khai khiếu', 'Chưa khai khiếu', 'Đinh đẳng', 'Đinh đẳng', 'Bính đẳng',
    'Bính đẳng', 'Bính đẳng', 'Ất đẳng', 'Ất đẳng', 'Giáp đẳng', 'Giáp đẳng', 'Giáp đẳng',
  ]);
});

test('the ford connects the banks, lateral moves do not add depth and hope cannot be farmed', () => {
  const starting = createCeremony();
  assert.deepEqual(routeTo(starting, 4, 3), []);
  const bank = go(starting, 6, 4);
  assert.equal(bank.depth, 0);
  const hope = go(bank, 8, 4);
  assert.equal(hope.depth, 2);
  const sideways = move(hope, 8, 3);
  assert.equal(sideways.depth, 2);
  const revisit = move(sideways, 8, 4);
  assert.equal(revisit.gathered.length, 1);
  assert.equal(revisit.resolve, hope.resolve - 2);
  assert.equal(move(revisit, 7, 4).depth, 2);
});

test('pressure stops a straight route but a planned route through the clusters reaches Giáp', () => {
  const exhausted = go(go(createCeremony(), 6, 2), 55, 2);
  assert.equal(exhausted.finished, true);
  assert.equal(aptitude(exhausted.depth), 'Bính đẳng');
  assert.equal(exhausted.resolve, 0);
  const restored = hopeCells.reduce((state, id) =>
    go(state, id % width, Math.floor(id / width)), createCeremony());
  assert.equal(restored.gathered.length, hopeCells.length);
  const completed = go(restored, 55, 4);
  assert.equal(completed.finished, true);
  assert.equal(completed.depth, finalDepth);
  assert.equal(aptitude(completed.depth), 'Giáp đẳng');
  assert.strictEqual(move(completed, 54, 4), completed);
});
