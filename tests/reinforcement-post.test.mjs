import assert from 'node:assert/strict';
import { test } from 'node:test';
import { REAR_POST } from '../dist/beast-king-raid.mjs';
import { FOREST_POST, LEADER_FOREST, canAdvanceRear, rearCheckpoint, reserveRoute } from '../dist/reinforcement-post.mjs';
import { GATE, TERRAIN, TRAIL_ENTRY, toCell } from '../dist/world.mjs';

test('rear-camp progress opens the gate, then the rally point, then the hunt', () => {
  assert.equal(canAdvanceRear('report', GATE, REAR_POST, true), 'report');
  assert.equal(canAdvanceRear('report', REAR_POST, REAR_POST, false), 'gate');
  assert.equal(canAdvanceRear('gate', FOREST_POST, REAR_POST, true), 'gate');
  assert.equal(canAdvanceRear('gate', GATE, REAR_POST, false), 'forest');
  assert.equal(canAdvanceRear('forest', TRAIL_ENTRY, REAR_POST, true), 'forest');
  assert.equal(canAdvanceRear('forest', FOREST_POST, REAR_POST, false), 'forest');
  assert.equal(canAdvanceRear('forest', FOREST_POST, REAR_POST, true), 'trail');
  assert.equal(canAdvanceRear('trail', FOREST_POST, REAR_POST, true), 'trail');
});

test('reload preserves the report and escort checkpoints for the same ceremony only', () => {
  for (const [suffix, stage] of [['rear', 'report'], ['rear-gate', 'gate'], ['rear-forest', 'forest'], ['rear-trail', 'trail']]) {
    assert.equal(rearCheckpoint('ao-reu:29|' + suffix, 'ao-reu:29'), stage);
    assert.equal(rearCheckpoint('ao-reu:29|' + suffix, 'huyen-bao:29'), null);
  }
  assert.equal(rearCheckpoint('ao-reu:29|rear-other', 'ao-reu:29'), null);
  assert.equal(rearCheckpoint('ao-reu:29|aid', 'ao-reu:29'), null);
});

test('the two reserves can take separate stairs and the leader can avoid the player at the rally tile', () => {
  const north = reserveRoute(toCell(11, 12), toCell(5, 9), toCell(5, 11));
  const west = reserveRoute(toCell(11, 14), toCell(5, 12), REAR_POST);
  assert.equal(north.at(-1), toCell(5, 9));
  assert.equal(west.at(-1), toCell(5, 12));
  assert.ok(north.some(cell => TERRAIN[cell].rampart?.stair?.uphill === 'north'));
  assert.ok(west.some(cell => TERRAIN[cell].rampart?.stair?.uphill === 'west'));
  assert.ok(!north.includes(toCell(5, 11)));
  const leading = reserveRoute(GATE + 1, LEADER_FOREST, FOREST_POST);
  assert.equal(leading.at(-1), LEADER_FOREST);
  assert.ok(!leading.includes(FOREST_POST));
  const intoHunt = reserveRoute(LEADER_FOREST, toCell(28, 9), TRAIL_ENTRY);
  assert.equal(intoHunt.at(-1), toCell(28, 9));
  assert.ok(!intoHunt.includes(TRAIL_ENTRY));
});
