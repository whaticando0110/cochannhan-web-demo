// Build from the shipped Huyền bào atlas using the same offline PNG codec as the rampart packer.
const path = require('node:path');
const fs = require('node:fs');
const { decode, encode } = require(path.resolve(process.argv[2]));
const assets = path.join(__dirname, '../dist/assets');
const source = decode(path.join(assets, 'huyen-bao.png'));
const size = 64;
const width = 8 * size;
const rows = 4;
const pixels = Buffer.alloc(width * size * rows * 4);

// Toe contacts, weight transfer, passing foot, and swing before the next contact.
const ankleX = [39, 36, 32, 28, 24, 25, 31, 37];
const lift = [0, 0, 0, 0, 0, 3, 4, 2];
const kneeLead = [0, 1, 1, 0, 0, 2, 4, 2];
const weight = [0, 1, 0, -1, 0, 1, 0, -1];
// Longer reach at contact, folded recovery leg, then a short flight phase.
const runAnkle = [42, 37, 29, 21, 22, 26, 34, 40];
const runLift = [0, 0, 0, 2, 5, 8, 7, 3];
const runKnee = [1, 3, 2, 0, 2, 6, 8, 4];
const runWeight = [0, 2, 1, -1, 0, 2, 1, -1];
const idleSources = [0, 1, 2, 3, 4, 5, 1, 0];
const breath = [0, 0, 1, 1, 1, 0, 0, 0];
const clamp = n => Math.min(1, Math.max(0, n));

function paint(column, row, x, y, sx, sy, sourceFrame = 0) {
  sx = Math.round(sx);
  sy = Math.round(sy);
  if (sx < 0 || sx >= size || sy < 0 || sy >= size) return;
  const read = 4 * (sy * source.width + sourceFrame * size + sx);
  if (!source.data[read + 3]) return;
  source.data.copy(pixels, 4 * ((row * size + y) * width + column * size + x), read, read + 4);
}

function leg(frame, row, near) {
  const phase = (frame + (near ? 0 : 4)) % 8;
  const ankle = near ? 27 : 35;
  const running = row === 3;
  const height = running ? runLift[phase] : lift[phase] * (row === 1 ? 1.65 : 1);
  const reach = (running ? runAnkle : ankleX)[phase] - ankle;
  const knee = (running ? runKnee : kneeLead)[phase];
  for (let y = 47; y <= 60; y++) {
    const t = clamp((y - 47) / (13 - height));
    const bend = Math.sin(Math.PI * t);
    const shift = reach * t + knee * bend;
    for (let x = 13; x < 51; x++) {
      const sx = Math.round(x - shift);
      if ((sx < 32) === near) paint(frame, row, x, y, sx, y + height * t);
    }
  }
}

for (let frame = 0; frame < 8; frame++) {
  for (const row of [0, 1, 3]) {
    const running = row === 3;
    leg(frame, row, false);
    leg(frame, row, true);
    for (let y = 17; y < 57; y++) {
      for (let x = 16; x < 46; x++) {
        const arm = clamp((y - 34) / 14) * clamp((32 - x) / 5);
        const hem = clamp((y - 41) / 14);
        const swing = Math.sin(frame * Math.PI / 4);
        const lean = running ? 4 * clamp((51 - y) / 20) : 0;
        const sleeveSwing = running ? 4.5 : 2.4;
        const trail = running ? 2.8 : 1;
        const sx = x - 1 - lean + sleeveSwing * swing * arm + hem * (trail + Math.cos(frame * Math.PI / 4));
        const sy = y - (running ? runWeight : weight)[frame] * (1 - hem);
        if (sy <= 53 + (sx < 30 ? 1 : 0)) paint(frame, row, x, y, sx, sy);
      }
    }
  }
  for (let y = 18; y <= 60; y++) for (let x = 18; x < 44; x++) {
    const cuff = clamp((y - 36) / 13) * clamp((56 - y) / 5) * clamp((31 - x) / 5);
    paint(frame, 2, x, y, x + cuff * Math.sin(frame * Math.PI / 4),
      y + breath[frame] * clamp((57 - y) / 17), idleSources[frame]);
  }
}
fs.writeFileSync(path.join(assets, 'huyen-bao-travel.png'), encode(pixels, width, size * rows));
