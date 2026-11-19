import { aptitude, finalDepth, seaEssenceRatio } from './awakening-rules.mjs';

function isHero(value) {
  return value === 'huyen-bao' || value === 'ao-reu';
}

export function readVillageArrival(search, savedOutcome = null) {
  const query = new URLSearchParams(search);
  const selectedHero = query.get('hero');
  const requestedDepth = query.get('depth');
  let saved;
  try {
    const value = JSON.parse(savedOutcome);
    if (isHero(value?.hero) && (selectedHero === null || selectedHero === value.hero)) saved = value;
  } catch {
    // A direct visit can still open the village after storage is cleared or corrupted.
  }

  const hero = isHero(selectedHero) ? selectedHero : saved?.hero ?? 'huyen-bao';
  const depth = requestedDepth === null ? saved?.depth
    : /^\d+$/.test(requestedDepth) ? Number(requestedDepth) : undefined;
  const ratio = Number.isInteger(depth) && depth <= finalDepth ? seaEssenceRatio(depth) : 0;

  return {
    hero,
    outcome: ratio > 0 ? { depth, grade: aptitude(depth), seaPct: Math.round(ratio * 100) } : null,
  };
}
