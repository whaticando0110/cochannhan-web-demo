import { aptitude, cellId, createCeremony, finalDepth, flowerBank, height,
  hopeCells, move, routeTo, terrain, width } from './awakening-rules.mjs';

const byId = id => document.getElementById(id);
const selection = byId('character-select');
const stage = byId('ceremony-stage');
const changeHero = byId('change-hero');
const storyContinue = byId('story-continue');
const canvas = byId('garden');
const screen = canvas.getContext('2d');
const tile = 32;
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
const caveTiles = new Image();
caveTiles.src = 'assets/awakening/cave-tiles.png';
const caveSpring = new Image();
caveSpring.src = 'assets/awakening/cave-spring.png';

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
let sceneProps = [];
let ambientFireflies = [];

const loaded = img => img.complete && img.naturalWidth > 0;

function drawTile(ctx, sheet, cx, cy, dx, dy) {
  ctx.drawImage(sheet, cx * tile, cy * tile, tile, tile, Math.floor(dx), Math.floor(dy), tile, tile);
}

function buildSeededPick(seedInit = 197) {
  let seed = seedInit >>> 0;
  return max => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return Math.floor((seed / 2 ** 32) * max);
  };
}

function paintMap() {
  ink.imageSmoothingEnabled = false;
  ink.fillStyle = '#0d1217';
  ink.fillRect(0, 0, map.width, map.height);

  const pick = buildSeededPick(197);
  const props = [];
  const fireflies = [];
  const hasCave = loaded(caveTiles) && caveTiles.naturalWidth >= 256;
  const hopeSet = new Set(hopeCells);

  // Layer 1: Base subterranean cavern floors, rocks & river
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const kind = terrain(x, y);
      const left = x * tile;
      const top = y * tile;
      const v = pick(12);

      if (!hasCave) {
        ink.fillStyle = kind === 'water' ? '#122531' : kind === 'ford' ? '#36454d' : kind === 'bank' ? '#2b3840' : kind === 'garden' ? '#1b2829' : '#151d23';
        ink.fillRect(left, top, tile, tile);
        continue;
      }

      if (kind === 'rock') {
        drawTile(ink, caveTiles, v % 3, 0, left, top);
      } else if (kind === 'bank') {
        drawTile(ink, caveTiles, v % 3, 1, left, top);
        if ((y === 2 || y === 6) && x === 1 && pick(2) === 0) {
          drawTile(ink, caveTiles, 1, 3, left + 10, top + (y === 2 ? -2 : 8));
        }
      } else if (kind === 'ford') {
        drawTile(ink, caveTiles, 5 + Math.min(2, x - 3), 1, left, top);
      } else if (kind === 'water') {
        drawTile(ink, caveTiles, 3 + (v % 2), 1, left, top);
      } else {
        // Moon Orchid meadow floor (cols 6..55, rows 2..6)
        const baseVar = y === 4 ? (4 + (v % 2)) : (v % 4);
        drawTile(ink, caveTiles, baseVar, 2, left, top);
        if (y === 4 && x > flowerBank && x < 54 && pick(3) > 0) {
          drawTile(ink, caveTiles, 3 + (pick(2)), 3, left, top);
        }
        if (hopeSet.has(cellId(x, y))) {
          drawTile(ink, caveTiles, 2, 3, left, top);
        }
      }
    }
  }

  // Layer 2: Organic river shoreline overhangs & Spirit Spring pool (drawn under ceiling overhangs)
  if (hasCave) {
    for (let y = 2; y <= 6; y++) {
      drawTile(ink, caveTiles, 6, 2, 3 * tile, y * tile);
      drawTile(ink, caveTiles, 7, 2, 5 * tile, y * tile);
    }
  }

  if (loaded(caveSpring)) {
    // Frame east cavern rock wall organically behind the Spirit Spring pool
    if (hasCave) {
      for (let y = 2; y <= 6; y++) {
        drawTile(ink, caveTiles, 1, 3, 55 * tile - 8, y * tile + (y % 2 === 0 ? -4 : 6));
      }
    }
    ink.drawImage(caveSpring, 55 * tile - 6, 2 * tile);
  }

  // Layer 3: Stratified limestone ceiling stalactites overhanging row 1->2 & lower cavern cliff rim row 7
  if (hasCave) {
    for (let x = 0; x < width; x++) {
      const cv = pick(3);
      drawTile(ink, caveTiles, 3 + cv, 0, x * tile, tile + 8);
      drawTile(ink, caveTiles, 6 + (cv % 2), 0, x * tile, 7 * tile - 4);
    }
  }

  // Layer 4: Subtle warm stone-lantern amber bounce pools on Elders' bank
  for (const ly of [2, 6]) {
    const gx = 18;
    const gy = ly * tile + 14;
    const glow = ink.createRadialGradient(gx, gy, 2, gx, gy, 30);
    glow.addColorStop(0, 'rgba(232, 180, 96, 0.24)');
    glow.addColorStop(0.55, 'rgba(184, 130, 62, 0.08)');
    glow.addColorStop(1, 'rgba(184, 130, 62, 0)');
    ink.fillStyle = glow;
    ink.fillRect(gx - 30, gy - 30, 60, 60);
    props.push({ kind: 'lantern', x: 2, y: ly * tile + 30 });
  }

  // Populate 1:1 Nguyet Lan orchid beds (natural carpet density with subtle central trail & clearings)
  for (let y = 2; y <= 6; y++) {
    for (let x = flowerBank; x < width - 2; x++) {
      const isHope = hopeSet.has(cellId(x, y));
      const left = x * tile;
      const top = y * tile;
      const denseRoll = pick(10);

      if (isHope) {
        // Frame each Hope Gu gathering patch on back/side rims cleanly without hiding the halo
        props.push({ kind: 'orchid', variant: pick(4), x: left + 6 + pick(4), y: top + 12 + pick(4) });
        props.push({ kind: 'orchid', variant: pick(4), x: left + 25 + pick(4), y: top + 28 + pick(3) });
      } else if (y === 4) {
        // Center trail stays walkable/readable; scatter wild lower/upper clusters unevenly without row lining
        if (denseRoll < 5 && x < width - 3) {
          const topSide = pick(2) === 0;
          props.push({
            kind: 'orchid',
            variant: pick(4),
            x: left + 4 + pick(24),
            y: top + (topSide ? 6 + pick(7) : 25 + pick(7)),
          });
        }
      } else if (x < width - 2) {
        // Rich Moon Orchid carpet across north & south flanks ("như tấm thảm lớn màu xanh")
        props.push({
          kind: 'orchid',
          variant: pick(4),
          x: left + 6 + pick(10),
          y: top + 13 + pick(8),
        });
        if (denseRoll < 8) {
          props.push({
            kind: 'orchid',
            variant: pick(4),
            x: left + 18 + pick(10),
            y: top + 22 + pick(9),
          });
        }
        if (x > flowerBank + 2 && fireflies.length < 30 && pick(14) === 0) {
          fireflies.push({
            x: left + 8 + pick(16),
            y: top + 6 + pick(14),
            seed: pick(100),
            speed: 0.7 + pick(7) * 0.1,
          });
        }
      }
    }
  }

  props.sort((a, b) => a.y - b.y);
  sceneProps = props;
  ambientFireflies = fireflies;
}

