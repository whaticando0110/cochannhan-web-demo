import { GATE, TERRAIN, TRAIL_ENTRY, createWorld, findPath, toCell, toPoint } from './world.mjs';

export const FOREST_POST = toCell(25, 10);
export const LEADER_FOREST = toCell(26, 10);
const LEADER_GATE = GATE + 1;
const LEADER_REAR = toCell(12, 12);
const LEADER_HUNT = toCell(28, 9);
const reserves = [
  { start: toCell(11, 12), post: toCell(5, 9), avoid: toCell(5, 11), outfit: 'russet-guard' },
  { start: toCell(11, 14), post: toCell(5, 12), outfit: 'ivory-guard' },
];

export function rearCheckpoint(value, identity) {
  if (value === identity + '|rear') return 'report';
  for (const phase of ['gate', 'forest', 'trail']) {
    if (value === identity + '|rear-' + phase) return phase;
  }
  return null;
}

export function canAdvanceRear(phase, playerCell, rearPost, leaderReady) {
  if (phase === 'report' && playerCell === rearPost) return 'gate';
  if (phase === 'gate' && playerCell === GATE) return 'forest';
  if (phase === 'forest' && playerCell === FOREST_POST && leaderReady) return 'trail';
  return phase;
}

export function reserveRoute(from, target, avoid) {
  const world = createWorld();
  return findPath({ ...world, player: { ...world.player, cell: from } }, target, avoid);
}

export function createReinforcements(plane) {
  function add(outfit, leader = false) {
    const node = document.createElement('div');
    node.className = `field-unit rampart-guard rear-unit ${outfit}`;
    if (leader) node.id = 'rear-leader';
    node.hidden = true;
    node.setAttribute('aria-hidden', 'true');
    node.innerHTML = '<i class="unit-shadow"></i><i class="guard-art"></i>';
    plane.append(node);
    return { node, cell: null, path: [], nextAt: 0 };
  }

  const leader = add('slate-guard', true);
  const crew = reserves.map(({ outfit }) => add(outfit));
  const actors = [leader, ...crew];

  function position(actor, cell) {
    actor.cell = cell;
    const { col, row } = toPoint(cell);
    actor.node.style.transform = `translate3d(calc(var(--tile) * ${col}), calc(var(--tile) * ${row}), 0)`;
  }

  function order(actor, target, now, avoid) {
    actor.path = reserveRoute(actor.cell, target, avoid);
    actor.nextAt = now;
  }

  function reset(phase = null, now = 0) {
    for (const actor of actors) {
      actor.node.hidden = phase === null;
      actor.node.classList.remove('rear-moving');
      actor.node.style.removeProperty('--rear-facing');
      actor.path = [];
      actor.nextAt = 0;
    }
    if (phase === null) return;
    position(leader, phase === 'trail' ? LEADER_FOREST : phase === 'forest' ? LEADER_GATE : LEADER_REAR);
    const dispatched = phase !== 'report';
    crew.forEach((actor, i) => position(actor, dispatched ? reserves[i].post : reserves[i].start));
    if (phase === 'gate') order(leader, LEADER_GATE, now + 150);
    else if (phase === 'forest') order(leader, LEADER_FOREST, now + 150, FOREST_POST);
    else if (phase === 'trail') leadToHunt(now);
  }

  function dispatch(now, playerCell) {
    crew.forEach((actor, index) => {
      const { post, avoid } = reserves[index];
      order(actor, post, now + 150 + 260 * index, avoid ?? playerCell);
    });
    order(leader, LEADER_GATE, now + 290, playerCell);
  }

  function leadToForest(now) {
    order(leader, LEADER_FOREST, Math.max(now, leader.nextAt), FOREST_POST);
  }

  function leadToHunt(now) {
    order(leader, LEADER_HUNT, now + 140, TRAIL_ENTRY);
  }

  function tick(now, playerCell) {
    for (const actor of actors) {
      const next = actor.path[0];
      if (actor.node.hidden || next === undefined || next === playerCell || now < actor.nextAt) continue;
      const dx = toPoint(next).col - toPoint(actor.cell).col;
      if (dx) actor.node.style.setProperty('--rear-facing', -Math.sign(dx));
      const onStairs = TERRAIN[next].rampart?.stair || TERRAIN[actor.cell].rampart?.stair;
      const duration = onStairs ? 460 : 305;
      actor.node.style.setProperty('--rear-step', duration + 'ms');
      actor.node.classList.add('rear-moving');
      actor.path.shift();
      position(actor, next);
      actor.nextAt = now + duration;
    }
  }

  return {
    reset, dispatch, leadToForest, leadToHunt, tick,
    ready: now => leader.cell === LEADER_FOREST && now >= leader.nextAt,
  };
}
