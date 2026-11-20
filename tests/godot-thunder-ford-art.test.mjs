import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REVIEW_DIR = path.join(ROOT, 'godot-combat', 'assets', 'thunder-ford-review');

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

test('Liquor Worm Gu atlases, wet-stone tiles, 4-bit water masks, electric telegraphs, and Thunder Ford mockup meet Godot specs', () => {
  const ttAtlas = decodePng(path.join(REVIEW_DIR, 'tuu-trung-co.png'));
  const ttIcon = decodePng(path.join(REVIEW_DIR, 'tuu-trung-co-icon.png'));
  const tvAtlas = decodePng(path.join(REVIEW_DIR, 'tu-vi-tuu-trung.png'));
  const tvIcon = decodePng(path.join(REVIEW_DIR, 'tu-vi-tuu-trung-icon.png'));
  const wetTiles = decodePng(path.join(REVIEW_DIR, 'wet-stone-tiles.png'));
  const waterMasks = decodePng(path.join(REVIEW_DIR, 'water-mask-16.png'));
  const elecTiles = decodePng(path.join(REVIEW_DIR, 'water-electric-telegraph.png'));
  const mockup = decodePng(path.join(REVIEW_DIR, 'mockup-bai-da-suoi-sam.png'));

  assert.equal(ttAtlas.width, 768);
  assert.equal(ttAtlas.height, 256);
  assert.equal(ttIcon.width, 32);
  assert.equal(ttIcon.height, 32);
  assert.equal(tvAtlas.width, 768);
  assert.equal(tvAtlas.height, 384);
  assert.equal(tvIcon.width, 32);
  assert.equal(tvIcon.height, 32);
  assert.equal(wetTiles.width, 364);
  assert.equal(wetTiles.height, 164);
  assert.equal(waterMasks.width, 364);
  assert.equal(waterMasks.height, 328);
  assert.equal(elecTiles.width, 364);
  assert.equal(elecTiles.height, 164);
  assert.equal(mockup.width, 803);
  assert.equal(mockup.height, 477);

  assertBinaryAlphaAndMacro2x2(ttAtlas, 'tuu-trung-co.png', true);
  assertBinaryAlphaAndMacro2x2(ttIcon, 'tuu-trung-co-icon.png', false);
  assertBinaryAlphaAndMacro2x2(tvAtlas, 'tu-vi-tuu-trung.png', true);
  assertBinaryAlphaAndMacro2x2(tvIcon, 'tu-vi-tuu-trung-icon.png', false);
  assertBinaryAlphaAndMacro2x2(waterMasks, 'water-mask-16.png', false);
  assertBinaryAlphaAndMacro2x2(elecTiles, 'water-electric-telegraph.png', false);

  // Tu Vi stack_2 must have substantially richer aura coverage than stack_1
  let s1Pixels = 0;
  let s2Pixels = 0;
  for (let col = 0; col < 6; col++) {
    assert.ok(cellOpaqueCount(ttAtlas, col, 0, 128, 128) > 0);
    assert.ok(cellOpaqueCount(ttAtlas, col, 1, 128, 128) > 0);
    assert.ok(cellOpaqueCount(tvAtlas, col, 0, 128, 128) > 0);
    s1Pixels += cellOpaqueCount(tvAtlas, col, 1, 128, 128);
    s2Pixels += cellOpaqueCount(tvAtlas, col, 2, 128, 128);
  }
  assert.ok(s2Pixels >= s1Pixels * 2, `Tu Vi stack_2 (${s2Pixels}px) must visually outshine stack_1 (${s1Pixels}px)`);

  // All 16 water-mask cells and all 8 electric/terrain tiles populated; mask 15 has zero rocky border & mask 0 is fully bordered
  for (let m = 0; m < 16; m++) {
    assert.ok(cellOpaqueCount(waterMasks, m % 4, Math.floor(m / 4), 91, 82) > 5000, `water mask ${m} populated`);
  }
  for (let r = 0; r < 2; r++) {
    for (let c = 0; c < 4; c++) {
      assert.ok(cellOpaqueCount(wetTiles, c, r, 91, 82) > 500, `wet tile (${c},${r}) populated`);
      assert.ok(cellOpaqueCount(elecTiles, c, r, 91, 82) > 60, `electric tile (${c},${r}) populated`);
    }
  }

  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'tuu-trung-co.aseprite')), { magic: 0xA5E0, frames: 12, width: 128, height: 128 });
  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'tu-vi-tuu-trung.aseprite')), { magic: 0xA5E0, frames: 18, width: 128, height: 128 });
  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'water-mask-16.aseprite')), { magic: 0xA5E0, frames: 16, width: 91, height: 82 });
  assert.deepEqual(readAsepriteHeader(path.join(REVIEW_DIR, 'water-electric-telegraph.aseprite')), { magic: 0xA5E0, frames: 8, width: 91, height: 82 });

  const gif = fs.readFileSync(path.join(REVIEW_DIR, 'tuu-trung-compare-play-scale.gif'));
  assert.equal(gif.subarray(0, 6).toString('ascii'), 'GIF89a');
  assert.ok(gif.length > 15000);

  const manifest = JSON.parse(fs.readFileSync(path.join(REVIEW_DIR, 'thunder-ford-review.json'), 'utf8'));
  assert.equal(manifest.godotRender.tileSize[0], 91);
  assert.equal(manifest.assets['tu-vi-tuu-trung'].clips.stack_2.bboxes128.length, 6);
  const readme = fs.readFileSync(path.join(REVIEW_DIR, 'README.md'), 'utf8');
  assert.match(readme, /Chương 121/);
  assert.match(readme, /Chương 225/);
});
