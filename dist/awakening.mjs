import { aptitude, cellId, createCeremony, finalDepth, flowerBank, height,
  hopeCells, move, routeTo, terrain, width } from './awakening-rules.mjs';

const byId = id => document.getElementById(id);
const selection = byId('character-select');
const stage = byId('ceremony-stage');
const changeHero = byId('change-hero');
const storyContinue = byId('story-continue');
const canvas = byId('garden');
const screen = canvas.getContext('2d');
const tile = 24;
const map = document.createElement('canvas');
map.width = width * tile;
map.height = height * tile;
const ink = map.getContext('2d');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const sprite = new Image();
const orchids = new Image();
orchids.src = 'assets/awakening/nguyet-lan-tiles.png';
const hopeGu = new Image();
hopeGu.src = 'assets/awakening/hy-vong-gu.png';
const story = [
  'Thuở hoang sơ, loài người đầu tiên là Nhân Tổ. Bầy thú mang tên Khốn Cảnh săn đuổi ông khắp nơi.',
  'Nhân Tổ đổi tuổi trẻ lấy Sức Mạnh, rồi đổi tuổi trung niên lấy Trí Tuệ. Khi ông già đi, hai con Cổ ấy đều bỏ ông mà đi.',
  'Khi Khốn Cảnh vây kín, con Cổ cuối cùng chỉ xin ông trao trái tim. Nhân Tổ bằng lòng. Ánh sáng của Hy Vọng Cổ bừng lên, khiến bầy thú tháo chạy.',
];
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
let storyIndex = 0;
let storyPaused = false;

function box(ctx, color, x, y, w, h) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.floor(x), Math.floor(y), w, h);
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
  ink.imageSmoothingEnabled = false;
  const plants = [];
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
      plants.push({ x: left + 3 + pick(9), y: top + 6 + pick(7), variant: pick(4), size: 18 + pick(7) });
      if (y !== 4 && pick(4) > 0) {
        plants.push({ x: left + 15 + pick(6), y: top + 16 + pick(7), variant: pick(4), size: 14 + pick(6) });
      }
    }
  }
  if (orchids.complete && orchids.naturalWidth === 128) {
    plants.sort((a, b) => a.y - b.y);
    for (const { x, y, variant, size } of plants) {
      ink.drawImage(orchids, variant * 32, 0, 32, 32, x - Math.floor(size / 2), y - size + 1, size, size);
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
  byId('finish').disabled = state.x < flowerBank || state.finished || storyPaused;
}

function showStory(index, pause = false) {
  storyIndex = index;
  storyPaused = pause;
  byId('story-line').textContent = story[index];
  storyContinue.hidden = !pause;
  if (pause) storyContinue.focus({ preventScroll: true });
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
    const restored = state.resolve - (from.resolve - 1);
    updateHint('Hy Vọng Cổ hội tụ · +' + restored + ' sức chống áp lực');
  } else if (x === flowerBank && from.x < flowerBank) {
    updateHint('Đi qua cụm Hy Vọng Cổ màu vàng để hồi sức và tiến sâu hơn.');
  }
  const chapter = x >= flowerBank + 2 ? 2 : x >= 4 ? 1 : 0;
  if (chapter > storyIndex && !state.finished) showStory(chapter, true);
  renderStatus();
  if (state.finished) showResult();
  return true;
}

