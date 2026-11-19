import assert from 'node:assert/strict';
import test from 'node:test';
import { readVillageArrival } from '../dist/village-arrival.mjs';

test('the ceremony URL carries both skins and all four aptitude tiers into the village', () => {
  const saved = JSON.stringify({ hero: 'ao-reu', depth: 49, grade: 'Giáp đẳng', seaPct: 97 });
  const outcomes = [
    [15, 'Đinh đẳng', 29],
    [25, 'Bính đẳng', 49],
    [35, 'Ất đẳng', 69],
    [45, 'Giáp đẳng', 89],
  ];
  for (const hero of ['huyen-bao', 'ao-reu']) {
    for (const [depth, grade, seaPct] of outcomes) {
      assert.deepEqual(readVillageArrival(`?hero=${hero}&depth=${depth}&essence=99`, saved), {
        hero, outcome: { depth, grade, seaPct },
      });
    }
  }
});

test('a direct visit can restore a saved result for the matching skin', () => {
  const saved = JSON.stringify({ hero: 'ao-reu', depth: 49, grade: 'Ất đẳng', seaPct: 1 });
  for (const search of ['', '?hero=ao-reu']) {
    assert.deepEqual(readVillageArrival(search, saved), {
      hero: 'ao-reu', outcome: { depth: 49, grade: 'Giáp đẳng', seaPct: 97 },
    });
  }
  assert.deepEqual(readVillageArrival('?hero=huyen-bao', saved), { hero: 'huyen-bao', outcome: null });
});

test('missing, unfinished and invalid results still allow a direct visit', () => {
  assert.deepEqual(readVillageArrival('', '{'), { hero: 'huyen-bao', outcome: null });
  const saved = JSON.stringify({ hero: 'ao-reu', depth: 49 });
  for (const depth of ['', '3', '-1', '50', '35.5', '1e1']) {
    assert.deepEqual(readVillageArrival(`?hero=ao-reu&depth=${depth}`, saved), {
      hero: 'ao-reu', outcome: null,
    });
  }
});
