import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createWolfMotion } from '../dist/wolf-motion.mjs';

function motionFixture() {
  function element() {
    const active = [];
    return {
      active,
      style: { setProperty(name, value) { this[name] = value; } },
      animate(frames, timing) {
        const animation = { frames, timing, cancel() { this.cancelled = true; } };
        active.push(animation);
        return animation;
      },
    };
  }
  const unit = element();
  const sprite = element();
  const impact = element();
  unit.querySelector = () => sprite;
  const preference = {
    matches: false,
    addEventListener(_, listener) { this.change = listener; },
  };
  return { unit, sprite, impact, preference, motion: createWolfMotion(unit, preference, impact) };
}

test('rampart wolf mirrors toward its destination and runs for the same time as it travels', () => {
  const { unit, sprite, motion } = motionFixture();
  motion.run(-4, .5, { duration: 1500, delay: 280 });
  const [travel] = unit.active;
  const [run] = sprite.active;
  assert.equal(unit.style['--face'], 1);
  assert.equal(travel.frames[0].translate, '-400% 50%');
  assert.equal(run.timing.delay, travel.timing.delay);
  assert.equal(run.timing.iterations * run.timing.duration, travel.timing.duration);
  run.onfinish();
  assert.equal(travel.cancelled, true);
  assert.equal(sprite.active.at(-1).timing.iterations, Infinity);
});

test('reset discards a pending reaction and reduced motion still completes a recoil', () => {
  const { sprite, preference, motion } = motionFixture();
  let responses = 0;
  const after = () => { responses++; };
  motion.play('hit', { direction: [-1, 0], after });
  const firstHit = sprite.active.at(-1);
  assert.equal(firstHit.frames[0].translate, '-10% 0%');
  motion.stop();
  assert.equal(firstHit.onfinish, null);
  assert.equal(firstHit.cancelled, true);
  motion.play('hit', { after });
  preference.matches = true;
  preference.change();
  assert.equal(responses, 1);
  assert.equal(sprite.style.backgroundPosition, '0% 0%');
});

test('the sustained attack starts on arrival and splinters coincide with wall contact', () => {
  const { unit, sprite, impact, preference, motion } = motionFixture();
  const approach = () => motion.run(-4, 0, { after: motion.attackWall });
  approach();
  assert.equal(impact.active.length, 0);
  sprite.active.at(-1).onfinish();

  const attack = sprite.active.at(-1);
  const dust = impact.active.at(-1);
  assert.equal(attack.timing.iterations, Infinity);
  assert.deepEqual(dust.timing, { duration: attack.timing.duration, iterations: Infinity });
  assert.equal(dust.frames[1].offset, attack.frames[2].offset);

  preference.matches = true;
  preference.change();
  assert.equal(attack.cancelled, true);
  assert.equal(dust.cancelled, true);
  assert.equal(impact.active.length, 1);
  preference.matches = false;
  preference.change();
  assert.equal(impact.active.length, 2);

  approach();
  assert.equal(impact.active.at(-1).cancelled, true);
  assert.equal(unit.active.length, 2);
  assert.notEqual(sprite.active.at(-1).timing.iterations, Infinity);
});
