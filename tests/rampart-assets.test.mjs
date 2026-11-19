import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';

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

test('huyet-nguyet atlas and metadata match exact cell layout and binary alpha', () => {
  const meta = JSON.parse(fs.readFileSync(path.join(rampartDir, 'huyet-nguyet.json'), 'utf8'));
  const img = decodePng(path.join(rampartDir, meta.file));
  assert.equal(img.width, 512);
  assert.equal(img.height, 320);
  assert.deepEqual(meta.cellSize, [64, 64]);
  assert.deepEqual(meta.grid, [8, 5]);
  assert.deepEqual(meta.pivot, [32, 32]);
  for (let i = 3; i < img.data.length; i += 4) {
    assert.ok(img.data[i] === 0 || img.data[i] === 255);
  }
  const expectedCounts = {
    flight: 8,
    impact_slash: 4,
    impact_block: 4,
    cast: 6,
    bleed_tick: 6,
    blood_trail: 4,
  };
  for (const [name, expected] of Object.entries(expectedCounts)) {
    const clip = meta.clips[name];
    assert.equal(clip.count, expected);
    assert.equal(clip.frames.length, expected);
    for (const f of clip.frames) {
      let count = 0;
      for (let y = f.y; y < f.y + f.h; y++) {
        for (let x = f.x; x < f.x + f.w; x++) {
          if (img.data[(y * img.width + x) * 4 + 3] > 0) count++;
        }
      }
      assert.ok(count > 0, `Frame ${name} (${f.col},${f.row}) must be non-empty`);
    }
  }
});

test('kim-chung-trao atlas and metadata preserve 96x96 bell geometry, ground pivot, and binary alpha', () => {
  const meta = JSON.parse(fs.readFileSync(path.join(rampartDir, 'kim-chung-trao.json'), 'utf8'));
  const img = decodePng(path.join(rampartDir, meta.file));
  assert.equal(img.width, 768);
  assert.equal(img.height, 480);
  assert.deepEqual(meta.cellSize, [96, 96]);
  assert.deepEqual(meta.grid, [8, 5]);
  assert.deepEqual(meta.groundPivot, [48, 82]);
  assert.deepEqual(meta.supportedRanks, [3, 4]);
  for (let i = 3; i < img.data.length; i += 4) {
    assert.ok(img.data[i] === 0 || img.data[i] === 255);
  }
  const expectedCounts = {
    cast: 6,
    sustain_back: 8,
    sustain_front: 8,
    block: 6,
    shatter: 6,
  };
  for (const [name, expected] of Object.entries(expectedCounts)) {
    const clip = meta.clips[name];
    assert.equal(clip.count, expected);
    assert.equal(clip.frames.length, expected);
    for (const f of clip.frames) {
      let count = 0;
      for (let y = f.y; y < f.y + f.h; y++) {
        for (let x = f.x; x < f.x + f.w; x++) {
          if (img.data[(y * img.width + x) * 4 + 3] > 0) count++;
        }
      }
      assert.ok(count > 0, `Frame ${name} (${f.col},${f.row}) must be non-empty`);
    }
  }
});
