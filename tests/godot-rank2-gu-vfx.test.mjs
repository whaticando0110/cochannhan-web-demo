import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REVIEW_DIR = path.join(ROOT, 'godot-combat', 'assets', 'rank2-review');

function decodePng(filePath) {
  const b = fs.readFileSync(filePath);
  assert.equal(b.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', `${path.basename(filePath)} PNG signature`);
  let w = 0;
  let h = 0;
  let c = 0;
  const parts = [];
  for (let p = 8; p < b.length;) {
    const n = b.readUInt32BE(p);
    const type = b.toString('ascii', p + 4, p + 8);
    const d = b.subarray(p + 8, p + 8 + n);
    if (type === 'IHDR') {
      w = d.readUInt32BE(0);
      h = d.readUInt32BE(4);
      c = d[9] === 6 ? 4 : d[9] === 2 ? 3 : 0;
    } else if (type === 'IDAT') {
      parts.push(d);
    }
    p += n + 12;
  }
  const scan = zlib.inflateSync(Buffer.concat(parts));
  const stride = w * c;
  const out = Buffer.alloc(w * h * c);
  const data = Buffer.alloc(w * h * 4);
  const paeth = (a, b2, c2) => {
    const pr = a + b2 - c2;
    const da = Math.abs(pr - a);
    const db = Math.abs(pr - b2);
    const dc = Math.abs(pr - c2);
    return da <= db && da <= dc ? a : db <= dc ? b2 : c2;
  };
  for (let y = 0; y < h; y++) {
    const f = scan[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const p = y * stride + x;
      const a = x >= c ? out[p - c] : 0;
      const up = y ? out[p - stride] : 0;
      const ul = y && x >= c ? out[p - stride - c] : 0;
      out[p] = (scan[y * (stride + 1) + 1 + x] + (f === 1 ? a : f === 2 ? up : f === 3 ? Math.floor((a + up) / 2) : f === 4 ? paeth(a, up, ul) : 0)) & 255;
    }
  }
  for (let p = 0; p < w * h; p++) {
    out.copy(data, p * 4, p * c, p * c + 3);
    data[p * 4 + 3] = c === 4 ? out[p * c + 3] : 255;
  }
  return { width: w, height: h, data };
}

function assertBinaryAlphaAndMacro2x2(img, name, checkMacro = true) {
  for (let i = 0; i < img.data.length; i += 4) {
    const a = img.data[i + 3];
    assert.ok(a === 0 || a === 255, `${name} must use strict binary alpha (0|255), got ${a}`);
  }
  if (!checkMacro) return;
  for (let y = 0; y < img.height; y += 2) {
    for (let x = 0; x < img.width; x += 2) {
      const i00 = (y * img.width + x) * 4;
      for (const [dx, dy] of [[1, 0], [0, 1], [1, 1]]) {
        const i = ((y + dy) * img.width + (x + dx)) * 4;
        assert.ok(
          img.data[i] === img.data[i00]
          && img.data[i + 1] === img.data[i00 + 1]
          && img.data[i + 2] === img.data[i00 + 2]
          && img.data[i + 3] === img.data[i00 + 3],
          `${name} must stay on a 2x2 macro-pixel grid without mixels at (${x},${y})`
        );
      }
    }
  }
}

function cellBBox(img, col, row, cw, ch) {
  let x0 = cw;
  let y0 = ch;
  let x1 = -1;
  let y1 = -1;
  let opaque = 0;
  for (let y = 0; y < ch; y++) {
    for (let x = 0; x < cw; x++) {
      const i = ((row * ch + y) * img.width + (col * cw + x)) * 4;
      if (img.data[i + 3] > 0) {
        opaque += 1;
        if (x < x0) x0 = x;
        if (y < y0) y0 = y;
        if (x > x1) x1 = x;
        if (y > y1) y1 = y;
      }
    }
  }
  return { opaque, bbox: x1 >= x0 ? { x0, y0, x1, y1 } : null };
}

function readAsepriteHeader(filePath) {
  const b = fs.readFileSync(filePath);
  return {
    magic: b.readUInt16LE(4),
    frames: b.readUInt16LE(6),
    width: b.readUInt16LE(8),
    height: b.readUInt16LE(10),
  };
}

test('Rank 2 Nguyet Mang & Bach Ngoc atlases, icons, Aseprite sources, manifest, and play-scale GIFs satisfy Godot specs', () => {
  const nmAtlas = decodePng(path.join(REVIEW_DIR, 'nguyet-mang-co.png'));
  const nmIcon = decodePng(path.join(REVIEW_DIR, 'nguyet-mang-co-icon.png'));
  const bnAtlas = decodePng(path.join(REVIEW_DIR, 'bach-ngoc-co.png'));
  const bnIcon = decodePng(path.join(REVIEW_DIR, 'bach-ngoc-co-icon.png'));
  const board = decodePng(path.join(REVIEW_DIR, 'rank2-review-board.png'));

  assert.equal(nmAtlas.width, 512);
  assert.equal(nmAtlas.height, 320);
  assert.equal(nmIcon.width, 32);
  assert.equal(nmIcon.height, 32);
  assert.equal(bnAtlas.width, 768);
  assert.equal(bnAtlas.height, 384);
  assert.equal(bnIcon.width, 32);
  assert.equal(bnIcon.height, 32);
  assert.equal(board.width, 768);
  assert.equal(board.height, 592);

  assertBinaryAlphaAndMacro2x2(nmAtlas, 'nguyet-mang-co.png', true);
  assertBinaryAlphaAndMacro2x2(nmIcon, 'nguyet-mang-co-icon.png', false);
  assertBinaryAlphaAndMacro2x2(bnAtlas, 'bach-ngoc-co.png', true);
  assertBinaryAlphaAndMacro2x2(bnIcon, 'bach-ngoc-co-icon.png', false);

  const manifest = JSON.parse(fs.readFileSync(path.join(REVIEW_DIR, 'rank2-review.json'), 'utf8'));
  const nmClips = manifest.assets['nguyet-mang-co'].clips;
  const bnClips = manifest.assets['bach-ngoc-co'].clips;

  // Verify Nguyet Mang populated vs unused cells & normal vs Nguyet An palette differentiation
  for (const [row, key] of [[0, 'flight'], [1, 'impact'], [2, 'flight_marked'], [3, 'impact_marked']]) {
    for (let col = 0; col < 8; col++) {
      const stats = cellBBox(nmAtlas, col, row, 64, 64);
      assert.ok(stats.opaque > 0, `nguyet-mang-co row ${row} col ${col} must be populated`);
      assert.deepEqual(stats.bbox, nmClips[key].bboxes64[col]);
    }
  }
  for (let col = 0; col < 6; col++) {
    const stats = cellBBox(nmAtlas, col, 4, 64, 64);
    assert.ok(stats.opaque > 0, `mark_emblem col ${col} must be populated`);
    assert.deepEqual(stats.bbox, nmClips.mark_emblem.bboxes64[col]);
  }
  for (const col of [6, 7]) {
    assert.equal(cellBBox(nmAtlas, col, 4, 64, 64).opaque, 0, `mark_emblem col ${col} must remain empty`);
  }

  let normalGoldCount = 0;
  let markedGoldCount = 0;
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 512; x++) {
      const i0 = (y * 512 + x) * 4;
      if (nmAtlas.data[i0 + 3] > 0 && nmAtlas.data[i0] > nmAtlas.data[i0 + 2] + 40) normalGoldCount += 1;
      const i2 = ((128 + y) * 512 + x) * 4;
      if (nmAtlas.data[i2 + 3] > 0 && nmAtlas.data[i2] > nmAtlas.data[i2 + 2] + 40) markedGoldCount += 1;
    }
  }
  assert.equal(normalGoldCount, 0, 'normal flight row must remain cool lunar cyan/white');
  assert.ok(markedGoldCount > 200, 'flight_marked row must highlight Nguyet An golden resonance');

  // Verify Bach Ngoc populated cells & warm ivory-white palette (not celadon green)
  for (const [row, key] of [[0, 'cast'], [1, 'sustain'], [2, 'impact_deflect']]) {
    for (let col = 0; col < 6; col++) {
      const stats = cellBBox(bnAtlas, col, row, 128, 128);
      assert.ok(stats.opaque > 0, `bach-ngoc-co row ${row} col ${col} must be populated`);
      assert.deepEqual(stats.bbox, bnClips[key].bboxes128[col]);
    }
  }
  let warmIvoryPixels = 0;
  let celadonGreenPixels = 0;
  for (let i = 0; i < bnAtlas.data.length; i += 4) {
    if (bnAtlas.data[i + 3] === 0) continue;
    const r = bnAtlas.data[i];
    const g = bnAtlas.data[i + 1];
    const b = bnAtlas.data[i + 2];
    if (r >= 200 && g >= 195 && r >= g && g >= b) warmIvoryPixels += 1;
    if (g > r + 15) celadonGreenPixels += 1;
  }
  assert.ok(warmIvoryPixels > 3000, 'bach-ngoc-co must render warm ivory-white tones');
  assert.equal(celadonGreenPixels, 0, 'bach-ngoc-co must avoid celadon-green collision with Ngoc Bi');

  // Aseprite headers & animated play-scale GIFs
  const nmAse = readAsepriteHeader(path.join(REVIEW_DIR, 'nguyet-mang-co.aseprite'));
  assert.deepEqual(nmAse, { magic: 0xA5E0, frames: 38, width: 64, height: 64 });
  const bnAse = readAsepriteHeader(path.join(REVIEW_DIR, 'bach-ngoc-co.aseprite'));
  assert.deepEqual(bnAse, { magic: 0xA5E0, frames: 18, width: 128, height: 128 });

  for (const gifName of ['nguyet-mang-compare-play-scale.gif', 'bach-ngoc-compare-play-scale.gif']) {
    const gb = fs.readFileSync(path.join(REVIEW_DIR, gifName));
    assert.equal(gb.subarray(0, 6).toString('ascii'), 'GIF89a', `${gifName} GIF89a header`);
    assert.ok(gb.length > 15000, `${gifName} must contain multi-frame play-scale comparison`);
  }

  assert.equal(manifest.activityReuseEvaluation.rawAtlasReused, false);
  const readme = fs.readFileSync(path.join(REVIEW_DIR, 'README.md'), 'utf8');
  assert.match(readme, /Chương 98/);
  assert.match(readme, /Chương 100/);
  assert.match(readme, /Nguyệt Ấn/);
  assert.match(readme, /Activity/);
});
