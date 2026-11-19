import { RAMPART_GUARD, RAMPART_WOLVES } from './rampart.mjs';

const castDuration = 700;
const castRelease = 330;
const openingDelay = 2940;
const timeBetweenShots = 980;
// Tile-relative positions of the two palms in the mirrored preparation and release cels.
const chargePalm = { col: RAMPART_GUARD.col + .18, row: RAMPART_GUARD.row + .26 };
const releasePalm = { col: RAMPART_GUARD.col + .03, row: RAMPART_GUARD.row + .23 };

function tile(value) {
  return `calc(var(--tile) * ${value})`;
}

function place(node, { col, row }) {
  node.style.left = tile(col);
  node.style.top = tile(row);
}

function cel(index, last, row = 0) {
  return { backgroundPosition: `${index * 100 / last}% ${row}%`, easing: 'steps(1, end)' };
}

export function createRampartDefense(plane, wolves, reducedMotion) {
  const guard = document.createElement('div');
  guard.className = 'field-unit rampart-guard';
  guard.setAttribute('aria-hidden', 'true');
  place(guard, RAMPART_GUARD);
  const shadow = document.createElement('i');
  shadow.className = 'unit-shadow';
  const sprite = document.createElement('i');
  sprite.className = 'guard-art';
  guard.append(shadow, sprite);

  const effects = document.createElement('div');
  effects.className = 'rampart-defense-effects';
  effects.setAttribute('aria-hidden', 'true');
  plane.append(guard, effects);

  const animations = new Set();
  function animate(node, frames, timing, finish) {
    const animation = node.animate(frames, timing);
    animations.add(animation);
    animation.onfinish = () => {
      animations.delete(animation);
      finish?.();
    };
  }

  function clearEffects() {
    for (const animation of animations) {
      animation.onfinish = null;
      animation.cancel();
    }
    animations.clear();
    effects.replaceChildren();
  }

  function effect(kind, point, angle) {
    const node = document.createElement('span');
    node.className = `rampart-moon ${kind}`;
    place(node, point);
    const art = document.createElement('i');
    art.style.rotate = `${angle}rad`;
    node.append(art);
    effects.append(node);
    return { node, art };
  }

  function showImpact(target, angle) {
    const { node, art } = effect('impact', target, angle);
    animate(art, [2, 3, 4, 5, 6, 7].map(index => cel(index, 7, 100)), 175);
    animate(node, [{ opacity: .97 }, { opacity: .9, offset: .62 }, { opacity: 0 }],
      175, () => node.remove());
  }

  function shoot(wolf, target, delay) {
    const dx = target.col - releasePalm.col;
    const dy = target.row - releasePalm.row;
    const angle = Math.atan2(-dy, -dx);
    const duration = Math.round(120 + Math.hypot(dx, dy) * 48);
    const release = delay + castRelease;

    animate(sprite, [
      { ...cel(0, 3), offset: 0 },
      { ...cel(1, 3), offset: 110 / castDuration },
      { ...cel(2, 3), offset: castRelease / castDuration },
      { ...cel(3, 3), offset: 475 / castDuration },
      { ...cel(0, 3), offset: 615 / castDuration },
      { ...cel(0, 3), offset: 1 },
    ], { duration: castDuration, delay });

    const charge = effect('charge', chargePalm, angle);
    animate(charge.node, [
      { opacity: 0, scale: '.2' }, { opacity: .85, scale: '.31' },
    ], { duration: castRelease - 130, delay: delay + 130 }, () => charge.node.remove());

    const blade = effect('blade', releasePalm, angle);
    animate(blade.art, [0, 1, 2, 3, 4, 5, 6, 7].map(index => cel(index, 7)),
      { duration, delay: release });
    animate(blade.node, [
      { translate: '0 0', opacity: 1 },
      { translate: `${tile(dx)} ${tile(dy)}`, opacity: 1 },
    ], { duration, delay: release }, () => {
      blade.node.remove();
      showImpact(target, angle);
      wolf.fall();
    });
  }

  function begin() {
    clearEffects();
    if (reducedMotion.matches) {
      wolves.forEach(wolf => wolf.fall());
      return;
    }
    // Clear the wolf opposite the guard first, then turn on the flanking pair.
    for (const [shot, index] of [1, 0, 2].entries()) {
      const { col, row } = RAMPART_WOLVES[index];
      shoot(wolves[index], { col: col + .52, row: row + .52 }, openingDelay + shot * timeBetweenShots);
    }
  }

  reducedMotion.addEventListener('change', () => {
    if (reducedMotion.matches) begin();
  });
  return { begin };
}
