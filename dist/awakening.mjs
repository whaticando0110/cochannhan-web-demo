import { aptitude, cellId, createCeremony, finalDepth, flowerBank, height,
  hopeCells, hopeGain, move, routeTo, terrain, width } from './awakening-rules.mjs';

const byId = id => document.getElementById(id);
const canvas = byId('garden');
const screen = canvas.getContext('2d');
const tile = 24;
const map = document.createElement('canvas');
map.width = width * tile;
map.height = height * tile;
const ink = map.getContext('2d');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const sprite = new Image();
sprite.src = 'assets/huyen-bao-travel.png';
const pace = 148;
const keys = { w: [0, -1], arrowup: [0, -1], s: [0, 1], arrowdown: [0, 1],
  a: [-1, 0], arrowleft: [-1, 0], d: [1, 0], arrowright: [1, 0] };
let state = createCeremony();
let from = state;
let steppedAt = -Infinity;
let facing = 1;
let path = [];
let heldKey;
let queuedKey;
let flash;
let cameraX = 0;
let cameraY = 0;
let frame;

function box(ctx, color, x, y, w, h) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.floor(x), Math.floor(y), w, h);
}

function flower(x, y, shape) {
  box(ink, '#21464a', x + 1, y + 2, 1, 5);
  box(ink, '#487775', x - 1, y + 4, 2, 1);
  box(ink, '#527d99', x - 1, y, 4, 2);
  box(ink, '#91bacd', x - 1, y - 1 - shape, 1, 2 + shape);
  box(ink, '#a9d4dd', x, y + 1, 2, 1);
  box(ink, '#dcf1d4', x + 1, y, 1, 1);
}

function caveRim(pick) {
  for (const top of [true, false]) {
    const edge = top ? 2 * tile : 7 * tile;
    for (let x = -4; x < map.width; x += 13 + pick(18)) {
      const blockWidth = 12 + pick(22);
      const rise = 10 + pick(22);
      const y = top ? edge - rise : edge;
      box(ink, '#101b24', x, y, blockWidth, rise);
      box(ink, '#26373e', x + 2, y + 3, blockWidth - 4, rise - 6);
      box(ink, '#3b4d4d', x + 4, top ? edge - 6 : edge + 1, blockWidth - 8, 3);
      box(ink, '#19292e', x + blockWidth - 8, y + 6, 4, rise - 7);
      if (rise > 22) box(ink, '#33484a', x + 5, y + 6, 3, 8);
    }
  }
}

function paintMap() {
  let seed = 197;
  const pick = max => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return Math.floor(seed / 2 ** 32 * max);
  };
  const palettes = {
    rock: ['#17232c', '#21333a', '#293b42', '#101a24'],
    water: ['#15394a', '#204e62', '#285a6c', '#17333f'],
    ford: ['#37535a', '#4a6b70', '#63828a', '#233c43'],
    bank: ['#33434a', '#3d5255', '#4f5f60', '#26343b'],
    garden: ['#253e42', '#2d4b49', '#355553', '#1d3337'],
  };
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const kind = terrain(x, y);
    const [base, mid, light, dark] = palettes[kind];
    const left = x * tile;
    const top = y * tile;
    box(ink, base, left, top, tile, tile);
    for (let i = 0; i < 13; i++) {
      box(ink, [mid, light, dark][pick(3)], left + pick(19), top + pick(21),
        2 + pick(4), kind === 'water' ? 1 : 1 + pick(3));
    }
    if (kind === 'rock') {
      const lip = y < 2 ? top + 15 : top + 2;
      box(ink, '#0c1821', left, lip + 4, tile, 4);
      box(ink, mid, left + 2, lip, 19, 4);
      box(ink, light, left + 4 + pick(8), lip - 1, 7, 1);
    }
    if (kind === 'ford') {
      box(ink, dark, left + 2, top + 7, 19, 12);
      box(ink, mid, left + 3, top + 4, 18, 12);
      box(ink, light, left + 4, top + 5, 11, 1);
    }
    if (kind === 'garden') {
      const flowers = y === 4 ? 3 : 6;
      for (let i = 0; i < flowers; i++) flower(left + 2 + pick(19), top + 4 + pick(14), pick(2));
    }
  }
  caveRim(pick);
  // Low lanterns flank the staging bank; a spring glints at the back of the cave.
  for (const y of [2, 6]) {
    box(ink, '#b38a62', 20, y * tile + 8, 3, 10);
    box(ink, '#f7cb84', 19, y * tile + 6, 5, 4);
    box(ink, '#4a5f61', 17, y * tile + 17, 9, 3);
  }
  const spring = (width - 1) * tile;
  for (let i = 0; i < 7; i++) {
    const w = [9, 15, 20, 22, 20, 15, 8][i];
    box(ink, '#316477', spring + 12 - w / 2, 66 + i * 10, w, 10);
    box(ink, '#599294', spring + 12 - w / 3, 69 + i * 10, w / 2, 2);
  }
}