function controls(now) {
  if (storyPaused || state.finished || now - steppedAt < pace) return;
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

function drawGu(x, y, now, seed, size) {
  if (!hopeGu.complete || hopeGu.naturalWidth !== 64) return;
  const cel = reduced.matches ? 0 : (Math.floor(now / 85) + seed) % 4;
  screen.drawImage(hopeGu, cel * 16, 0, 16, 16,
    Math.round(x - size / 2), Math.round(y - size / 2), size, size);
}

function drawLights(now, heroX, heroY) {
  const lights = reduced.matches ? 0 : now / 800;
  for (let i = 0; i < 17; i++) {
    const x = (3 * tile) + 4 + (i * 43 % 61) - cameraX;
    const streamY = 50 + (i * 37 + lights * 8) % 114;
    if (Math.floor(streamY / tile) === 4) continue;
    box(screen, i % 4 ? '#3b7682' : '#72a5a8', x, streamY - cameraY, 2 + i % 6, 1);
  }
  for (let i = 0; i < 87; i++) {
    const x = (flowerBank + 1) * tile + (i * 211 % (tile * 48)) - cameraX;
    const y = 56 + i * 61 % 98 - cameraY;
    if (x < -6 || x > canvas.width + 6) continue;
    const glowX = x + Math.sin(lights + i) * 5;
    const glowY = y + Math.cos(lights * .7 + i) * 8;
    drawGu(glowX, glowY, now, i, 7);
  }
  for (const id of hopeCells) {
    if (state.gathered.includes(id)) continue;
    const x = (id % width + .5) * tile - cameraX;
    const y = (Math.floor(id / width) + .5) * tile - cameraY;
    for (let i = 0; i < 5; i++) {
      const a = i * 1.26 + lights;
      const px = x + Math.sin(a) * 8;
      const py = y + Math.cos(a) * 5 - 3;
      drawGu(px, py, now, i, 13);
    }
  }
  if (flash && !reduced.matches && now - flash.at < 780) {
    const t = (now - flash.at) / 780;
    for (let i = 0; i < 8; i++) {
      const angle = i * Math.PI / 4 + t;
      drawGu(heroX + Math.cos(angle) * 25 * (1 - t),
        heroY - 12 + Math.sin(angle) * 19 * (1 - t), now, i, 9);
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
  if (stage.hidden) return;
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
  if (state.finished || storyPaused) return;
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor(((event.clientX - rect.left) * canvas.width / rect.width + cameraX) / tile);
  const y = Math.floor(((event.clientY - rect.top) * canvas.height / rect.height + cameraY) / tile);
  canvas.focus({ preventScroll: true });
  queuedKey = undefined;
  path = routeTo(state, x, y);
});
storyContinue.addEventListener('click', () => {
  storyPaused = false;
  storyContinue.hidden = true;
  renderStatus();
  canvas.focus({ preventScroll: true });
});
byId('finish').addEventListener('click', () => {
  state = { ...state, finished: true };
  renderStatus();
  showResult();
});
function resetCeremony() {
  state = createCeremony();
  from = state;
  steppedAt = -Infinity;
  path = [];
  heldKey = undefined;
  queuedKey = undefined;
  facing = 1;
  flash = undefined;
  byId('ceremony-result').hidden = true;
  showStory(0);
  updateHint('Qua sông ở đoạn nước nông. Dùng WASD, phím mũi tên hoặc chạm một ô.');
  renderStatus();
  canvas.focus({ preventScroll: true });
}

byId('retry').addEventListener('click', resetCeremony);
selection.addEventListener('submit', event => {
  event.preventDefault();
  const selected = new FormData(selection).get('hero');
  const hero = selected === 'ao-reu' ? 'ao-reu' : 'huyen-bao';
  sprite.src = 'assets/' + hero + '-travel.png';
  byId('enter-village').href = 'village.html?hero=' + hero;
  selection.hidden = true;
  stage.hidden = false;
  changeHero.hidden = false;
  resetCeremony();
  resize();
  cancelAnimationFrame(frame);
  frame = requestAnimationFrame(tick);
});
changeHero.addEventListener('click', () => {
  cancelAnimationFrame(frame);
  stage.hidden = true;
  changeHero.hidden = true;
  selection.hidden = false;
  selection.querySelector('input:checked').focus();
});

orchids.addEventListener('load', paintMap);
paintMap();
new ResizeObserver(resize).observe(canvas);
window.addEventListener('pagehide', () => cancelAnimationFrame(frame));
window.addEventListener('pageshow', event => {
  if (event.persisted && !stage.hidden) frame = requestAnimationFrame(tick);
});
