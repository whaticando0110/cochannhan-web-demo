import assert from 'node:assert/strict';
import { test } from 'node:test';
import { RAID_CUE, RAID_END, REAR_POST, raidFrame, raidProgress } from '../dist/beast-king-raid.mjs';
import { SUPPLY_POST } from '../dist/rampart-lesson.mjs';
import { createWorld, findPath } from '../dist/world.mjs';

test('cutscene checkpoints resume after the stone and distinguish the call for help from reaching the rear', () => {
  const id = 'ao-reu:47';
  assert.equal(raidProgress(null, id), 'lesson');
  assert.equal(raidProgress('ao-reu:46|aid', id), 'lesson');
  assert.equal(raidProgress(id, id), 'scene');
  assert.equal(raidProgress(id + '|scene', id), 'scene');
  assert.equal(raidProgress(id + '|aid', id), 'aid');
  assert.equal(raidProgress(id + '|rear', id), 'rear');
  const world = createWorld();
  const from = { ...world, player: { ...world.player, cell: SUPPLY_POST } };
  assert.equal(findPath(from, REAR_POST).at(-1), REAR_POST);
});

test('the roof ascent, release and guard use the intended mentor poses at contact', () => {
  assert.deepEqual(raidFrame(RAID_CUE.climb).mentor, [8, 11]);
  assert.deepEqual(raidFrame(RAID_CUE.release).mentor, [5, 11]);
  assert.deepEqual(raidFrame(RAID_CUE.release).mentorCel, [4, 2]);
  assert.deepEqual(raidFrame(RAID_CUE.block - 1).mentorCel, [2, 4]);
  assert.deepEqual(raidFrame(RAID_CUE.block).mentorCel, [3, 4]);
  assert.deepEqual(raidFrame(99999), raidFrame(RAID_END));
});

test('the beast uses a distinct frame for impact, recoil, and counterattack with a steady reduced-motion camera', () => {
  const beats = [RAID_CUE.roar, RAID_CUE.wall, RAID_CUE.wound, RAID_CUE.block];
  assert.deepEqual(beats.map(time => raidFrame(time).bossCel), [6, 10, 12, 15]);
  assert.notDeepEqual(raidFrame(0).camera, raidFrame(RAID_CUE.roar).camera);
  assert.equal(raidFrame(RAID_CUE.wound + 35, false, Infinity).bossCel, 16);
  assert.equal(raidFrame(RAID_CUE.wound + 35, false, 35).bossCel, 12);
  const [strikeX, strikeY] = raidFrame(RAID_CUE.block).boss;
  assert.ok(Math.abs(strikeX + 74 * 5.95 / 160 - 5.208) < .01);
  assert.ok(Math.abs(strikeY - 42 * 5.95 / 160 - 11.195) < .01);
  for (const time of beats) {
    assert.deepEqual(raidFrame(time, true).camera, raidFrame(0, true).camera);
    assert.deepEqual(raidFrame(time, true).boss, raidFrame(time).boss);
  }
});
