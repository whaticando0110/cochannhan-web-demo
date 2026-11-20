import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';

const reviewDir = path.resolve('godot-combat/assets/gu-review');

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

function assertBinaryMacroAtlas(png, cols, rows) {
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

  const cw = png.width / cols;
  const ch = png.height / rows;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      let count = 0;
      for (let y = 0; y < ch; y++) {
        for (let x = 0; x < cw; x++) {
          if (png.data[((r * ch + y) * png.width + (c * cw + x)) * 4 + 3] > 0) count++;
        }
      }
      assert.ok(count > 0, `Cell (${c},${r}) must be populated`);
    }
  }
}

test('ngoc-bi-co and sinh-co-diep Godot atlases, icons, Aseprite sources, and manifest match specification', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(reviewDir, 'gu-review.json'), 'utf8'));

  const ngocPng = decodePng(path.join(reviewDir, 'ngoc-bi-co.png'));
  assert.equal(ngocPng.width, 768);
  assert.equal(ngocPng.height, 384);
  assertBinaryMacroAtlas(ngocPng, 6, 3);

  const sinhPng = decodePng(path.join(reviewDir, 'sinh-co-diep.png'));
  assert.equal(sinhPng.width, 1024);
  assert.equal(sinhPng.height, 128);
  assertBinaryMacroAtlas(sinhPng, 8, 1);

  for (const iconName of ['ngoc-bi-co-icon.png', 'sinh-co-diep-icon.png']) {
    const icon = decodePng(path.join(reviewDir, iconName));
    assert.equal(icon.width, 32);
    assert.equal(icon.height, 32);
    let opaque = 0;
    for (let i = 3; i < icon.data.length; i += 4) {
      assert.ok(icon.data[i] === 0 || icon.data[i] === 255);
      if (icon.data[i] === 255) opaque++;
    }
    assert.ok(opaque > 80, `${iconName} must have crisp icon pixels`);
  }

  const ngocAse = fs.readFileSync(path.join(reviewDir, 'ngoc-bi-co.aseprite'));
  assert.equal(ngocAse.readUInt16LE(4), 0xA5E0);
  assert.equal(ngocAse.readUInt16LE(6), 18);
  assert.equal(ngocAse.readUInt16LE(8), 128);
  assert.equal(ngocAse.readUInt16LE(10), 128);

  const sinhAse = fs.readFileSync(path.join(reviewDir, 'sinh-co-diep.aseprite'));
  assert.equal(sinhAse.readUInt16LE(4), 0xA5E0);
  assert.equal(sinhAse.readUInt16LE(6), 8);
  assert.equal(sinhAse.readUInt16LE(8), 128);
  assert.equal(sinhAse.readUInt16LE(10), 128);

  assert.equal(manifest.assets['ngoc-bi-co'].clips.cast.durationMs, 510);
  assert.equal(manifest.assets['ngoc-bi-co'].clips.impact_flash.contactEndMs, 115);
  assert.equal(manifest.assets['sinh-co-diep'].clips.heal.durationMs, 680);
  assert.equal(manifest.assets['sinh-co-diep'].clips.heal.healPeakMs, 240);

  assert.ok(fs.statSync(path.join(reviewDir, 'ngoc-bi-co-play-scale.gif')).size > 5000);
  assert.ok(fs.statSync(path.join(reviewDir, 'sinh-co-diep-play-scale.gif')).size > 5000);
  assert.ok(fs.statSync(path.join(reviewDir, 'gu-review-board.png')).size > 15000);
});
