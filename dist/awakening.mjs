import { aptitude, cellId, createCeremony, finalDepth, flowerBank, height,
  hopeCells, move, routeTo, terrain, width } from './awakening-rules.mjs';

const byId = id => document.getElementById(id);
const selection = byId('character-select');
const stage = byId('ceremony-stage');
const changeHero = byId('change-hero');
const narrationBar = byId('narration-bar');
const finishBtn = byId('finish');
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

// 5 beats from Nhân Tổ Truyện (Ch. 5) scrolling seamlessly underneath without interrupting movement
const storyBeats = [
  'Thuở hoang sơ, loài người đầu tiên là Nhân Tổ. Bầy thú mang tên Khốn Cảnh săn đuổi ông khắp mọi nẻo.',
  'Nhân Tổ đổi tuổi trẻ lấy Sức Mạnh Cổ, rồi đổi tuổi trung niên lấy Trí Tuệ Cổ — khi ông già yếu, cả hai đều bỏ ông mà đi.',
  'Giữa vòng vây Khốn Cảnh, con Cổ nhỏ bé thứ ba tìm đến, chỉ xin Nhân Tổ trao cho nó một trái tim.',
  'Nhân Tổ bằng lòng giao trái tim. Hy Vọng Cổ bừng lên ánh sáng dịu dàng mà rực rỡ, đẩy lùi bầy thú Khốn Cảnh.',
  'Từ đó, dẫu rơi vào tuyệt cảnh nào, chỉ cần trong lòng còn giữ một tia hy vọng, bước chân con người vẫn hướng về phía trước.',
];

const pace = 148;
const keys = { w: [0, -1], arrowup: [0, -1], s: [0, 1], arrowdown: [0, 1],
  a: [-1, 0], arrowleft: [-1, 0], d: [1, 0], arrowright: [1, 0] };

