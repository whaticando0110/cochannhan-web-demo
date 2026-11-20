import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REVIEW_DIR = path.join(ROOT, 'godot-combat', 'assets', 'ambush-veil-review');

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

function cellOpaqueCount(img, col, row, cw, ch) {
  let opaque = 0;
  for (let y = 0; y < ch; y++) {
    for (let x = 0; x < cw; x++) {
      const i = ((row * ch + y) * img.width + (col * cw + x)) * 4;
      if (img.data[i + 3] > 0) opaque += 1;
    }
  }
  return opaque;
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

test('Stealth Gu (reusing Activity An Lan + An Thach) and Ambush Canyon split-rock/rockfall art pack meet Godot specs', () => {
  const anLanAtlas = decodePng(path.join(REVIEW_DIR, 'an-lan-co.png'));
  const anLanIcon = decodePng(path.join(REVIEW_DIR, 'an-lan-co-icon.png'));
  const anThachAtlas = decodePng(path.join(REVIEW_DIR, 'an-thach-co.png'));
  const anThachIcon = decodePng(path.join(REVIEW_DIR, 'an-thach-co-icon.png'));
  const canyonTiles = decodePng(path.join(REVIEW_DIR, 'ambush-canyon-tiles.png'));
  const rfTiles = decodePng(path.join(REVIEW_DIR, 'rockfall-telegraph.png'));
  const mockup = decodePng(path.join(REVIEW_DIR, 'mockup-hem-da-phuc-kich.png'));

  assert.equal(anLanAtlas.width, 1024);
  assert.equal(anLanAtlas.height, 512);
  assert.equal(anLanIcon.width, 32);
  assert.equal(anLanIcon.height, 32);
  assert.equal(anThachAtlas.width, 768);
  assert.equal(anThachAtlas.height, 384);
  assert.equal(anThachIcon.width, 32);
  assert.equal(anThachIcon.height, 32);
  assert.equal(canyonTiles.width, 364);
  assert.equal(canyonTiles.height, 164);
  assert.equal(rfTiles.width, 364);
  assert.equal(rfTiles.height, 164);
  assert.equal(mockup.width, 803);
  assert.equal(mockup.height, 477);

  assertBinaryAlphaAndMacro2x2(anLanAtlas, 'an-lan-co.png', true);
  assertBinaryAlphaAndMacro2x2(anLanIcon, 'an-lan-co-icon.png', false);
  assertBinaryAlphaAndMacro2x2(anThachAtlas, 'an-thach-co.png', true);
  assertBinaryAlphaAndMacro2x2(anThachIcon, 'an-thach-co-icon.png', false);
  assertBinaryAlphaAndMacro2x2(rfTiles, 'rockfall-telegraph.png', false);

  // Verify Activity An Lan rows 0..2 preserve exact 5 Activity colors losslessly
  const allowedActivityHex = new Set(['#1f4b66', '#4292ba', '#7cd4ee', '#c8f6ff', '#f2fcff']);
  for (const [row, count] of [[0, 4], [1, 8], [2, 4]]) {
    for (let col = 0; col < count; col++) {
      assert.ok(cellOpaqueCount(anLanAtlas, col, row, 128, 128) > 0, `an-lan row ${row} col ${col} populated`);
    }
  }
  for (let y = 0; y < 384; y++) {
    for (let x = 0; x < 1024; x++) {
      const i = (y * 1024 + x) * 4;
      if (anLanAtlas.data[i + 3] === 0) continue;
      const hex = '#' + [anLanAtlas.data[i], anLanAtlas.data[i + 1], anLanAtlas.data[i + 2]]
        .map((v) => v.toString(16).padStart(2, '0')).join('');
      assert.ok(allowedActivityHex.has(hex), `Unpacked Activity An Lan frame color ${hex} mismatch`);
    }
  }
  for (let col = 0; col < 4; col++) {
    assert.ok(cellOpaqueCount(anLanAtlas, col, 3, 128, 128) > 0, `wolf_lost_target col ${col} populated`);
  }

  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 6; c++) {
      assert.ok(cellOpaqueCount(anThachAtlas, c, r, 128, 128) > 0, `an-thach (${c},${r}) populated`);
    }
  }

  // Amber rockfall row 0 uses amber hues (R >= G > B), distinct from coral pounce_ref_diagonal at (0,1)
  let amberPx = 0;
  for (let y = 0; y < 82; y++) {
    for (let x = 0; x < 364; x++) {
      const i = (y * 364 + x) * 4;
      if (rfTiles.data[i + 3] > 0 && rfTiles.data[i] >= 200 && rfTiles.data[i + 1] >= 100 && rfTiles.data[i] > rfTiles.data[i + 2] + 80) {
        amberPx += 1;
      }
    }
  }
  assert.ok(amberPx > 500, 'rockfall row 0 must prominently render warm amber warning tones');

  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'an-lan-co.aseprite')), { magic: 0xA5E0, frames: 20, width: 128, height: 128 });
  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'an-thach-co.aseprite')), { magic: 0xA5E0, frames: 18, width: 128, height: 128 });
  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'rockfall-telegraph.aseprite')), { magic: 0xA5E0, frames: 8, width: 91, height: 82 });

  const gif = fs.readFileSync(path.join(REVIEW_DIR, 'stealth-compare-play-scale.gif'));
  assert.equal(gif.subarray(0, 6).toString('ascii'), 'GIF89a');
  assert.ok(gif.length > 15000);

  const manifest = JSON.parse(fs.readFileSync(path.join(REVIEW_DIR, 'ambush-veil-review.json'), 'utf8'));
  assert.equal(manifest.activityReuseEvaluation.reusedActivityAtlasDirectly, true);
  assert.equal(manifest.godotRender.tileSize[0], 91);

  const readme = fs.readFileSync(path.join(REVIEW_DIR, 'README.md'), 'utf8');
  assert.match(readme, /Chương 116/);
  assert.match(readme, /Chương 121/);
  assert.match(readme, /Chương 130/);
});
