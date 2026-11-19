import motionAtlas from './assets/forest-support/team-motion.json' with { type: 'json' };
import { FOREST_PACK, FOREST_TEAM } from './forest-encounter.mjs';
import { createWolfMotion } from './wolf-motion.mjs';
import { toPoint } from './world.mjs';

export const REVEAL_MS = 2450;

function place(node, cell) {
  const { col, row } = toPoint(cell);
  node.style.transform = `translate3d(calc(var(--tile) * ${col}), calc(var(--tile) * ${row}), 0)`;
}

function position(frame) {
  return `${frame % 4 * 100 / 3}% ${Math.floor(frame / 4) * 50}%`;
}

export function createForestTeam(plane, wolfTemplate, motion, shoot) {
  const layer = document.createElement('div');
  layer.hidden = true;
  layer.className = 'forest-team';
  layer.setAttribute('aria-hidden', 'true');
  plane.append(layer);
  const actors = FOREST_TEAM.map(({ id, cell, cast }) => {
    const node = document.createElement('div');
    node.className = 'field-unit forest-support';
    node.dataset.support = id;
    const art = document.createElement('i');
    art.className = 'support-art';
    art.style.backgroundImage = `url("assets/forest-support/${motionAtlas[id].file}")`;
    const shadow = document.createElement('i');
    shadow.className = 'unit-shadow';
    node.append(shadow, art);
    layer.append(node);
    return { id, cell, cast, node, art, fx: null };
  });
  const wolves = FOREST_PACK.map((cell, i) => {
    const node = wolfTemplate.cloneNode(true);
    node.removeAttribute('id');
    node.classList.add('forest-pack-wolf');
    node.querySelector('.wolf-health').hidden = true;
    node.style.setProperty('--face', i === 0 || i === 3 ? 1 : -1);
    layer.append(node);
    return { cell, node, animation: createWolfMotion(node, motion) };
  });
  const ward = document.createElement('i');
  ward.className = 'forest-ward';
  layer.append(ward);
  let started = null;
  const timers = new Set();
  const later = (fn, delay) => {
    const timer = setTimeout(() => {
      timers.delete(timer);
      fn();
    }, delay);
    timers.add(timer);
  };
  function clearActions() {
    timers.forEach(clearTimeout);
    timers.clear();
    ward.hidden = true;
  }

  function play(actor, name) {
    actor.fx?.cancel();
    const { frames, times, duration: length } = motionAtlas[actor.id].clips[name];
    actor.art.style.backgroundPosition = position(frames[0]);
    if (motion.matches) return;
    const keyframes = frames.map((frame, index) => ({
      offset: times[index] / length, backgroundPosition: position(frame), easing: 'steps(1, end)',
    }));
    keyframes.push({ ...keyframes.at(-1), offset: 1 });
    actor.fx = actor.art.animate(keyframes, { duration: length });
    actor.fx.onfinish = () => { actor.art.style.backgroundPosition = position(8); };
  }

  function reset() {
    clearActions();
    started = null;
    layer.hidden = true;
    for (const actor of actors) {
      actor.node.style.setProperty('--support-face', '1');
      place(actor.node, actor.cell);
      play(actor, 'idle');
    }
    for (const wolf of wolves) {
      wolf.animation.stop();
      wolf.node.hidden = true;
    }
  }

  function release(actor) {
    const { col, row } = toPoint(actor.cell);
    const [x,y] = motionAtlas[actor.id].clips.skill.releaseOrigin;
    const from = { col: col + .5 + (x / 128 - .5) * 1.46, row: row + .89 - (1 - y / 128) * 1.46 };
    if (actor.id === 'moon') {
      shoot({ from, target: { col: 38.5, row: 10.54 }, windup: 0, kind: 'forest-mang' }, () => true);
    } else if (actor.id === 'pine') {
      shoot({ from, target: { col: 37.5, row: 8.53 }, windup: 0, kind: 'needles' }, () => true);
    } else {
      ward.hidden = false;
      place(ward, FOREST_TEAM[1].cell);
      later(() => { ward.hidden = true; }, 900);
    }
  }

  function cast(actor, delay) {
    later(() => play(actor, 'skill'), delay);
    later(() => release(actor), delay + motionAtlas[actor.id].clips.skill.releaseAt);
  }

  function exchange(turn) {
    clearActions();
    cast(actors[turn % actors.length], 0);
    const wolf = wolves[turn % wolves.length];
    later(() => wolf.animation.play('pounce', { direction: [turn % 4 === 0 || turn % 4 === 3 ? .35 : -.35, 0] }), 190);
  }

  function reveal(now) {
    if (started !== null) return;
    reset();
    started = now;
    layer.hidden = false;
    for (const wolf of wolves) {
      place(wolf.node, wolf.cell);
      wolf.node.hidden = false;
      wolf.animation.idle();
    }
    for (const actor of actors) cast(actor, actor.cast);
    wolves.forEach((wolf, index) => later(() =>
      wolf.animation.play('hit', { direction: [index === 0 || index === 3 ? .2 : -.2, 0] }), 1100 + index * 115));
  }

  function facePlayer(cell) {
    const captain = actors[1];
    const direction = toPoint(cell).col < toPoint(captain.cell).col ? -1 : 1;
    captain.node.style.setProperty('--support-face', direction);
    play(captain, 'signal');
    later(() => captain.node.style.setProperty('--support-face', '1'), 540);
  }

  function finishFight() {
    clearActions();
    wolves.forEach(wolf => wolf.animation.fall());
    actors.forEach(actor => play(actor, 'idle'));
  }

  return { reveal, facePlayer, exchange, finishFight, reset,
    camera: now => started !== null && now - started < REVEAL_MS ? [35.4, 9.65] : null };
}
