import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';

const reviewDir = path.resolve('godot-combat/assets/guard-review');

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

test('huyen-bao-guard atlas, Aseprite source, and manifest match 4-phase Godot guard exchange specification', () => {
  const meta = JSON.parse(fs.readFileSync(path.join(reviewDir, 'guard-review.json'), 'utf8'));
  const png = decodePng(path.join(reviewDir, 'huyen-bao-guard.png'));

  assert.equal(png.width, 1024);
  assert.equal(png.height, 256);
  assert.deepEqual(meta.cellSize, [128, 128]);
  assert.deepEqual(meta.grid, [8, 2]);
  assert.deepEqual(meta.footAnchor128, [64, 120]);
  assert.deepEqual(meta.godotRender.sleeveBlockPoint128, [88, 76]);
  assert.equal(meta.sequenceTiming.totalDurationMs, 930);
  assert.equal(meta.sequenceTiming.contactMs, 520);
  assert.equal(meta.sequenceTiming.contactHeroFrame, 4);
  assert.equal(meta.sequenceTiming.contactWolfFrame, 10);

  // Strict binary alpha (0 | 255) and 2x2 macro-pixel grid (0 mixels)
  let mixels = 0;
  for (let y = 0; y < png.height; y += 2) {
    for (let x = 0; x < png.width; x += 2) {
      const i00 = (y * png.width + x) * 4;
      const a = png.data[i00 + 3];
      assert.ok(a === 0 || a === 255, `Non-binary alpha ${a} at (${x},${y})`);
      for (const [dx, dy] of [[1, 0], [0, 1], [1, 1]]) {
        const idx = ((y + dy) * png.width + (x + dx)) * 4;
        if (
          png.data[idx] !== png.data[i00] ||
          png.data[idx + 1] !== png.data[i00 + 1] ||
          png.data[idx + 2] !== png.data[i00 + 2] ||
          png.data[idx + 3] !== png.data[i00 + 3]
        ) {
          mixels++;
        }
      }
    }
  }
  assert.equal(mixels, 0, 'Expected strict 2x2 macro-pixel grid with 0 1x1 mixels');

  // All 8 actor frames (Row 0) must sit on baseline y1 = 121 (60*2+1) and have opaque pixels at sleeveBlockPoint128=[88,76] during guard/contact (frames 2..5)
  for (let c = 0; c < 8; c++) {
    const fMeta = meta.frames[c];
    assert.equal(fMeta.actorBBox128.y1, 121, `Frame ${c} foot baseline must be 121`);
    assert.ok(fMeta.wardFxBBox128.x1 >= fMeta.wardFxBBox128.x0, `Row 1 Ward FX frame ${c} must be populated`);
    if (c >= 2 && c <= 5) {
      const blockX = c === 4 ? 86 : 88;
      const bi = (76 * png.width + (c * 128 + blockX)) * 4;
      assert.equal(png.data[bi + 3], 255, `Frame ${c} must have solid sleeve block pixels at (${blockX}, 76)`);
    }
  }

  // Contact frame 4 must recoil 4px left relative to hold frame 3
  assert.equal(meta.frames[4].actorBBox128.x0, meta.frames[3].actorBBox128.x0 - 4);

  // Verify Aseprite file header (0xA5E0) and 8 frame magic numbers (0xF1FA)
  const ase = fs.readFileSync(path.join(reviewDir, 'huyen-bao-guard.aseprite'));
  assert.equal(ase.readUInt16LE(4), 0xA5E0);
  assert.equal(ase.readUInt16LE(6), 8);
  assert.equal(ase.readUInt16LE(8), 128);
  assert.equal(ase.readUInt16LE(10), 128);
  assert.equal(ase.readUInt16LE(128 + 4), 0xF1FA);

  // Verify play-scale GIF and comparison board exist and are non-empty
  assert.ok(fs.statSync(path.join(reviewDir, 'guard-exchange-play-scale.gif')).size > 4000);
  assert.ok(fs.statSync(path.join(reviewDir, 'guard-comparison-strip.png')).size > 10000);
});
