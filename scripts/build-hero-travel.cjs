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
const runAnkle = [40, 36, 29, 22, 23, 26, 32, 37];
const runLift = [0, 0, 0, 2, 5, 8, 7, 3];
const runKnee = [1, 3, 2, 0, 2, 6, 8, 4];
const idleSources = [0, 1, 2, 3, 4, 5, 1, 0];
const breath = [0, 0, 1, 1, 1, 0, 0, 0];
const clamp = n => Math.min(1, Math.max(0, n));

function paint(column, row, x, y, sx, sy, sourceFrame = 0) {
  sx = Math.round(sx);
  sy = Math.round(sy);
  if (sx < 0 || sx >= size || sy < 0 || sy >= size) return;
  const sourceX = (sourceFrame % 8) * size + sx;
  const sourceY = Math.floor(sourceFrame / 8) * size + sy;
  const read = 4 * (sourceY * source.width + sourceX);
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

function paintRun(frame) {
  const runRow = 3;
  leg(frame, runRow, false);
  leg(frame, runRow, true);
  // The approved lunge poses supply a lowered shoulder and bent forearm.
  // Keep the face intact and flex the trailing robe independently of the feet.
  const pose = [20, 20, 21, 25, 20, 20, 21, 25][frame];
  const hemSwing = [0, 1, 2, 1, 0, -1, -2, -1][frame];
  for (let y = 23; y <= 54; y++) {
    for (let x = 9; x <= 49; x++) {
      const looseCloth = clamp((y - 40) / 12) * clamp((32 - x) / 14);
      const sx = x + 4 + looseCloth * hemSwing;
      const sy = y + looseCloth * Math.abs(hemSwing);
      if (sy <= 52) paint(frame, runRow, x, y, sx, sy, pose);
    }
  }
}

for (let frame = 0; frame < 8; frame++) {
  for (const row of [0, 1]) {
    leg(frame, row, false);
    leg(frame, row, true);
    for (let y = 17; y < 57; y++) {
      for (let x = 16; x < 46; x++) {
        const arm = clamp((y - 34) / 14) * clamp((32 - x) / 5);
        const hem = clamp((y - 41) / 14);
        const swing = Math.sin(frame * Math.PI / 4);
        const sx = x - 1 + 2.4 * swing * arm + hem * (1 + Math.cos(frame * Math.PI / 4));
        const sy = y - weight[frame] * (1 - hem);
        if (sy <= 53 + (sx < 30 ? 1 : 0)) paint(frame, row, x, y, sx, sy);
      }
    }
  }
  for (let y = 18; y <= 60; y++) for (let x = 18; x < 44; x++) {
    const cuff = clamp((y - 36) / 13) * clamp((56 - y) / 5) * clamp((31 - x) / 5);
    paint(frame, 2, x, y, x + cuff * Math.sin(frame * Math.PI / 4),
      y + breath[frame] * clamp((57 - y) / 17), idleSources[frame]);
  }
  paintRun(frame);
}
fs.writeFileSync(path.join(assets, 'huyen-bao-travel.png'), encode(pixels, width, size * rows));
