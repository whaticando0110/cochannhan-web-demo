import assert from 'node:assert/strict';
import test from 'node:test';
import { ROCKS, actionBlock, coordinate, createBattle, distance, moveTargets, playTurn } from '../dist/combat.mjs';

function step(state, action, cell) {
  const result = playTurn(state, action, cell);
  assert.equal(result.error, '');
  return result.state;
}

test('the first threat is announced and moving outside its marked cells avoids damage', () => {
  const initial = createBattle();
  assert.equal(initial.intent.type, 'heavy');
  assert.equal(coordinate(initial.player.cell), 'C3');
  assert.ok(initial.intent.cells.includes(initial.player.cell));
  const safe = moveTargets(initial).find(cell => !initial.intent.cells.includes(cell));
  const next = step(initial, 'move', safe);
  assert.equal(next.player.cell, safe);
  assert.equal(next.player.hp, initial.player.maxHp);
  assert.equal(next.turn, 2);
  assert.match(next.report[1].text, /Bạn né được/);
  assert.equal(initial.player.cell, 18);
});

test('rocks and the enemy occupy cells and blocked commands preserve the current turn', () => {
  const initial = createBattle();
  const cells = moveTargets(initial);
  assert.ok(cells.every(cell => !ROCKS.includes(cell) && cell !== initial.rival.cell));
  assert.strictEqual(playTurn(initial, 'move', ROCKS[0]).state, initial);
  assert.match(playTurn(initial, 'strike').error, /ngoài tầm/);
  assert.strictEqual(playTurn(initial, 'heal').state, initial);
  assert.match(playTurn(initial, 'constructor').error, /không hợp lệ/);
  const boundary = { ...initial, player: { ...initial.player, cell: 7 } };
  assert.equal(distance(7, 8), 8);
  assert.ok(!moveTargets(boundary).includes(8));
  const beyondRock = { ...initial, player: { ...initial.player, cell: 3 } };
  assert.ok(!moveTargets(beyondRock).includes(19), 'moving straight through a rock takes more than two steps');
});

test('guard reduces damage and restores qi; healing is capped and uses qi', () => {
  const initial = createBattle();
  const guarded = step(initial, 'guard');
  assert.equal(guarded.player.hp, 63);
  assert.equal(guarded.player.qi, 5);
  const healed = step(guarded, 'heal');
  assert.equal(healed.player.hp, 72);
  assert.equal(healed.player.qi, 3);
  assert.equal(healed.rival.cell, 20);
  const empty = { ...initial, player: { ...initial.player, qi: 0 } };
  assert.match(actionBlock(empty, 'moon'), /Thiếu chân nguyên/);
});

test('a complete winning line ends the battle without an enemy counterattack', () => {
  let state = createBattle();
  for (const action of ['guard', 'guard', 'moon', 'moon', 'moon']) state = step(state, action);
  assert.equal(state.result, 'win');
  assert.equal(state.rival.hp, 0);
  assert.equal(state.turn, 5);
  assert.equal(state.intent, null);
  assert.ok(state.events.every(event => event.actor === 'player'));
  assert.strictEqual(playTurn(state, 'move', 20).state, state);
  assert.equal(createBattle().turn, 1);
});

test('remaining in the attack zone can lose the battle and health stops at zero', () => {
  let state = createBattle();
  for (let round = 0; round < 10 && !state.result; round++) {
    const choices = moveTargets(state);
    const unsafe = choices.find(cell => state.intent.cells.includes(cell)) ?? choices[0];
    state = step(state, 'move', unsafe);
  }
  assert.equal(state.result, 'loss');
  assert.equal(state.player.hp, 0);
  assert.equal(state.intent, null);
});
