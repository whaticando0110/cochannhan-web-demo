import motionAtlas from './assets/forest-support/team-motion.json' with { type: 'json' };
import { FOREST_PACK, FOREST_TEAM } from './forest-encounter.mjs';
import { createWolfMotion } from './wolf-motion.mjs';
import { createWorld, findPath, toCell, toPoint } from './world.mjs';

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
  const actors = FOREST_TEAM.map(({ id, cell, regroup, cast }) => {
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
    return { id, cell, regroup, cast, node, art, fx: null, route: [] };
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
  let timers = [];
  const later = (fn, delay) => timers.push(setTimeout(fn, delay));

  function play(actor, name, { duration, iterations = 1 } = {}) {
    actor.fx?.cancel();
    const { frames, times, duration: length } = motionAtlas[actor.id].clips[name];
    actor.art.style.backgroundPosition = position(frames[0]);
    if (motion.matches) return;
    const keyframes = frames.map((frame, index) => ({
      offset: times[index] / length, backgroundPosition: position(frame), easing: 'steps(1, end)',
    }));
    keyframes.push({ ...keyframes.at(-1), offset: 1 });
    actor.fx = actor.art.animate(keyframes, { duration: duration ?? length, iterations });
    actor.fx.onfinish = () => { actor.art.style.backgroundPosition = position(8); };
  }

  function reset(visible = false) {
    timers.forEach(clearTimeout);
    timers = [];
    started = null;
    layer.hidden = !visible;
    ward.hidden = true;
    for (const actor of actors) {
      actor.node.classList.remove('support-walking');
      actor.route = [];
      actor.node.style.setProperty('--support-face', '1');
      place(actor.node, visible ? actor.regroup : actor.cell);
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
    for (const actor of actors) {
      later(() => play(actor, 'skill'), actor.cast);
      later(() => release(actor), actor.cast + motionAtlas[actor.id].clips.skill.releaseAt);
    }
    const exits = [toCell(36, 6), toCell(41, 8), toCell(41, 10), toCell(37, 14)];
    wolves.forEach((wolf, i) => later(() => {
      wolf.animation.play('hit', { direction: [i === 0 ? .2 : -.2, 0] });
      later(() => {
        const a = toPoint(wolf.cell), b = toPoint(exits[i]);
        place(wolf.node, exits[i]);
        wolf.animation.run(a.col - b.col, a.row - b.row, { duration: 620, after: () => {
          wolf.node.hidden = true;
          wolf.animation.stop();
        } });
      }, 205);
    }, 1055 + i * 103));
    for (const actor of actors) {
      const world = createWorld();
      const path = findPath({ ...world, player: { ...world.player, cell: actor.cell } }, actor.regroup);
      path.forEach((cell, index) => later(() => {
        const from = toPoint(path[index - 1] ?? actor.cell);
        const to = toPoint(cell);
        if (from.col !== to.col) actor.node.style.setProperty('--support-face', Math.sign(to.col - from.col));
        actor.node.classList.add('support-walking');
        if (index === 0) play(actor, 'walk', { duration: 400, iterations: Math.ceil(path.length / 2) });
        place(actor.node, cell);
      }, 1660 + 177 * index));
    }
  }

  function facePlayer(cell) {
    const captain = actors[1];
    const direction = toPoint(cell).col < toPoint(captain.regroup).col ? -1 : 1;
    captain.node.style.setProperty('--support-face', direction);
    play(captain, 'signal');
  }

  return { reveal, facePlayer, reset, camera: now => started !== null && now - started < REVEAL_MS ? [35.4, 9.65] : null };
}