function resize() {
  const clientW = Math.max(1, canvas.clientWidth);
  const clientH = Math.max(1, canvas.clientHeight);
  const aspect = clientW / clientH;
  const minLandscapeCols = clientW < 540 ? 12 : 14;
  let bufH = map.height;
  let bufW = Math.round(bufH * aspect);

  if (bufW < minLandscapeCols * tile) {
    bufW = minLandscapeCols * tile;
    bufH = Math.max(map.height, Math.round(bufW / aspect));
  }
  canvas.width = Math.min(map.width, bufW);
  canvas.height = bufH;
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
    updateHint('Đi qua cụm Hy Vọng Cổ để hồi sức và tiến sâu hơn.');
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

function drawGu(x, y, now, seed) {
  if (!loaded(hopeGu) || hopeGu.naturalWidth < 64) return;
  const cel = reduced.matches ? 0 : (Math.floor(now / 135) + seed) % 4;
  screen.drawImage(hopeGu, cel * 16, 0, 16, 16, Math.round(x - 8), Math.round(y - 8), 16, 16);
}

function drawProp(prop) {
  if (prop.kind === 'lantern') {
    if (!loaded(caveTiles)) return;
    screen.drawImage(caveTiles, 0, 96, tile, tile,
      Math.round(prop.x - cameraX), Math.round(prop.y - 26 - cameraY), tile, tile);
    return;
  }
  if (!loaded(orchids) || orchids.naturalWidth < 128) return;
  // Exact 1:1 native 32x32 Nguyet Lan bottom-center anchored at (16, 31)
  screen.drawImage(orchids, prop.variant * 32, 0, 32, 32,
    Math.round(prop.x - 16 - cameraX), Math.round(prop.y - 31 - cameraY), 32, 32);
}

function drawBackdropRock() {
  screen.fillStyle = '#0d1217';
  screen.fillRect(0, 0, canvas.width, canvas.height);
  if (!loaded(caveTiles)) return;
  // If tall viewport leaves padding above/below 288px cavern, extend dark stratified limestone wall cleanly
  const minY = Math.max(0, -cameraY);
  const maxY = Math.min(canvas.height, map.height - cameraY);
  if (minY > 0 || maxY < canvas.height) {
    const startCol = Math.floor(cameraX / tile);
    const endCol = Math.ceil((cameraX + canvas.width) / tile);
    for (let cx = startCol; cx <= endCol; cx++) {
      const dx = Math.round(cx * tile - cameraX);
      const sx = ((cx % 3) + 3) % 3 * tile;
      for (let py = minY - tile; py >= -tile; py -= tile) {
        screen.drawImage(caveTiles, sx, 0, tile, tile, dx, py, tile, tile);
      }
      for (let py = maxY; py < canvas.height; py += tile) {
        screen.drawImage(caveTiles, sx, 0, tile, tile, dx, py, tile, tile);
      }
    }
  }
}

function drawAmbientWaterAndSpring(now) {
  const t = reduced.matches ? 0 : now / 900;
  // Soft subterranean river horizontal shimmer across cols 3..5 (y=2..6, skip stone ford at y=4)
  for (let i = 0; i < 18; i++) {
    const streamX = 3 * tile + 8 + ((i * 31) % (tile * 3 - 18));
    const streamY = 2 * tile + 10 + ((i * 29 + Math.floor(t * 7)) % (tile * 5 - 20));
    if (Math.floor(streamY / tile) === 4) continue;
    const dx = Math.round(streamX - cameraX);
    const dy = Math.round(streamY - cameraY);
    if (dx < -8 || dx > canvas.width + 8) continue;
    screen.fillStyle = i % 3 === 0 ? 'rgba(130, 174, 182, 0.35)' : 'rgba(62, 106, 120, 0.45)';
    screen.fillRect(dx, dy, 3 + (i % 5), 1);
  }
  // Subtle Linh Tuyen mineral pool shimmer at cols 55..56
  const springX = 55 * tile + 42 - cameraX;
  if (springX > -40 && springX < canvas.width + 40) {
    for (let i = 0; i < 7; i++) {
      const px = springX + Math.sin(t + i * 1.4) * 10;
      const py = 4.5 * tile + Math.cos(t * 0.8 + i * 1.1) * 32 - cameraY;
      screen.fillStyle = 'rgba(182, 232, 224, 0.45)';
      screen.fillRect(Math.round(px), Math.round(py), i % 2 === 0 ? 2 : 1, 1);
    }
  }
}

function drawHero(x, heroFootY, progress, now) {
  screen.fillStyle = 'rgba(8, 13, 16, 0.52)';
  screen.fillRect(Math.round(x - 8), Math.round(heroFootY - 1), 16, 3);
  if (loaded(sprite)) {
    const walking = !reduced.matches && progress < 1;
    const cel = reduced.matches ? 0 : walking ? Math.floor(progress * 8) : Math.floor(now / 350) % 8;
    screen.save();
    screen.translate(Math.round(x), Math.round(heroFootY));
    screen.scale(facing, 1);
    // Exact 1:1 native 64x64 sprite frame, boots grounded at y=60
    screen.drawImage(sprite, cel * 64, walking ? 0 : 128, 64, 64, -32, -60, 64, 64);
    screen.restore();
  } else {
    screen.fillStyle = '#d0cbb3';
    screen.fillRect(Math.round(x - 3), Math.round(heroFootY - 26), 6, 5);
    screen.fillStyle = '#1b2535';
    screen.fillRect(Math.round(x - 5), Math.round(heroFootY - 21), 10, 20);
  }
}

function drawHopeSwarms(now, heroX, heroFootY) {
  const t = reduced.matches ? 0 : now / 850;

  // 1. Subtle sparse background Hy Vong Gu rising organically across the Moon Orchid sea (1:1 16x16)
  for (const f of ambientFireflies) {
    const sx = f.x + Math.sin(t * f.speed + f.seed) * 6 - cameraX;
    if (sx < -16 || sx > canvas.width + 16) continue;
    const sy = f.y - 6 + Math.cos(t * f.speed * 0.8 + f.seed) * 5 - cameraY;
    drawGu(sx, sy, now, f.seed);
  }

  // 2. Active collectible Hy Vong Gu milestone clusters (clear radial mist halo + orbiting 1:1 swarm)
  for (const id of hopeCells) {
    if (state.gathered.includes(id)) continue;
    const cx = (id % width + 0.5) * tile - cameraX;
    const cy = (Math.floor(id / width) + 0.5) * tile - cameraY;
    if (cx < -32 || cx > canvas.width + 32) continue;

    const pulse = 0.22 + (reduced.matches ? 0 : Math.sin(t * 2 + id) * 0.06);
    const halo = screen.createRadialGradient(cx, cy + 2, 2, cx, cy + 2, 22);
    halo.addColorStop(0, `rgba(229, 210, 149, ${pulse})`);
    halo.addColorStop(0.55, `rgba(176, 208, 188, ${pulse * 0.45})`);
    halo.addColorStop(1, 'rgba(176, 208, 188, 0)');
    screen.fillStyle = halo;
    screen.fillRect(Math.round(cx - 22), Math.round(cy - 20), 44, 44);

    for (let i = 0; i < 3; i++) {
      const ang = i * ((Math.PI * 2) / 3) + t * 1.35;
      const px = cx + Math.cos(ang) * 9;
      const py = cy - 6 + Math.sin(ang * 1.3) * 5;
      drawGu(px, py, now, i + id);
    }
  }

  // 3. Convergence into character Khong Khieu (chest center ~heroFootY - 22) when Hope Gu gathers
  if (flash && !reduced.matches && now - flash.at < 780) {
    const k = (now - flash.at) / 780;
    const ringAlpha = Math.max(0, 0.7 * (1 - k));
    screen.strokeStyle = `rgba(244, 234, 193, ${ringAlpha})`;
    screen.lineWidth = 1;
    screen.beginPath();
    screen.arc(Math.round(heroX), Math.round(heroFootY - 22), Math.round(3 + k * 11), 0, Math.PI * 2);
    screen.stroke();
    for (let i = 0; i < 6; i++) {
      const ang = i * (Math.PI / 3) + k * 2.2;
      drawGu(
        heroX + Math.cos(ang) * 26 * (1 - k),
        heroFootY - 22 + Math.sin(ang) * 18 * (1 - k),
        now,
        i,
      );
    }
  }
}

function draw(now) {
  const progress = reduced.matches ? 1 : Math.min(1, (now - steppedAt) / pace);
  const heroMapX = (from.x + (state.x - from.x) * progress + 0.5) * tile;
  const heroMapY = (from.y + (state.y - from.y) * progress + 0.5) * tile + 6;
  cameraX = Math.round(Math.max(0, Math.min(map.width - canvas.width, heroMapX - canvas.width * 0.34)));
  cameraY = Math.round((map.height - canvas.height) / 2);

  drawBackdropRock();
  screen.drawImage(map, -cameraX, -cameraY);
  drawAmbientWaterAndSpring(now);

  const heroX = heroMapX - cameraX;
  const heroY = heroMapY - cameraY;

  // Y-sort Moon Orchids & Stone Lanterns around Hero boots cleanly for real 2.5D depth
  const minX = cameraX - 32;
  const maxX = cameraX + canvas.width + 32;
  let heroDrawn = false;
  for (const prop of sceneProps) {
    if (!heroDrawn && prop.y > heroMapY) {
      drawHero(heroX, heroY, progress, now);
      heroDrawn = true;
    }
    if (prop.x < minX || prop.x > maxX) continue;
    drawProp(prop);
  }
  if (!heroDrawn) drawHero(heroX, heroY, progress, now);

  drawHopeSwarms(now, heroX, heroY);

  // Subtle top/bottom atmospheric cavern vignette
  const shade = screen.createLinearGradient(0, 0, 0, canvas.height);
  shade.addColorStop(0, 'rgba(10, 15, 20, 0.55)');
  shade.addColorStop(0.18, 'rgba(10, 15, 20, 0)');
  shade.addColorStop(0.84, 'rgba(10, 15, 20, 0)');
  shade.addColorStop(1, 'rgba(10, 15, 20, 0.55)');
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

for (const img of [orchids, caveTiles, caveSpring]) {
  img.addEventListener('load', paintMap);
}
paintMap();
new ResizeObserver(resize).observe(canvas);
window.addEventListener('pagehide', () => cancelAnimationFrame(frame));
window.addEventListener('pageshow', event => {
  if (event.persisted && !stage.hidden) frame = requestAnimationFrame(tick);
});
