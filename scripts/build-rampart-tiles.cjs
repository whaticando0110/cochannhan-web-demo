const { createHash } = require('node:crypto');
const { mkdirSync, readFileSync, writeFileSync } = require('node:fs');
const { basename, join, resolve } = require('node:path');

const [codec, cornerFile, wallFile, yardFile, output] = process.argv.slice(2);
if (!output) throw new Error('Usage: node build-rampart-tiles.cjs <pixel-png.cjs> <upper-left.png> <upper-right.png> <lower-right.png> <output>');
const { decode, encode } = require(resolve(codec));
const [corner, wall, yard] = [cornerFile, wallFile, yardFile].map(decode);
const size = 48;
const atlasColumns = 8;
const atlasRows = 9;
const atlas = blank(atlasColumns * size, atlasRows * size);
const entries = {};
const images = {};

function blank(width, height) {
  return { width, height, data: Buffer.alloc(width * height * 4) };
}

function sample(image, x, y) {
  const col = Math.max(0, Math.min(image.width - 1, Math.floor(x)));
  const row = Math.max(0, Math.min(image.height - 1, Math.floor(y)));
  const index = (row * image.width + col) * 4;
  return image.data.subarray(index, index + 4);
}

function make(width, height, colorAt) {
  const result = blank(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) result.data.set(colorAt(x, y), (y * width + x) * 4);
  }
  return result;
}

function smooth(value) {
  const ratio = Math.min(1, Math.max(0, value));
  return ratio * ratio * (3 - 2 * ratio);
}

function mix(a, b, factor) {
  return a.map((value, index) => Math.round(value + (b[index] - value) * factor));
}

function periodic(patch, x, y) {
  const edge = size - 1;
  const tx = smooth(x / 14);
  const ty = smooth(y / 14);
  const wrapX = x < 14 ? x + edge : x;
  const wrapY = y < 14 ? y + edge : y;
  const top = mix(patch(wrapX, wrapY), patch(x, wrapY), tx);
  const bottom = mix(patch(wrapX, y), patch(x, y), tx);
  return mix(top, bottom, ty);
}

function material(image, origins, stepX, stepY) {
  const patches = origins.map(([left, top]) => (x, y) => [...sample(image, left + x * stepX, top + y * stepY)]);
  return patches.map((patch, variant) => make(size, size, (x, y) => {
    const base = periodic(patches[0], x, y);
    if (variant === 0) return base;
    const distance = Math.min(x, y, size - 1 - x, size - 1 - y);
    return mix(base, periodic(patch, x, y), smooth(distance / 9) * 0.85);
  }));
}

function rotateLeft(image) {
  return make(image.height, image.width, (x, y) => sample(image, image.width - 1 - y, x));
}

function slice(image, source, width, height, opacity) {
  const { x: left, y: top, w, h } = source;
  return make(width, height, (x, y) => {
    const pixel = [...sample(image, left + (x + 0.5) * w / width, top + (y + 0.5) * h / height)];
    pixel[3] = opacity(x, y);
    return pixel;
  });
}

function draw(destination, image, left, top, blend = false) {
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      const target = ((top + y) * destination.width + left + x) * 4;
      const start = (y * image.width + x) * 4;
      const alpha = image.data[start + 3];
      if (!blend || alpha === 255) {
        image.data.copy(destination.data, target, start, start + 4);
      } else if (alpha) {
        for (let channel = 0; channel < 3; channel++) {
          destination.data[target + channel] = (image.data[start + channel] * alpha +
            destination.data[target + channel] * (255 - alpha)) / 255;
        }
      }
    }
  }
}

function place(id, image, col, row, gameplay) {
  const x = col * size;
  const y = row * size;
  if (x + image.width > atlas.width || y + image.height > atlas.height) throw new Error(`Tile out of bounds: ${id}`);
  for (const rect of Object.values(entries)) {
    if (x < rect.x + rect.width && x + image.width > rect.x && y < rect.y + rect.height && y + image.height > rect.y) {
      throw new Error(`Tile overlaps an existing frame: ${id}`);
    }
  }
  entries[id] = { x, y, width: image.width, height: image.height, ...gameplay };
  images[id] = image;
  draw(atlas, image, x, y);
}

const wood = material(wall, [[645, 336], [560, 341], [884, 331], [287, 340]], 1.83, 1.25);
const sets = {
  mud: material(corner, [[261, 432], [396, 328], [245, 607], [384, 679]], 1.65, 1.65),
  stone: material(yard, [[899, 524], [1029, 638], [1195, 457], [1440, 662]], 2.04, 1.72),
  'deck-east': wood,
  'deck-south': wood.map(rotateLeft),
  bamboo: material(corner, [[12, 20], [8, 287], [4, 506], [16, 727]], 1.64, 1.48),
};

function assertEdges(variants) {
  for (const tile of variants) {
    for (let i = 0; i < size; i++) {
      const base = variants[0];
      if (!sample(tile, 0, i).equals(sample(base, size - 1, i)) ||
          !sample(tile, size - 1, i).equals(sample(base, 0, i)) ||
          !sample(tile, i, 0).equals(sample(base, i, size - 1)) ||
          !sample(tile, i, size - 1).equals(sample(base, i, 0))) {
        throw new Error('Terrain variant has incompatible edges');
      }
    }
  }
}

const families = {};
Object.entries(sets).forEach(([name, variants], row) => {
  assertEdges(variants);
  families[name] = variants.map((tile, index) => {
    const id = `${name}-${index + 1}`;
    place(id, tile, index, row, {
      layer: 'surface',
      walkable: name !== 'bamboo',
      elevation: name.startsWith('deck') ? 1 : 0,
    });
    return id;
  });
});