function resize() {
  canvas.width = Math.max(1, Math.round(canvas.clientWidth / 2));
  canvas.height = Math.max(1, Math.round(canvas.clientHeight / 2));
  screen.imageSmoothingEnabled = false;
}

function showResult() {
  byId('ceremony-result').hidden = false;
  byId('result-depth').textContent = state.depth + ' bước vào biển Nguyệt Lan';
  byId('result-grade').textContent = aptitude(state.depth);
  byId('result-note').textContent = state.depth < 10
    ? 'Bạn có thể thử lại và đi qua các cụm Hy Vọng Cổ để vào sâu hơn.'
    : 'Gia lão đã ghi nhận kết quả Đại điển.';
  byId('result-grade').focus();
}

function updateHint(note) {
  byId('garden-hint').textContent = note;
  byId('ceremony-announce').textContent = note;
}

function renderStatus() {
  byId('depth').textContent = state.depth;
  byId('grade').textContent = aptitude(state.depth);
  byId('resolve').value = state.resolve;
  byId('finish').disabled = state.x < flowerBank || state.finished;
}

function step(x, y, now) {
  const next = move(state, x, y);
  if (next === state) return false;
  from = state;
  state = next;
  if (x !== from.x) facing = Math.sign(x - from.x);
  steppedAt = now;
  if (state.gathered !== from.gathered) {
    flash = { x, y, at: now };
    updateHint('Hy Vọng Cổ hội tụ · +' + hopeGain + ' sức chống áp lực');
  } else if (x === flowerBank && from.x < flowerBank) {
    updateHint('Cụm Hy Vọng Cổ màu vàng giúp bạn đi sâu hơn vào biển hoa.');
  }
  renderStatus();
  if (state.finished) showResult();
  return true;
}

function controls(now) {
  if (state.finished || now - steppedAt < pace) return;
  const key = queuedKey ?? heldKey;
  queuedKey = undefined;
  if (key) {
    const [dx, dy] = keys[key];
    step(state.x + dx, state.y + dy, now);
  } else if (path.length) {
    const [x, y] = path.shift();
    if (!step(x, y, now)) path = [];
  }
}

function drawLights(now, heroX, heroY) {
  const lights = reduced.matches ? 0 : now / 800;
  for (let i = 0; i < 17; i++) {
    const x = (3 * tile) + 4 + (i * 43 % 61) - cameraX;
    const streamY = 50 + (i * 37 + lights * 8) % 114;
    if (Math.floor(streamY / tile) === 4) continue;
    box(screen, i % 4 ? '#3b7682' : '#72a5a8', x, streamY - cameraY, 2 + i % 6, 1);
  }
  for (let i = 0; i < 128; i++) {
    const x = (flowerBank + 1) * tile + (i * 211 % (tile * 48)) - cameraX;
    const y = 56 + i * 61 % 98 - cameraY;
    if (x < -6 || x > canvas.width + 6) continue;
    const glowX = x + Math.sin(lights + i) * 5;
    const glowY = y + Math.cos(lights * .7 + i) * 8;
    box(screen, '#8fb18b', glowX - 1, glowY, 3, 1);
    box(screen, '#e0edb2', glowX, glowY, 1, 1);
  }
  for (const id of hopeCells) {
    if (state.gathered.includes(id)) continue;
    const x = (id % width + .5) * tile - cameraX;
    const y = (Math.floor(id / width) + .5) * tile - cameraY;
    for (let i = 0; i < 5; i++) {
      const a = i * 1.26 + lights;
      const px = x + Math.sin(a) * 8;
      const py = y + Math.cos(a) * 5 - 3;
      box(screen, '#a98a56', px - 1, py - 1, 4, 4);
      box(screen, '#fff0ad', px, py, 2, 2);
    }
  }
  if (flash && !reduced.matches && now - flash.at < 780) {
    const t = (now - flash.at) / 780;
    for (let i = 0; i < 8; i++) {
      const angle = i * Math.PI / 4 + t;
      box(screen, '#fff4ae', heroX + Math.cos(angle) * 25 * (1 - t),
        heroY - 12 + Math.sin(angle) * 19 * (1 - t), 2, 2);
    }
  }
}

