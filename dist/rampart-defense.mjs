import {
  RAMPART_GUARD, RAMPART_INSTRUCTOR, RAMPART_MOONWHIRL_GUARD, RAMPART_WOLVES,
  RAMPART_NORTH_REINFORCEMENT, RAMPART_SOUTH_REINFORCEMENT,
} from './rampart.mjs';
import { MOONLIGHT, TRAINING_POST, toPoint } from './world.mjs';

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

function guardPalm(post, x, y) {
  // Mirror the measured 128px hand socket and match the size and baseline of .guard-art.
  return { col: post.col + .5 - 1.46 * (x / 128 - .5), row: post.row + .89 - 1.46 * (1 - y / 128) };
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
  const northGuard = addGuard(plane, RAMPART_NORTH_REINFORCEMENT, 'russet-guard');
  const southGuard = addGuard(plane, RAMPART_SOUTH_REINFORCEMENT, 'ivory-guard');
  const relief = addGuard(plane, { col: 0, row: 0 }, 'ivory-guard relief-guard');
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
    const row = kind === 'huyet-nguyet' ? 25 : 100;
    animate(impact.art, frames.map(index => cel(index, 7, row)), 165);
    animate(impact.node, [{ opacity: .96 }, { opacity: 0 }], 165, () => impact.node.remove());

    const blood = effect('blood', target);
    blood.art.style.setProperty('--blood-facing', direction < 0 ? '-1' : '1');
    animate(blood.art, [0, 1, 2, 3].map(index => cel(index, 3)), 235);
    animate(blood.node, [{ opacity: 1 }, { opacity: 1, offset: .6 }, { opacity: 0 }],
      235, () => blood.node.remove());
  }

  function shoot({ from, target, sprite, delay = 0, kind = 'moonlight', windup = releaseTime, chargeFrom = from, travelMs }, contact) {
    const dx = target.col - from.col;
    const dy = target.row - from.row;
    const whirl = kind === 'whirl';
    const duration = travelMs ?? Math.round(145 + Math.hypot(dx, dy) * 40 + (whirl ? 90 : 0));
    const release = delay + windup;
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
    if (windup && !reducedMotion.matches && kind !== 'needles') {
      const charge = effect(`${kind} charge`, chargeFrom, angle);
      animate(charge.node, [{ opacity: 0, scale: '.18' }, { opacity: .88, scale: '.32' }],
        { duration: windup - 120, delay: delay + 120 }, () => charge.node.remove());
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

  function damage(index, amount = MOONLIGHT.damage) {
    if (!health[index]) return false;
    health[index] = Math.max(0, health[index] - amount);
    const { unit, motion } = wolves[index];
    updateWolfHealth(unit, health[index], wolfMaxHp);
    if (!health[index]) motion.fall();
    else motion.play('hit', { direction: [-1, 0], after: motion.attackWall });
    onHit(index, health[index]);
    return true;
  }

  function stop() {
    for (const animation of animations) {
      animation.onfinish = null;
      animation.cancel();
    }
    animations.clear();
    effects.replaceChildren();
  }

  function begin(guardVolley = true) {
    stop();
    health = RAMPART_WOLVES.map(() => wolfMaxHp);
    wolves.forEach(({ unit }, index) => updateWolfHealth(unit, health[index], wolfMaxHp));
    if (!guardVolley) return;
    shoot({ from: { col: RAMPART_GUARD.col + .03, row: RAMPART_GUARD.row + .23 },
      sprite: guard, target: targets[0], delay: 2780 }, () => damage(0));
    shoot({ from: { col: RAMPART_INSTRUCTOR.col + .47, row: RAMPART_INSTRUCTOR.row + .05 },
      sprite: needleGuard, target: targets[0], delay: 3950, kind: 'needles' }, () => damage(0, 13));
    shoot({ from: { col: RAMPART_MOONWHIRL_GUARD.col - .04, row: RAMPART_MOONWHIRL_GUARD.row + .30 },
      sprite: whirlGuard, target: targets[2], delay: 3120, kind: 'whirl' }, () => damage(2));
    shoot({ from: guardPalm(RAMPART_NORTH_REINFORCEMENT, 96, 63.5),
      chargeFrom: guardPalm(RAMPART_NORTH_REINFORCEMENT, 67.5, 69.5),
      sprite: northGuard, target: targets[0], delay: 4520 }, () => damage(0, 13));
    shoot({ from: guardPalm(RAMPART_SOUTH_REINFORCEMENT, 94, 64.5),
      chargeFrom: guardPalm(RAMPART_SOUTH_REINFORCEMENT, 68.5, 66),
      sprite: southGuard, target: targets[2], delay: 4250, kind: 'whirl' }, () => damage(2));
  }

  function coverTrainingPost() {
    if (!health[midpoint]) {
      const { col, row, startCol, startRow } = RAMPART_WOLVES[midpoint];
      const { unit, motion } = wolves[midpoint];
      health[midpoint] = wolfMaxHp;
      updateWolfHealth(unit, wolfMaxHp, wolfMaxHp);
      motion.run(startCol - col, startRow - row, { duration: 1400, after: motion.attackWall });
    }
    const post = toPoint(TRAINING_POST);
    const from = guardPalm(post, 94, 64.5);
    const chargeFrom = guardPalm(post, 67, 68);
    for (const delay of [1300, 3000]) {
      shoot({ from, chargeFrom, sprite: relief, target: targets[midpoint], delay }, () => damage(midpoint));
    }
  }

  function recoilAtWall() {
    if (reducedMotion.matches) return;
    for (const [index, actor] of [guard, whirlGuard, needleGuard, northGuard, southGuard].entries()) {
      animate(actor.parentElement, [
        { translate: '0 0', offset: 0 },
        { translate: '12% 4%', offset: .27 },
        { translate: '7% 2%', offset: .58 },
        { translate: '0 0', offset: 1 },
      ], { duration: 510, delay: 40 + index * 28, easing: 'ease-out' });
      animate(actor, [
        { rotate: '0deg', offset: 0 }, { rotate: '8deg', offset: .24 }, { rotate: '0deg', offset: 1 },
      ], { duration: 510, delay: 40 + index * 28 });
    }
  }

  return {
    begin, stop, shoot, coverTrainingPost, recoilAtWall,
    reliefUnit: relief.parentElement,
    trainingTarget: targets[midpoint],
    targetHp: () => health[midpoint],
    playerShot: (from, settled) => shoot({ from, target: targets[midpoint], windup: 0 }, () => {
      const hit = damage(midpoint);
      settled();
      return hit;
    }),
  };
}
