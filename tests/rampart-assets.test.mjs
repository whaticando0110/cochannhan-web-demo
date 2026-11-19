import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';
import {
  BEAST_KING_TREMOR_STEPS,
  SUPPLY_CRATE_POST,
  SUPPLY_STAND_POST,
  buildAnimeImpactSchedule,
  buildGuWakeSchedule,
  buildStoneAbsorptionSchedule,
  buildTremorKeyframes,
} from '../dist/rampart-fx.mjs';

const rampartDir = path.resolve('dist/assets/rampart');

function decodePng(filePath) {
  const buf = fs.readFileSync(filePath);
  let width = 0;
  let height = 0;
  let channels = 0;
  const idats = [];
  for (let p = 8; p < buf.length;) {
    const len = buf.readUInt32BE(p);
    const type = buf.toString('ascii', p + 4, p + 8);
    const data = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      channels = data[9] === 6 ? 4 : data[9] === 2 ? 3 : 0;
    } else if (type === 'IDAT') {
      idats.push(data);
    }
    p += len + 12;
  }
  const scan = zlib.inflateSync(Buffer.concat(idats));
  const stride = width * channels;
  const raw = Buffer.alloc(height * stride);
  const paeth = (a, b, c) => {
    const p = a + b - c;
    const da = Math.abs(p - a);
    const db = Math.abs(p - b);
    const dc = Math.abs(p - c);
    return da <= db && da <= dc ? a : db <= dc ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const filter = scan[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const idx = y * stride + x;
      const a = x >= channels ? raw[idx - channels] : 0;
      const b = y > 0 ? raw[idx - stride] : 0;
      const c = y > 0 && x >= channels ? raw[idx - stride - channels] : 0;
      const v = scan[y * (stride + 1) + 1 + x];
      const pred = filter === 1 ? a : filter === 2 ? b : filter === 3 ? Math.floor((a + b) / 2) : filter === 4 ? paeth(a, b, c) : 0;
      raw[idx] = (v + pred) & 255;
    }
  }
  const rgba = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    rgba[i * 4] = raw[i * channels];
    rgba[i * 4 + 1] = raw[i * channels + 1];
    rgba[i * 4 + 2] = raw[i * channels + 2];
    rgba[i * 4 + 3] = channels === 4 ? raw[i * channels + 3] : 255;
  }
  return { width, height, data: rgba };
}

function assertAtlasIntegrity(metaFile, expectedW, expectedH, expectedCell, expectedGrid, expectedCounts) {
  const meta = JSON.parse(fs.readFileSync(path.join(rampartDir, metaFile), 'utf8'));
  const img = decodePng(path.join(rampartDir, meta.file));
  assert.equal(img.width, expectedW);
  assert.equal(img.height, expectedH);
  assert.deepEqual(meta.cellSize, expectedCell);
  assert.deepEqual(meta.grid, expectedGrid);
  for (let i = 3; i < img.data.length; i += 4) {
    assert.ok(img.data[i] === 0 || img.data[i] === 255);
  }
  for (const [name, expected] of Object.entries(expectedCounts)) {
    const clip = meta.clips[name];
    assert.ok(clip, `Missing clip ${name} in ${metaFile}`);
    assert.equal(clip.count, expected);
    assert.equal(clip.frames.length, expected);
    for (const f of clip.frames) {
      let count = 0;
      for (let y = f.y; y < f.y + f.h; y++) {
        for (let x = f.x; x < f.x + f.w; x++) {
          if (img.data[(y * img.width + x) * 4 + 3] > 0) count++;
        }
      }
      assert.ok(count > 0, `Frame ${name} (${f.col},${f.row}) in ${metaFile} must be non-empty`);
    }
  }
  return meta;
}

test('huyet-nguyet atlas and metadata match exact cell layout and binary alpha', () => {
  const meta = assertAtlasIntegrity('huyet-nguyet.json', 512, 320, [64, 64], [8, 5], {
    flight: 8,
    impact_slash: 4,
    impact_block: 4,
    cast: 6,
    bleed_tick: 6,
    blood_trail: 4,
  });
  assert.deepEqual(meta.pivot, [32, 32]);
});

test('kim-chung-trao atlas and metadata preserve 96x96 bell geometry, ground pivot, and binary alpha', () => {
  const meta = assertAtlasIntegrity('kim-chung-trao.json', 768, 480, [96, 96], [8, 5], {
    cast: 6,
    sustain_back: 8,
    sustain_front: 8,
    block: 6,
    shatter: 6,
  });
  assert.deepEqual(meta.groundPivot, [48, 82]);
  assert.deepEqual(meta.supportedRanks, [3, 4]);
});