function draw(now) {
  const progress = reduced.matches ? 1 : Math.min(1, (now - steppedAt) / pace);
  const heroMapX = (from.x + (state.x - from.x) * progress + .5) * tile;
  const heroMapY = (from.y + (state.y - from.y) * progress + .5) * tile;
  cameraX = Math.round(Math.max(0, Math.min(map.width - canvas.width, heroMapX - canvas.width * .38)));
  cameraY = Math.round((map.height - canvas.height) / 2);
  box(screen, '#101a24', 0, 0, canvas.width, canvas.height);
  screen.drawImage(map, -cameraX, -cameraY);
  const x = heroMapX - cameraX;
  const y = heroMapY - cameraY + 5;
  drawLights(now, x, y);
  box(screen, '#112627', x - 8, y - 1, 16, 3);
  if (sprite.complete && sprite.naturalWidth) {
    const walking = !reduced.matches && progress < 1;
    const cel = reduced.matches ? 0 : walking ? Math.floor(progress * 8) : Math.floor(now / 350) % 8;
    screen.save();
    screen.translate(Math.round(x), Math.round(y));
    screen.scale(facing, 1);
    screen.drawImage(sprite, cel * 64, walking ? 0 : 128, 64, 64, -18, -34, 36, 36);
    screen.restore();
  } else {
    box(screen, '#d0cbb3', x - 2, y - 15, 5, 3);
    box(screen, '#1b2535', x - 3, y - 12, 7, 12);
  }
  const shade = screen.createLinearGradient(0, 0, 0, canvas.height);
  shade.addColorStop(0, '#0c151cb3');
  shade.addColorStop(.24, '#0c151c00');
  shade.addColorStop(.79, '#0c151c00');
  shade.addColorStop(1, '#0c151cb3');
  screen.fillStyle = shade;
  screen.fillRect(0, 0, canvas.width, canvas.height);
}

function tick(now) {
  controls(now);
  draw(now);
  frame = requestAnimationFrame(tick);
}

canvas.addEventListener('keydown', event => {
  const key = event.key.toLowerCase();
  if (!Object.hasOwn(keys, key) || event.ctrlKey || event.metaKey || event.altKey) return;
  event.preventDefault();
  path = [];
  heldKey = key;
  if (!event.repeat) queuedKey = key;
  controls(performance.now());
});
window.addEventListener('keyup', event => {
  if (heldKey === event.key.toLowerCase()) heldKey = undefined;
});
canvas.addEventListener('blur', () => {
  heldKey = undefined;
  queuedKey = undefined;
});
canvas.addEventListener('click', event => {
  if (state.finished) return;
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor(((event.clientX - rect.left) * canvas.width / rect.width + cameraX) / tile);
  const y = Math.floor(((event.clientY - rect.top) * canvas.height / rect.height + cameraY) / tile);
  canvas.focus({ preventScroll: true });
  queuedKey = undefined;
  path = routeTo(state, x, y);
});
byId('finish').addEventListener('click', () => {
  state = { ...state, finished: true };
  renderStatus();
  showResult();
});
byId('retry').addEventListener('click', () => {
  state = createCeremony();
  from = state;
  steppedAt = -Infinity;
  path = [];
  heldKey = undefined;
  queuedKey = undefined;
  facing = 1;
  flash = undefined;
  byId('ceremony-result').hidden = true;
  updateHint('Qua sông ở đoạn nước nông. Dùng WASD, phím mũi tên hoặc chạm một ô.');
  renderStatus();
  canvas.focus();
});

paintMap();
resize();
new ResizeObserver(resize).observe(canvas);
renderStatus();
frame = requestAnimationFrame(tick);
window.addEventListener('pagehide', () => cancelAnimationFrame(frame));
window.addEventListener('pageshow', event => {
  if (event.persisted) frame = requestAnimationFrame(tick);
});
