import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ABSORB_MS, RELIEF_START, SUPPLY_POST, advanceAbsorption, createLesson, settleTrainingShot, startAbsorption } from '../dist/rampart-lesson.mjs';
import { MOONLIGHT, TERRAIN, TRAINING_POST, createWorld, findPath } from '../dist/world.mjs';

test('the refill stage begins only after a settled shot leaves too little qi to cast again', () => {
  const lesson = createLesson();
  assert.equal(settleTrainingShot(lesson, MOONLIGHT.cost), lesson);
  assert.equal(startAbsorption(lesson, SUPPLY_POST, 32), lesson);
  const refill = settleTrainingShot(lesson, MOONLIGHT.cost - 1);
  assert.equal(refill.phase, 'refill');
  assert.equal(settleTrainingShot(refill, 0), refill);
});

test('the stone can be used once at the supply post, and walking away cancels without using it', () => {
  const refill = settleTrainingShot(createLesson(), 0);
  assert.equal(startAbsorption(refill, TRAINING_POST, 100), refill);
  const absorbing = startAbsorption(refill, SUPPLY_POST, 100);
  assert.equal(startAbsorption(absorbing, SUPPLY_POST, 103), absorbing);
  assert.equal(advanceAbsorption(absorbing, SUPPLY_POST, 100 + ABSORB_MS - 1), absorbing);
  const interrupted = advanceAbsorption(absorbing, TRAINING_POST, 110);
  assert.deepEqual(interrupted, refill);
  const restarted = startAbsorption(interrupted, SUPPLY_POST, 300);
  const complete = advanceAbsorption(restarted, SUPPLY_POST, 300 + ABSORB_MS);
  assert.deepEqual(complete, createLesson(true));
  assert.equal(startAbsorption(complete, SUPPLY_POST, 9000), complete);
  assert.equal(advanceAbsorption(complete, SUPPLY_POST, 9000), complete);
});

test('the relief guard and player have routes across the west stairs without crossing the supply post', () => {
  function route(from, to, avoidCell) {
    const world = createWorld();
    return findPath({ ...world, player: { ...world.player, cell: from } }, to, avoidCell);
  }
  const returning = route(TRAINING_POST, SUPPLY_POST, RELIEF_START);
  const replacing = route(RELIEF_START, TRAINING_POST, SUPPLY_POST);
  assert.equal(returning.at(-1), SUPPLY_POST);
  assert.equal(replacing.at(-1), TRAINING_POST);
  assert.ok(!replacing.includes(SUPPLY_POST));
  for (const path of [returning, replacing]) {
    assert.equal(path.filter(cell => TERRAIN[cell].rampart?.stair?.uphill === 'west').length, 2);
  }
});
