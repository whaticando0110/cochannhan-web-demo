import { RELIEF_WALK_DURATION_MS, buildReliefWalkKeyframes } from './rampart-fx.mjs';

function tile(value) {
  return `calc(var(--tile) * ${value})`;
}

function cel(col, lastCol, row = 0, lastRow = 1) {
  const xPct = lastCol > 0 ? (col * 100) / lastCol : 0;
  const yPct = lastRow > 0 ? (row * 100) / lastRow : 0;
  return {
    backgroundPosition: `${xPct}% ${yPct}%`,
    easing: 'steps(1, end)',
  };
}

export const FOREST_AMBUSH_ROLES = Object.freeze({
  cover: Object.freeze({
    role: 'cover',
    sprite: 'slate-guard',
    motionAtlas: 'assets/rampart/guard-slate-motion.png',
    cellSize: Object.freeze([128, 128]),
    grid: Object.freeze([4, 2]),
    anchorBaselineY: 119,
    sockets128: Object.freeze({
      chargePalm: Object.freeze([88, 56]),
      releasePalm: Object.freeze([108, 65]),
      wardContact: Object.freeze([102, 58]),
      footGround: Object.freeze([64, 119]),
    }),
  }),
  'opens-gap': Object.freeze({
    role: 'opens-gap',
    sprite: 'russet-guard',
    motionAtlas: 'assets/rampart/guard-russet-motion.png',
    cellSize: Object.freeze([128, 128]),
    grid: Object.freeze([4, 2]),
    anchorBaselineY: 121,
    sockets128: Object.freeze({
      chargePalm: Object.freeze([67.5, 69.5]),
      releasePalm: Object.freeze([96, 63.5]),
      footGround: Object.freeze([64, 121]),
    }),
  }),
  'rear-guard': Object.freeze({
    role: 'rear-guard',
    sprite: 'ivory-guard',
    motionAtlas: 'assets/rampart/guard-ivory-motion.png',
    cellSize: Object.freeze([128, 128]),
    grid: Object.freeze([4, 2]),
    anchorBaselineY: 121,
    sockets128: Object.freeze({
      chargePalm: Object.freeze([67, 68]),
      releasePalm: Object.freeze([94, 64.5]),
      footGround: Object.freeze([64, 121]),
    }),
  }),
  'scout-wolf': Object.freeze({
    role: 'scout-wolf',
    sprite: 'dien-lang',
    motionAtlas: 'assets/world/dien-lang.png',
    cellSize: Object.freeze([128, 128]),
    grid: Object.freeze([4, 4]),
    anchorBaselineY: 102,
    sockets128: Object.freeze({
      eyeAlert: Object.freeze([94, 48]),
      forepawGround: Object.freeze([88, 100]),
      hitCenter: Object.freeze([68, 66]),
    }),
  }),
});

export const FOREST_AMBUSH_FX_CLIPS = Object.freeze({
  detection_glint:   Object.freeze({ row: 0, startCol: 0, count: 4, durationMs: 260, pivot: Object.freeze([32, 32]) }),
  pounce_coil_dust:  Object.freeze({ row: 0, startCol: 4, count: 4, durationMs: 320, pivot: Object.freeze([32, 50]) }),
  fang_ward_spark:   Object.freeze({ row: 1, startCol: 0, count: 4, durationMs: 240, pivot: Object.freeze([32, 32]) }),
  gap_blast_wave:    Object.freeze({ row: 1, startCol: 4, count: 4, durationMs: 280, pivot: Object.freeze([32, 32]) }),
  urgent_step_dust:  Object.freeze({ row: 2, startCol: 0, count: 4, durationMs: 240, pivot: Object.freeze([32, 52]) }),
  regroup_stance_ring: Object.freeze({ row: 2, startCol: 4, count: 4, durationMs: 360, pivot: Object.freeze([32, 52]) }),
});

/**
 * Converts a 128x128 guard socket [x, y] to world tile coordinates { col, row },
 * accounting for facing direction (1 = East/Right, -1 = West/Left).
 */
export function guardSocketToPoint(post, [x, y], facing = -1) {
  const dir = facing >= 0 ? 1 : -1;
  return {
    col: Number((post.col + 0.5 + dir * 1.46 * (x / 128 - 0.5)).toFixed(3)),
    row: Number((post.row + 0.89 - 1.46 * (1 - y / 128)).toFixed(3)),
  };
}

