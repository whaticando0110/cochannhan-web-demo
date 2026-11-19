import { RAMPART_GUARD, RAMPART_INSTRUCTOR, RAMPART_MOONWHIRL_GUARD, RAMPART_WOLVES } from './rampart.mjs';
import { MOONLIGHT } from './world.mjs';

const wolfMaxHp = 52;
const castDuration = 690;
const releaseTime = 330;
const midpoint = 1;
const targets = RAMPART_WOLVES.map(({ col, row }) => ({ col: col + .52, row: row + .52 }));

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

function addGuard(plane, post, style) {
  const guard = document.createElement('div');
  guard.className = `field-unit rampart-guard ${style}`;
  guard.setAttribute('aria-hidden', 'true');
  place(guard, post);
  const shadow = document.createElement('i');
  shadow.className = 'unit-shadow';
  const sprite = document.createElement('i');
  sprite.className = 'guard-art';
  guard.append(shadow, sprite);
  plane.append(guard);
  return sprite;
}

export function updateWolfHealth(unit, hp, maxHp) {
  const meter = unit.querySelector('.wolf-health');
  meter.max = maxHp;
  meter.value = hp;
  meter.hidden = hp === 0;
}

export function createRampartDefense(plane, wolves, reducedMotion, onHit) {
  const guard = addGuard(plane, RAMPART_GUARD, 'sand-guard');
  const whirlGuard = addGuard(plane, RAMPART_MOONWHIRL_GUARD, 'slate-guard');
  const needleGuard = addGuard(plane, RAMPART_INSTRUCTOR, 'indigo-guard');
  const effects = document.createElement('div');
  effects.className = 'rampart-defense-effects';
  effects.setAttribute('aria-hidden', 'true');
  plane.append(effects);
  const animations = new Set();
  let health;

  function animate(node, frames, timing, finish) {
    const animation = node.animate(frames, timing);
    animations.add(animation);
    animation.onfinish = () => {
      animations.delete(animation);
      finish?.();
    };
  }

  function effect(kind, point, angle = 0) {
    const node = document.createElement('span');
    node.className = `rampart-moon ${kind}`;
    place(node, point);
    const art = document.createElement('i');
    art.style.rotate = `${angle}rad`;
    node.append(art);
    effects.append(node);
    return { node, art };
  }

  function showContact(target, angle, direction, kind) {
    if (reducedMotion.matches) return;
    const impact = effect(`${kind} impact`, target, angle);
    const frames = kind === 'moonlight' ? [2, 3, 4, 5, 6, 7] : [0, 1, 2, 3];
    animate(impact.art, frames.map(index => cel(index, 7, 100)), 165);
    animate(impact.node, [{ opacity: .96 }, { opacity: 0 }], 165, () => impact.node.remove());

    const blood = effect('blood', target);
    blood.art.style.setProperty('--blood-facing', direction < 0 ? '-1' : '1');
    animate(blood.art, [0, 1, 2, 3].map(index => cel(index, 3)), 235);
    animate(blood.node, [{ opacity: 1 }, { opacity: 1, offset: .6 }, { opacity: 0 }],
      235, () => blood.node.remove());
  }

  function shoot({ from, target, sprite, delay = 0, kind = 'moonlight' }, contact) {
    const dx = target.col - from.col;
    const dy = target.row - from.row;
    const whirl = kind === 'whirl';
    const duration = Math.round(145 + Math.hypot(dx, dy) * 40 + (whirl ? 90 : 0));
    const release = delay + releaseTime;
    const left = dx < 0;
    const angle = Math.atan2(-dy, -dx);
    if (sprite && !reducedMotion.matches) {
      const poses = kind === 'needles' ? [
        { rotate: '0deg', offset: 0 }, { rotate: '5deg', offset: .29 },
        { rotate: '-7deg', offset: releaseTime / castDuration }, { rotate: '0deg', offset: 1 },
      ] : [[0, 0], [110, 1], [releaseTime, 2], [475, 3], [615, 0], [castDuration, 0]]
        .map(([time, frame]) => ({ ...cel(frame, 3), offset: time / castDuration }));
      animate(sprite, poses, { duration: castDuration, delay });
    }
    if (!reducedMotion.matches && kind !== 'needles') {
      const charge = effect(`${kind} charge`, from, angle);
      animate(charge.node, [{ opacity: 0, scale: '.18' }, { opacity: .88, scale: '.32' }],
        { duration: releaseTime - 120, delay: delay + 120 }, () => charge.node.remove());
    }

    const blade = effect(`${kind} blade`, from, angle);
    if (reducedMotion.matches) blade.node.hidden = true;
    const bend = whirl ? -.72 : 0;
    const travel = Array.from({ length: 9 }, (_, i) => {
      const t = i / 8;
      const y = dy * t + 4 * t * (1 - t) * bend;
      return { translate: `${tile(dx * t)} ${tile(y)}`, opacity: 1 };
    });
    animate(blade.art, Array.from({ length: 8 }, (_, index) => ({ ...cel(index, 7),
      rotate: `${Math.atan2(-(dy + 4 * (1 - index / 4) * bend), -dx)}rad`,
    })), { duration, delay: release });
    animate(blade.node, travel, { duration, delay: release }, () => {
      blade.node.remove();
      if (contact()) showContact(target, angle, left ? -1 : 1, kind);
    });
  }

  function damage(index) {
    if (!health[index]) return false;
    health[index] = Math.max(0, health[index] - MOONLIGHT.damage);
    const { unit, motion } = wolves[index];
    updateWolfHealth(unit, health[index], wolfMaxHp);
    if (!health[index]) motion.fall();
    else motion.play('hit', { direction: [-1, 0], after: motion.attackWall });
    onHit(index, health[index]);
    return true;
  }

  function begin() {
    for (const animation of animations) {
      animation.onfinish = null;
      animation.cancel();
    }
    animations.clear();
    effects.replaceChildren();
    health = RAMPART_WOLVES.map(() => wolfMaxHp);
    wolves.forEach(({ unit }, index) => updateWolfHealth(unit, health[index], wolfMaxHp));
    shoot({ from: { col: RAMPART_GUARD.col + .03, row: RAMPART_GUARD.row + .23 },
      sprite: guard, target: targets[0], delay: 2780 }, () => damage(0));
    shoot({ from: { col: RAMPART_INSTRUCTOR.col + .47, row: RAMPART_INSTRUCTOR.row + .05 },
      sprite: needleGuard, target: targets[0], delay: 3950, kind: 'needles' }, () => damage(0));
    for (const delay of [3120, 4250]) {
      shoot({ from: { col: RAMPART_MOONWHIRL_GUARD.col -.04, row: RAMPART_MOONWHIRL_GUARD.row + .30 },
        sprite: whirlGuard, target: targets[2], delay, kind: 'whirl' }, () => damage(2));
    }
  }

  return {
    begin, shoot,
    trainingTarget: targets[midpoint],
    targetHp: () => health[midpoint],
    playerShot: from => shoot({ from, target: targets[midpoint] }, () => damage(midpoint)),
  };
}