let selectedHero = 'huyen-bao';
let state = createCeremony();
let from = state;
let steppedAt = -Infinity;
let facing = 1;
let path = [];
let heldKey;
let queuedKey;
let flash;
let tierFlashAt = -Infinity;
let cameraX = 0;
let cameraY = 0;
let frame;
let storyIndex = 0;
let narrationPulseTimer;
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
        const baseVar = y === 4 ? (4 + (v % 2)) : (v % 4);
        drawTile(ink, caveTiles, baseVar, 2, left, top);
        if (y === 4 && x > flowerBank && x < 54 && pick(3) > 0) {
          drawTile(ink, caveTiles, 3 + pick(2), 3, left, top);
        }
        if (hopeSet.has(cellId(x, y))) {
          drawTile(ink, caveTiles, 2, 3, left, top);
        }
      }
    }
  }

  if (hasCave) {
    for (let y = 2; y <= 6; y++) {
      drawTile(ink, caveTiles, 6, 2, 3 * tile, y * tile);
      drawTile(ink, caveTiles, 7, 2, 5 * tile, y * tile);
    }
  }

  if (loaded(caveSpring)) {
    if (hasCave) {
      for (let y = 2; y <= 6; y++) {
        drawTile(ink, caveTiles, 1, 3, 55 * tile - 8, y * tile + (y % 2 === 0 ? -4 : 6));
      }
    }
    ink.drawImage(caveSpring, 55 * tile - 6, 2 * tile);
  }

  if (hasCave) {
    for (let x = 0; x < width; x++) {
      const cv = pick(3);
      drawTile(ink, caveTiles, 3 + cv, 0, x * tile, tile + 8);
      drawTile(ink, caveTiles, 6 + (cv % 2), 0, x * tile, 7 * tile - 4);
    }
  }

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

  for (let y = 2; y <= 6; y++) {
    for (let x = flowerBank; x < width - 2; x++) {
      const isHope = hopeSet.has(cellId(x, y));
      const left = x * tile;
      const top = y * tile;
      const denseRoll = pick(10);

      if (isHope) {
        props.push({ kind: 'orchid', variant: pick(4), x: left + 6 + pick(4), y: top + 12 + pick(4) });
        props.push({ kind: 'orchid', variant: pick(4), x: left + 25 + pick(4), y: top + 28 + pick(3) });
      } else if (y === 4) {
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

function saveOutcome(grade) {
  try {
    sessionStorage.setItem('cochannhan.awakening', JSON.stringify({
      hero: selectedHero,
      depth: state.depth,
      grade,
      hopeGathered: state.gathered.length,
    }));
  } catch {
    // Session persistence is best-effort for offline static environments.
  }
  byId('enter-village').href = `village.html?hero=${selectedHero}&depth=${state.depth}`;
}

function showResult() {
  const grade = aptitude(state.depth);
  saveOutcome(grade);
  byId('ceremony-result').hidden = false;
  byId('result-depth').textContent = `${state.depth} / ${finalDepth} bước vào biển Nguyệt Lan`;
  byId('result-grade').textContent = grade;
  byId('result-hope').textContent = `Hy Vọng Cổ đã tụ: ${state.gathered.length} / ${hopeCells.length} cụm`;

  let note = 'Gia lão đã ghi nhận kết quả Đại điển.';
  if (state.depth < 10) {
    note = 'Chưa khai thông Không Khiếu. Hãy thử lại và đi qua các cụm Hy Vọng Cổ để tiến sâu hơn.';
  } else if (state.resolve <= 0) {
    note = `Áp lực Linh Tuyền đã tới cực hạn ở bước ${state.depth}. Tụ thêm Hy Vọng Cổ trong biển hoa để đi sâu hơn.`;
  } else if (state.depth >= 43) {
    note = 'Vượt mốc 43 bước khai khiếu Giáp đẳng, chạm sát Linh Tuyền cổ tộc!';
  } else if (state.depth > 27) {
    note = `Đạt ${grade} (${state.depth} bước), vượt qua cột mốc 27 bước Bính đẳng của Phương Nguyên trong truyện.`;
  } else if (state.depth === 27) {
    note = 'Đúng 27 bước Bính đẳng — ngang dấu chân Cổ Nguyệt Phương Nguyên thuở khai khiếu.';
  }

  byId('result-note').textContent = note;
  byId('result-grade').focus();
}

function updateHint(note) {
  byId('garden-hint').textContent = note;
  byId('ceremony-announce').textContent = note;
}

function renderStatus() {
  const grade = aptitude(state.depth);
  byId('depth').textContent = state.depth;
  byId('grade').textContent = grade;

  // Highlight Đinh / Bính / Ất / Giáp tiers sequentially
  const currentThreshold = state.depth >= 40 ? 40 : state.depth >= 30 ? 30 : state.depth >= 20 ? 20 : state.depth >= 10 ? 10 : 0;
  for (const el of byId('tier-track').children) {
    const t = Number(el.dataset.tier);
    el.classList.toggle('reached', state.depth >= t);
    el.classList.toggle('current', t === currentThreshold);
  }

  // Light up 7 Hope Gu aperture pips
  const count = state.gathered.length;
  byId('hope-count').textContent = count;
  const pips = byId('hope-pips');
  pips.setAttribute('aria-label', `${count} trên ${hopeCells.length} cụm Hy Vọng Cổ`);
  Array.from(pips.children).forEach((pip, idx) => pip.classList.toggle('lit', idx < count));

  finishBtn.disabled = state.x < flowerBank || state.finished;
  finishBtn.textContent = state.depth < 10 ? 'Dừng sớm' : `Chốt ${grade}`;
}

function showStory(index, flashSub = false) {
  storyIndex = index;
  byId('story-line').textContent = storyBeats[index];
  if (flashSub && !reduced.matches) {
    narrationBar.classList.remove('pulse');
    void narrationBar.offsetWidth;
    narrationBar.classList.add('pulse');
    clearTimeout(narrationPulseTimer);
    narrationPulseTimer = setTimeout(() => narrationBar.classList.remove('pulse'), 520);
  }
}

function beatForProgress(next) {
  if (next.depth >= 34) return 4;
  if (next.depth >= 18) return 3;
  if (next.x >= flowerBank + 1) return 2;
  if (next.x >= 4) return 1;
  return 0;
}

function step(x, y, now) {
  const prevGrade = aptitude(state.depth);
  const next = move(state, x, y);
  if (next === state) return false;
  from = state;
  state = next;
  if (x !== from.x) facing = Math.sign(x - from.x);
  steppedAt = now;

  const newGrade = aptitude(state.depth);
  if (state.gathered !== from.gathered) {
    flash = { x, y, at: now };
    updateHint(`Hy Vọng Cổ hội tụ (${state.gathered.length}/${hopeCells.length}) · Bước chân nhẹ hẳn`);
  } else if (newGrade !== prevGrade) {
    tierFlashAt = now;
    updateHint(`Không Khiếu rung động · Đạt ngưỡng ${newGrade}`);
  } else if (x === flowerBank && from.x < flowerBank) {
    updateHint('Đi theo các cụm Hy Vọng Cổ để tiến sâu về phía Linh Tuyền.');
  }

  const nextBeat = beatForProgress(state);
  if (nextBeat > storyIndex && !state.finished) {
    showStory(nextBeat, true);
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
  screen.drawImage(orchids, prop.variant * 32, 0, 32, 32,
    Math.round(prop.x - 16 - cameraX), Math.round(prop.y - 31 - cameraY), 32, 32);
}

function drawBackdropRock() {
  screen.fillStyle = '#0d1217';
  screen.fillRect(0, 0, canvas.width, canvas.height);
  if (!loaded(caveTiles)) return;
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
  // Subtle Khong Khieu (Aperture Light) at chest/dantian scaling naturally with awakening depth & hope
  const tier = state.depth >= 40 ? 4 : state.depth >= 30 ? 3 : state.depth >= 20 ? 2 : state.depth >= 10 ? 1 : 0;
  const apertureStrength = Math.min(1, state.gathered.length * 0.1 + tier * 0.14);
  if (apertureStrength > 0.08) {
    const cx = Math.round(x);
    const cy = Math.round(heroFootY - 22);
    const r = 10 + tier * 2;
    const pulse = reduced.matches ? 1 : (0.9 + Math.sin(now / 360) * 0.12);
    const glow = screen.createRadialGradient(cx, cy, 1, cx, cy, r);
    glow.addColorStop(0, `rgba(252, 247, 223, ${0.34 * apertureStrength * pulse})`);
    glow.addColorStop(0.55, `rgba(176, 220, 212, ${0.18 * apertureStrength})`);
    glow.addColorStop(1, 'rgba(176, 220, 212, 0)');
    screen.fillStyle = glow;
    screen.fillRect(cx - r, cy - r, r * 2, r * 2);
  }

  screen.fillStyle = 'rgba(8, 13, 16, 0.52)';
  screen.fillRect(Math.round(x - 8), Math.round(heroFootY - 1), 16, 3);
  if (loaded(sprite)) {
    const walking = !reduced.matches && progress < 1;
    const cel = reduced.matches ? 0 : walking ? Math.floor(progress * 8) : Math.floor(now / 350) % 8;
    screen.save();
    screen.translate(Math.round(x), Math.round(heroFootY));
    screen.scale(facing, 1);
    screen.drawImage(sprite, cel * 64, walking ? 0 : 128, 64, 64, -32, -60, 64, 64);
    screen.restore();
  } else {
    screen.fillStyle = '#d0cbb3';
    screen.fillRect(Math.round(x - 3), Math.round(heroFootY - 26), 6, 5);
    screen.fillStyle = '#1b2535';
    screen.fillRect(Math.round(x - 5), Math.round(heroFootY - 21), 10, 20);
  }

  // Brief bright aperture expansion when crossing Đinh / Bính / Ất / Giáp milestone
  if (!reduced.matches && now - tierFlashAt < 650) {
    const k = (now - tierFlashAt) / 650;
    screen.strokeStyle = `rgba(216, 237, 226, ${(1 - k) * 0.72})`;
    screen.lineWidth = 1;
    screen.beginPath();
    screen.arc(Math.round(x), Math.round(heroFootY - 22), Math.round(4 + k * 14), 0, Math.PI * 2);
    screen.stroke();
  }
}

function drawHopeSwarms(now, heroX, heroFootY) {
  const t = reduced.matches ? 0 : now / 850;

  for (const f of ambientFireflies) {
    const sx = f.x + Math.sin(t * f.speed + f.seed) * 6 - cameraX;
    if (sx < -16 || sx > canvas.width + 16) continue;
    const sy = f.y - 6 + Math.cos(t * f.speed * 0.8 + f.seed) * 5 - cameraY;
    drawGu(sx, sy, now, f.seed);
  }

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

  // Subtle cavern vignette + organic cyan primeval spring pressure haze when close to stamina cap
  const pressureRatio = state.x > flowerBank ? Math.max(0, (8 - state.resolve) / 8) : 0;
  const edgeAlpha = 0.55 + pressureRatio * 0.28;
  const shade = screen.createLinearGradient(0, 0, 0, canvas.height);
  shade.addColorStop(0, `rgba(10, 15, 20, ${edgeAlpha})`);
  shade.addColorStop(0.18, 'rgba(10, 15, 20, 0)');
  shade.addColorStop(0.84, 'rgba(10, 15, 20, 0)');
  shade.addColorStop(1, `rgba(10, 15, 20, ${edgeAlpha})`);
  screen.fillStyle = shade;
  screen.fillRect(0, 0, canvas.width, canvas.height);
  if (pressureRatio > 0) {
    const r = Math.max(canvas.width, canvas.height) * 0.65;
    const haze = screen.createRadialGradient(heroX, heroY - 16, r * 0.25, heroX, heroY - 16, r);
    haze.addColorStop(0, 'rgba(20, 56, 68, 0)');
    haze.addColorStop(1, `rgba(28, 72, 84, ${0.32 * pressureRatio})`);
    screen.fillStyle = haze;
    screen.fillRect(0, 0, canvas.width, canvas.height);
  }
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
  if (state.finished) return;
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor(((event.clientX - rect.left) * canvas.width / rect.width + cameraX) / tile);
  const y = Math.floor(((event.clientY - rect.top) * canvas.height / rect.height + cameraY) / tile);
  canvas.focus({ preventScroll: true });
  queuedKey = undefined;
  path = routeTo(state, x, y);
});
finishBtn.addEventListener('click', () => {
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
  tierFlashAt = -Infinity;
  byId('ceremony-result').hidden = true;
  showStory(0, false);
  updateHint('Qua sông ở đoạn nước nông. Dùng WASD, phím mũi tên hoặc chạm một ô.');
  renderStatus();
  canvas.focus({ preventScroll: true });
}

byId('retry').addEventListener('click', resetCeremony);
selection.addEventListener('submit', event => {
  event.preventDefault();
  const selected = new FormData(selection).get('hero');
  selectedHero = selected === 'ao-reu' ? 'ao-reu' : 'huyen-bao';
  sprite.src = 'assets/' + selectedHero + '-travel.png';
  byId('enter-village').href = 'village.html?hero=' + selectedHero;
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