const north = slice(wall, { x: 624, y: 247, w: 96, h: 87 }, size, size,
  (x, y) => y >= 4 + 0.65 * Math.abs(x % 12 - 6) ? 255 : 0);
const turn = slice(corner, { x: 613, y: 245, w: 139, h: 139 }, size, size,
  (x, y) => x + y >= 21 && x >= 3 && y >= 3 ? 255 : 0);
const support = slice(wall, { x: 908, y: 421, w: 111, h: 103 }, size, size, (x, y) => {
  if (y <= 11) return 255;
  const center = Math.abs(x - 23);
  if (y <= 44 && center <= 5.5) return 255;
  if (y <= 26 && Math.abs(center - (25 - y)) < 2.25) return 230;
  return Math.round(50 * (1 - smooth((y - 11) / 25)));
});
const fringe = slice(corner, { x: 3, y: 248, w: 112, h: 100 }, size, size, (x, y) => {
  const tip = Math.max(x * 0.9, y * 0.62);
  return Math.round((1 - smooth((tip - 20) / 23)) * 255);
});
const forestEdge = make(size, size, (x, y) => {
  const color = sample(sets.bamboo[0], x, y);
  const angle = x * 2 * Math.PI / (size - 1);
  const tip = 18 + 7 * Math.sin(angle) + 4 * Math.sin(3 * angle) + (color[1] - color[0]) / 6;
  const alpha = Math.round(255 * (1 - smooth((y - tip) / 7)));
  return [color[0], color[1], color[2], alpha];
});
const stairs = slice(wall, { x: 1167, y: 380, w: 173, h: 266 }, size * 2, size * 3, (x, y) => {
  const margin = y <= 14 || y >= 105 ? 2 : 5;
  return x >= margin && x < 96 - margin && y >= 3 && y < 141 ? 255 : 0;
});
const wallRules = { layer: 'structure', walkable: false, blocksVisionAtGround: true };
const decoration = { layer: 'overlay' };
place('palisade-north', north, 0, 5, wallRules);
place('palisade-west', rotateLeft(north), 1, 5, wallRules);
place('palisade-corner-nw', turn, 2, 5, wallRules);
place('platform-edge-south', support, 3, 5, decoration);
place('platform-edge-east', rotateLeft(support), 4, 5, decoration);
place('bamboo-fringe', fringe, 5, 5, decoration);
place('bamboo-edge-south', forestEdge, 6, 5, decoration);
place('bamboo-edge-east', rotateLeft(forestEdge), 7, 5, decoration);
place('stairs-up-north', stairs, 0, 6, { layer: 'structure', footprint: [2, 3], uphill: 'north', levels: [0, 1] });
place('stairs-up-west', rotateLeft(stairs), 3, 6, { layer: 'structure', footprint: [3, 2], uphill: 'west', levels: [0, 1] });

function buildPreview(seed) {
  const columns = 24;
  const rows = 16;
  const result = blank(columns * size, rows * size);
  const northWall = 4;
  const westWall = 6;
  const add = (id, col, row) => draw(result, images[id], col * size, row * size, true);
  const terrain = (family, col, row) => {
    const value = (Math.imul(col + seed, 0x45d9f3b) ^ Math.imul(row + 1, 0x119de1f3)) >>> 0;
    const mixed = Math.imul(value ^ (value >>> 15), 0x7feb352d) >>> 0;
    add(families[family][(mixed >>> 9) % families[family].length], col, row);
  };
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < columns; col++) {
      const fullCanopy = row <= 1 || col <= 1;
      const inside = row > northWall && col > westWall;
      terrain(inside ? 'stone' : fullCanopy ? 'bamboo' : 'mud', col, row);
      if (!fullCanopy && row === 2) add('bamboo-edge-south', col, row);
      if (!fullCanopy && col === 2) add('bamboo-edge-east', col, row);
      if (!inside && col === 3 && row > 3 && row % 4 === 0) add('bamboo-fringe', col, row);
      if (inside && row <= 6) terrain('deck-east', col, row);
      else if (inside && col <= 8) terrain('deck-south', col, row);
    }
  }
  for (let col = westWall + 1; col < columns; col++) add('palisade-north', col, northWall);
  for (let row = northWall + 1; row < rows; row++) add('palisade-west', westWall, row);
  add('palisade-corner-nw', westWall, northWall);
  for (let col = 9; col < columns; col++) add('platform-edge-south', col, 7);
  for (let row = 8; row < rows; row++) add('platform-edge-east', 9, row);
  add('stairs-up-north', 15, 7);
  add('stairs-up-west', 9, 11);
  return result;
}

const sources = [cornerFile, wallFile, yardFile].map(file => ({
  name: basename(file),
  sha256: createHash('sha256').update(readFileSync(file)).digest('hex'),
}));
const manifest = {
  name: 'Cổ Nguyệt Sơn Trại · Lũy gỗ',
  version: 1,
  tileSize: size,
  atlas: { file: 'atlas.png', width: atlas.width, height: atlas.height },
  sources,
  families,
  frames: entries,
};
mkdirSync(output, { recursive: true });
writeFileSync(join(output, 'atlas.png'), encode(atlas.data, atlas.width, atlas.height));
const preview = buildPreview(29);
writeFileSync(join(output, 'preview.png'), encode(preview.data, preview.width, preview.height));
writeFileSync(join(output, 'tileset.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`${Object.keys(entries).length} atlas frames, ${Object.keys(families).length} checked terrain families, preview ${preview.width}×${preview.height}`);
