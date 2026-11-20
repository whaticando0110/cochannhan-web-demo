import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';

const reviewDir = path.resolve('godot-combat/assets/terrain-telegraphs-review');

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

test('terrain-telegraphs atlas, Aseprite source, manifest, and play-scale 8x5 mockups match Godot 91x82 tile grid', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(reviewDir, 'terrain-telegraphs.json'), 'utf8'));
  const atlas = decodePng(path.join(reviewDir, 'terrain-telegraphs.png'));

  assert.equal(atlas.width, 364);
  assert.equal(atlas.height, 328);
  assert.deepEqual(manifest.tileSize, [91, 82]);
  assert.deepEqual(manifest.grid, [4, 4]);
  assert.deepEqual(manifest.boardSize, [803, 477]);

  // Every 91x82 tile cell must have drawn pixels
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      let drawn = 0;
      for (let y = 0; y < 82; y++) {
        for (let x = 0; x < 91; x++) {
          if (atlas.data[((r * 82 + y) * 364 + (c * 91 + x)) * 4 + 3] > 0) drawn++;
        }
      }
      assert.ok(drawn > 100, `Telegraph cell (${c},${r}) must be populated`);
    }
  }

  // Interior actor zone (x=24..66, y=28..53) of mid-lane charge (1,1) & boss sweep (1,2) must stay translucent
  // so characters and terrain remain readable underneath!
  for (const [col, row] of [[1, 1], [1, 2]]) {
    let sumA = 0;
    let count = 0;
    for (let y = 28; y <= 53; y++) {
      for (let x = 24; x <= 66; x++) {
        sumA += atlas.data[((row * 82 + y) * 364 + (col * 91 + x)) * 4 + 3];
        count++;
      }
    }
    const avgAlpha = sumA / count;
    assert.ok(avgAlpha <= 60, `Mid-corridor cell (${col},${row}) interior avgAlpha=${avgAlpha} must stay <= 60`);
  }

  // Verify Aseprite file (0xA5E0, 16 frames of 91x82)
  const ase = fs.readFileSync(path.join(reviewDir, 'terrain-telegraphs.aseprite'));
  assert.equal(ase.readUInt16LE(4), 0xA5E0);
  assert.equal(ase.readUInt16LE(6), 16);
  assert.equal(ase.readUInt16LE(8), 91);
  assert.equal(ase.readUInt16LE(10), 82);

  // Verify all 3 play-scale 8x5 mockups match arena dimensions 803x477
  for (const file of [
    'mockup-1-khe-da-cover.png',
    'mockup-2-loi-san-tinh-anh-charge.png',
    'mockup-3-hang-cuong-dien-lang-sweep.png',
  ]) {
    const m = decodePng(path.join(reviewDir, file));
    assert.equal(m.width, 803, `${file} must match 803px board width`);
    assert.equal(m.height, 477, `${file} must match 477px board height`);
  }

  const legend = decodePng(path.join(reviewDir, 'telegraph-legend-strip.png'));
  assert.equal(legend.width, 364);
  assert.equal(legend.height, 328);
});