/**
 * Converts a 128x128 wolf socket [x, y] to world tile coordinates { col, row },
 * accounting for facing direction (1 = East/Right, -1 = West/Left).
 */
export function wolfSocketToPoint(post, [x, y], facing = -1) {
  const dir = facing >= 0 ? 1 : -1;
  return {
    col: Number((post.col + 0.5 + dir * 1.65 * (x / 128 - 0.5)).toFixed(3)),
    row: Number((post.row + 0.92 - 1.65 * (1 - y / 128)).toFixed(3)),
  };
}

export const FOREST_AMBUSH_SEGMENTS = Object.freeze({
  segment1_breakout: Object.freeze({
    id: 'segment1_breakout',
    order: 1,
    triggerCell: Object.freeze([27, 10]),
    durationMs: 2200,
    escapePath: Object.freeze([[35, 10], [36, 10], [37, 10], [37, 11], [38, 11]]),
    actors: Object.freeze([
      Object.freeze({
        role: 'cover',
        sprite: 'slate-guard',
        startCell: Object.freeze([35, 8]),
        endCell: Object.freeze([37, 10]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,    cell: [35, 8],  facing: -1, row: 0, frames: [0, 1] }),
          Object.freeze({ atMs: 520,  cell: [35, 8],  facing: 1,  row: 0, frames: [1, 2, 3, 0] }),
          Object.freeze({ atMs: 1220, cell: [35, 8],  facing: 1,  row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1520, cell: [35, 10], facing: 1,  row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1820, cell: [36, 10], facing: 1,  row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 2120, cell: [37, 10], facing: 1,  row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([
          Object.freeze({ atMs: 220,  kind: 'fang_ward_spark',  socket: 'wardContact', facing: -1, cell: [34.72, 7.82], durationMs: 240 }),
          Object.freeze({ atMs: 1220, kind: 'urgent_step_dust', socket: 'footGround',  facing: 1,  cell: [35.0, 8.85],  durationMs: 240 }),
        ]),
      }),
      Object.freeze({
        role: 'opens-gap',
        sprite: 'russet-guard',
        startCell: Object.freeze([35, 10]),
        endCell: Object.freeze([38, 11]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,    cell: [35, 10], facing: 1, row: 0, frames: [0] }),
          Object.freeze({ atMs: 420,  cell: [35, 10], facing: 1, row: 0, frames: [0, 1, 2, 3, 0], releaseAtMs: 750 }),
          Object.freeze({ atMs: 1120, cell: [35, 10], facing: 1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1350, cell: [36, 10], facing: 1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1580, cell: [37, 10], facing: 1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1810, cell: [37, 11], facing: 1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 2040, cell: [38, 11], facing: 1, row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([
          Object.freeze({ atMs: 750,  kind: 'gap_blast_wave',   socket: 'releasePalm', facing: 1, cell: [35.84, 10.15], targetCell: [38.0, 10.15], durationMs: 280 }),
          Object.freeze({ atMs: 1120, kind: 'urgent_step_dust', socket: 'footGround',  facing: 1, cell: [35.0, 10.88], durationMs: 240 }),
        ]),
      }),
      Object.freeze({
        role: 'rear-guard',
        sprite: 'ivory-guard',
        startCell: Object.freeze([36, 11]),
        endCell: Object.freeze([38, 11]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,    cell: [36, 11], facing: -1, row: 0, frames: [0, 1, 2, 3, 0], releaseAtMs: 330 }),
          Object.freeze({ atMs: 1320, cell: [36, 11], facing: 1,  row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1720, cell: [37, 11], facing: 1,  row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 2120, cell: [38, 11], facing: -1, row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([
          Object.freeze({ atMs: 330,  kind: 'fang_ward_spark',  socket: 'releasePalm', facing: -1, cell: [35.66, 11.17], targetCell: [34.52, 11.92], durationMs: 240 }),
          Object.freeze({ atMs: 1320, kind: 'urgent_step_dust', socket: 'footGround',  facing: 1,  cell: [36.0, 11.88], durationMs: 240 }),
        ]),
      }),
      Object.freeze({
        role: 'pack-north',
        sprite: 'dien-lang',
        startCell: Object.freeze([34, 7]),
        endCell: Object.freeze([34, 7]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,   cell: [34, 7], facing: 1, frames: [8, 9, 10, 11, 0] }),
          Object.freeze({ atMs: 380, cell: [34, 7], facing: 1, frames: [0, 1, 2, 3] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
      Object.freeze({
        role: 'pack-northeast',
        sprite: 'dien-lang',
        startCell: Object.freeze([37, 8]),
        endCell: Object.freeze([37.4, 7.8]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 160, cell: [37, 8],     facing: -1, frames: [8, 9, 10, 11, 0] }),
          Object.freeze({ atMs: 680, cell: [37.4, 7.8], facing: -1, frames: [12, 13, 14, 15] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
      Object.freeze({
        role: 'pack-east',
        sprite: 'dien-lang',
        startCell: Object.freeze([38, 10]),
        endCell: Object.freeze([39, 9.5]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,    cell: [38, 10],   facing: -1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 980,  cell: [38, 10],   facing: -1, frames: [12, 13, 14, 15] }),
          Object.freeze({ atMs: 1260, cell: [39, 9.5],  facing: -1, frames: [0, 1] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
      Object.freeze({
        role: 'pack-south',
        sprite: 'dien-lang',
        startCell: Object.freeze([34, 12]),
        endCell: Object.freeze([33.7, 12.2]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 100, cell: [34, 12],     facing: 1, frames: [8, 9, 10, 11, 0] }),
          Object.freeze({ atMs: 480, cell: [33.7, 12.2], facing: 1, frames: [12, 13, 14, 15] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
    ]),
  }),

  segment2_scout_alert: Object.freeze({
    id: 'segment2_scout_alert',
    order: 2,
    triggerCell: Object.freeze([29, 10]),
    shoutText: 'Cẩn thận!',
    durationMs: 1450,
    dodgeCell: Object.freeze([30, 9]),
    threatCells: Object.freeze([[29, 10], [28, 10], [30, 10], [29, 9], [29, 11]]),
    actors: Object.freeze([
      Object.freeze({
        role: 'scout-wolf',
        sprite: 'dien-lang',
        startCell: Object.freeze([34, 9]),
        endCell: Object.freeze([32, 10]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,    cell: [34, 9],   facing: -1, frames: [1, 2, 3] }),
          Object.freeze({ atMs: 320,  cell: [34, 9],   facing: -1, frames: [4, 5, 6, 7] }),
          Object.freeze({ atMs: 620,  cell: [33, 9.5], facing: -1, frames: [4, 5, 6, 7] }),
          Object.freeze({ atMs: 920,  cell: [32, 10],  facing: -1, frames: [10, 11] }),
          Object.freeze({ atMs: 1080, cell: [32, 10],  facing: -1, frames: [8] }),
        ]),
        fxEvents: Object.freeze([
          Object.freeze({ atMs: 40,  kind: 'detection_glint',  socket: 'eyeAlert',      facing: -1, cell: [33.76, 8.58], durationMs: 260 }),
          Object.freeze({ atMs: 940, kind: 'pounce_coil_dust', socket: 'forepawGround', facing: -1, cell: [31.85, 10.35], durationMs: 320 }),
        ]),
      }),
    ]),
  }),

  segment3_regroup: Object.freeze({
    id: 'segment3_regroup',
    order: 3,
    durationMs: 1650,
    regroupLead: Object.freeze([37, 11]),
    talkFrom: Object.freeze([36, 11]),
    actors: Object.freeze([
      Object.freeze({
        role: 'scout-wolf',
        sprite: 'dien-lang',
        startCell: Object.freeze([32, 10]),
        endCell: Object.freeze([32, 10]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 0,   cell: [32, 10], facing: -1, frames: [12, 13, 8, 8] }),
          Object.freeze({ atMs: 320, cell: [32, 10], facing: -1, frames: [8] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
      Object.freeze({
        role: 'cover',
        sprite: 'slate-guard',
        startCell: Object.freeze([38, 11]),
        endCell: Object.freeze([37, 11]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 240,  cell: [38, 11], facing: -1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1120, cell: [37, 11], facing: -1, row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([
          Object.freeze({ atMs: 1120, kind: 'regroup_stance_ring', socket: 'footGround', facing: -1, cell: [37, 11], durationMs: 360 }),
          Object.freeze({ atMs: 1200, kind: 'regroup_stance_ring', socket: 'footGround', facing: 1,  cell: [36, 11], durationMs: 360 }),
        ]),
      }),
      Object.freeze({
        role: 'opens-gap',
        sprite: 'russet-guard',
        startCell: Object.freeze([39, 10]),
        endCell: Object.freeze([38, 10]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 320,  cell: [39, 10], facing: -1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1220, cell: [38, 10], facing: -1, row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
      Object.freeze({
        role: 'rear-guard',
        sprite: 'ivory-guard',
        startCell: Object.freeze([39, 12]),
        endCell: Object.freeze([38, 12]),
        waypoints: Object.freeze([
          Object.freeze({ atMs: 400,  cell: [39, 12], facing: -1, row: 1, frames: [0, 1, 2, 3] }),
          Object.freeze({ atMs: 1320, cell: [38, 12], facing: -1, row: 0, frames: [0] }),
        ]),
        fxEvents: Object.freeze([]),
      }),
    ]),
  }),
});

/**
 * Deterministically samples actor positions, facing, atlas frame, and active FX
 * at `elapsedMs` for any of the 3 forest ambush segments.
 */
export function sampleForestAmbushSegment(segmentId, elapsedMs) {
  const seg = FOREST_AMBUSH_SEGMENTS[segmentId];
  if (!seg) throw new Error(`Unknown forest ambush segment: ${segmentId}`);
  const t = Math.max(0, Math.min(seg.durationMs, elapsedMs));

  const actors = seg.actors.map((actor) => {
    const wps = actor.waypoints;
    let idx = 0;
    for (let i = 0; i < wps.length; i++) {
      if (t >= wps[i].atMs) idx = i;
    }
    const cur = wps[idx];
    const next = wps[idx + 1];
    const span = next ? Math.max(1, next.atMs - cur.atMs) : Math.max(1, seg.durationMs - cur.atMs);
    const localT = Math.max(0, Math.min(1, (t - cur.atMs) / span));

    const col = next ? cur.cell[0] + (next.cell[0] - cur.cell[0]) * localT : cur.cell[0];
    const row = next ? cur.cell[1] + (next.cell[1] - cur.cell[1]) * localT : cur.cell[1];
    const frameIdx = cur.frames[Math.min(cur.frames.length - 1, Math.floor(localT * cur.frames.length))];

    let backgroundPosition;
    if (actor.sprite === 'dien-lang') {
      backgroundPosition = `${(frameIdx % 4) * (100 / 3)}% ${Math.floor(frameIdx / 4) * (100 / 3)}%`;
    } else {
      const atlasRow = cur.row ?? 0;
      backgroundPosition = `${frameIdx * (100 / 3)}% ${atlasRow * 100}%`;
    }

    const activeFx = actor.fxEvents.filter(fx => t >= fx.atMs && t <= fx.atMs + fx.durationMs);
    return {
      role: actor.role,
      sprite: actor.sprite,
      col: Number(col.toFixed(3)),
      row: Number(row.toFixed(3)),
      facing: cur.facing,
      frame: frameIdx,
      atlasRow: cur.row ?? Math.floor(frameIdx / 4),
      backgroundPosition,
      activeFx,
    };
  });

  return {
    segmentId: seg.id,
    elapsedMs: t,
    done: t >= seg.durationMs,
    actors,
  };
}

/**
 * Spawns a one-shot effect from `forest-ambush-fx.png` (512x192, 8x3 @ 64x64)
 * into `effectsLayer`.
 */
export function spawnForestAmbushFx(effectsLayer, reducedMotion, { kind, point, facing = 1, durationMs } = {}) {
  const clip = FOREST_AMBUSH_FX_CLIPS[kind];
  if (!clip) throw new Error(`Unknown forest-ambush-fx clip: ${kind}`);
  const dur = durationMs ?? clip.durationMs;
  const keyframes = Array.from({ length: clip.count }, (_, i) =>
    cel(clip.startCol + i, 7, clip.row, 2)
  );
  if (!effectsLayer || reducedMotion?.matches) {
    return { kind, durationMs: dur, keyframes };
  }
  const node = document.createElement('span');
  node.className = `forest-ambush-fx ${kind}`;
  node.style.left = tile(point.col ?? point[0]);
  node.style.top = tile(point.row ?? point[1]);
  const art = document.createElement('i');
  if (facing < 0) art.style.transform = 'scaleX(-1)';
  node.append(art);
  effectsLayer.append(node);
  const anim = art.animate(keyframes, { duration: dur });
  anim.onfinish = () => node.remove();
  return { kind, durationMs: dur, keyframes, node };
}

export { RELIEF_WALK_DURATION_MS, buildReliefWalkKeyframes };