test('tremor-dust, kim-chung-impact, and gu-cast-fx atlases have binary alpha and populated frames', () => {
  const tremor = assertAtlasIntegrity('tremor-dust.json', 512, 128, [64, 64], [8, 2], {
    ground_shock: 8,
    thunder_quake: 8,
  });
  assert.deepEqual(tremor.groundPivot, [32, 46]);

  const impact = assertAtlasIntegrity('kim-chung-impact.json', 768, 288, [96, 96], [8, 3], {
    anime_impact: 8,
    sonic_ripple: 8,
    claw_clash: 8,
  });
  assert.deepEqual(impact.groundPivot, [48, 82]);
  assert.deepEqual(impact.animeImpactFrames, [0, 1]);
  assert.deepEqual(impact.bellFlashFrames, [2, 3]);

  const castFx = assertAtlasIntegrity('gu-cast-fx.json', 512, 320, [64, 64], [8, 5], {
    moonlight_release: 4,
    moonlight_wake: 4,
    whirl_release: 4,
    whirl_wake: 4,
    needles_release: 4,
    needles_wake: 4,
    blood_release: 4,
    blood_wake: 4,
    foot_dust: 4,
    hit_flash: 4,
  });
  assert.deepEqual(castFx.pivot, [32, 32]);
});

test('rampart-fx schedules generate deterministic tremor keyframes, anime impact phases, and flight wakes', () => {
  assert.equal(BEAST_KING_TREMOR_STEPS.length, 4);
  assert.ok(BEAST_KING_TREMOR_STEPS[0].amplitudePx < BEAST_KING_TREMOR_STEPS[3].amplitudePx);
  const shake = buildTremorKeyframes(12, 8);
  assert.equal(shake[0].translate, '0px 0px');
  assert.equal(shake.at(-1).translate, '0px 0px');
  assert.notEqual(shake[1].translate, '0px 0px');

  const impact = buildAnimeImpactSchedule();
  assert.equal(impact.hitStop.startMs, 0);
  assert.equal(impact.animeFrameA.startMs, impact.hitStop.endMs);
  assert.equal(impact.animeFrameB.startMs, impact.animeFrameA.endMs);
  assert.equal(impact.goldenFlash.startMs, impact.animeFrameB.endMs);
  assert.deepEqual(impact.goldenFlash.atlasCols, [2, 3, 4, 5, 6, 7]);

  const wake = buildGuWakeSchedule({
    from: { col: 8, row: 11 },
    target: { col: 3, row: 10 },
    bend: -0.5,
    count: 3,
    duration: 280,
    releaseDelay: 330,
  });
  assert.equal(wake.releaseBurst.delayMs, 330);
  assert.equal(wake.footDust.flipX, true);
  assert.equal(wake.wakes.length, 3);
  assert.ok(wake.wakes[0].col > wake.wakes[1].col && wake.wakes[1].col > wake.wakes[2].col);
  assert.ok(wake.wakes[0].opacity > wake.wakes[2].opacity);
});

test('primeval-stone and stone-absorb-fx atlases match 1500ms absorption schedule and binary alpha', () => {
  const stone = assertAtlasIntegrity('primeval-stone.json', 256, 128, [64, 64], [4, 2], {
    supply_crate: 4,
    stone_icon: 4,
  });
  assert.deepEqual(stone.groundPivot, [32, 54]);
  assert.deepEqual(stone.clips.supply_crate.activeFrames, [0, 1, 2]);
  assert.equal(stone.clips.supply_crate.depletedFrame, 3);

  const absorb = assertAtlasIntegrity('stone-absorb-fx.json', 512, 128, [64, 64], [8, 2], {
    qi_spiral_over: 8,
    ground_ring_under: 8,
  });
  assert.equal(absorb.durationMs, 1500);
  assert.deepEqual(absorb.dantianCenter, [32, 34]);
  assert.equal(absorb.powderStartFrame, 6);

  const schedule = buildStoneAbsorptionSchedule({ durationMs: 1500 });
  assert.equal(schedule.durationMs, 1500);
  assert.deepEqual(schedule.standPost, SUPPLY_STAND_POST);
  assert.deepEqual(schedule.cratePost, SUPPLY_CRATE_POST);
  assert.notDeepEqual(schedule.standPost, schedule.cratePost);
  assert.equal(schedule.facingTowardCrate, 1);
  assert.equal(schedule.frames.length, 8);
  assert.equal(schedule.frames[0].startMs, 0);
  assert.equal(schedule.frames.at(-1).endMs, 1500);
  assert.equal(schedule.frames[5].phase, 'aperture-full');
  assert.equal(schedule.frames[6].phase, 'crumble-powder');
  assert.equal(schedule.powderStartMs, 1130);
});
