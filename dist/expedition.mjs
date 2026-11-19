import { coordinate } from './combat.mjs';
import { awakeningStorageKey } from './awakening-rules.mjs';
import { REAR_POST, createBeastKingRaid, raidProgress } from './beast-king-raid.mjs';
import { createHeroMotion, MOONLIGHT_RELEASE_MS, releasePalm } from './hero-motion.mjs';
import { createRampartDefense, updateWolfHealth } from './rampart-defense.mjs';
import { FOREST_POST, canAdvanceRear, createReinforcements, rearCheckpoint } from './reinforcement-post.mjs';
import {
  ABSORB_MS, RELIEF_START, SUPPLY_POST, advanceAbsorption, createLesson, settleTrainingShot, startAbsorption,
} from './rampart-lesson.mjs';
import { lessonCheckpointKey, readVillageArrival } from './village-arrival.mjs';
import { createWolfMotion } from './wolf-motion.mjs';
import atlas from './assets/rampart/atlas.mjs';
import {
  chooseRampartFrame, RAMPART_EDGE, RAMPART_FOREST_WIDTH, RAMPART_MENTOR, RAMPART_WOLVES, westForestFamily,
} from './rampart.mjs';
import {
  CONTINUE, GATE, MAP, MOONLIGHT, TERRAIN, TRAIL_ENTRY, TRAINING_POST,
  advanceHunt, cellDistance, clearShot, createWorld, findPath, hitHunt, insideHunt, locationOf, retryEncounter, toCell, toPoint, walk,
} from './world.mjs';

const byId = (id) => document.getElementById(id);
const field = byId('field');
const plane = byId('world-plane');
const map = byId('map');
const artwork = byId('map-ornaments');
const hero = byId('hero-unit');
const heroSprite = hero.querySelector('.sprite');
const beast = byId('wolf-unit');
const castButton = byId('cast-moon');
const absorbButton = byId('absorb-stone');
const absorbProgress = byId('absorption-progress');
const guide = byId('guide');
const introDialog = byId('raid-intro');
const mentorDialog = byId('mentor-dialog');
const mentorNext = byId('mentor-next');
const rearDialog = byId('rear-dialog');
const rearNext = byId('rear-next');
let rearLine = 0;
const rearSpeech = {
  report: [
    ['Bạn', 'Thú vương đã tới lũy tây! Giáo tập Tĩnh Nghi đang cầm chân nó.'],
    ['Đội trưởng hậu trại', 'Hai người lên lũy tây tiếp viện ngay. Còn ngươi, theo ta ra cổng đông đón đội tuần rừng.'],
  ],
  forest: [
    ['Đội trưởng hậu trại', 'Đội tuần rừng ở bãi săn phía trước. Giữ khoảng cách, chuẩn bị Nguyệt Quang rồi đi cùng ta.'],
  ],
};
const mentorLines = [
  'Nhóc con! Ngươi muốn chết hay sao mà đứng ngây ra đó, hãy lên phụ giúp đi.',
  'Lên lũy theo cầu thang. Tới ô đánh dấu, dùng Nguyệt Quang đánh con Điện Lang ở giữa. Mỗi lần phóng tốn hai điểm chân nguyên.',
];
const refillLine = 'Nếu hết chân nguyên hãy xuống hấp thụ nguyên thạch để hồi phục chân nguyên.';
let mentorLine = 0;
let introTimer;
const motion = matchMedia('(prefers-reduced-motion: reduce)');
const walkHint = matchMedia('(pointer: coarse)').matches ? 'Chạm một ô để đi tới.' : 'WASD · Phím mũi tên · Shift bật/tắt chạy · Bấm ô để đi';
const runToggle = byId('run-toggle');
const runPreference = 'cochannhan.explore.run';
let savedAwakening = null;
try {
  savedAwakening = sessionStorage.getItem(awakeningStorageKey);
} catch {
  // The ceremony passes the result in the URL if browser storage is unavailable.
}
const arrival = readVillageArrival(location.search, savedAwakening);
const checkpointId = `${arrival.hero}:${arrival.outcome?.depth ?? 'direct'}`;
let raidStage = 'lesson';
let rearPhase = 'report';
try {
  const saved = sessionStorage.getItem(lessonCheckpointKey);
  const rear = rearCheckpoint(saved, checkpointId);
  raidStage = rear ? 'rear' : raidProgress(saved, checkpointId);
  rearPhase = rear ?? 'report';
} catch {
  // The tutorial can run without browser storage.
}
let lesson = createLesson(raidStage !== 'lesson');
const wearsAoReu = arrival.hero === 'ao-reu';
if (wearsAoReu) {
  document.body.classList.add('hero-ao-reu');
  byId('hero-name').textContent = 'Cổ sư Áo rêu';
}
if (arrival.outcome) {
  const { grade, seaPct } = arrival.outcome;
  const summary = byId('awakening-summary');
  summary.textContent = `${grade} · Nguyên Hải ${seaPct}%`;
  summary.hidden = false;
}
const heroMotion = createHeroMotion(heroSprite, motion, wearsAoReu);
const wolfMotion = createWolfMotion(beast, motion);
const stepDurations = { walk: 485, run: 280, climb: 630 };

const keys = {
  arrowup: -MAP.columns, w: -MAP.columns,
  arrowleft: -1, a: -1,
  arrowright: 1, d: 1,
  arrowdown: MAP.columns, s: MAP.columns,
};
function newTrip() {
  const trip = createWorld({ seed: (Math.random() * 2 ** 32) >>> 0 });
  if (lesson.phase === 'complete') {
    const rearSpawn = rearPhase === 'forest' ? GATE : rearPhase === 'trail' ? FOREST_POST : REAR_POST;
    trip.player = { ...trip.player, cell: raidStage === 'rear' ? rearSpawn : SUPPLY_POST, qi: trip.player.maxQi };
  }
  return trip;
}
let world = newTrip();
let reliefCell = lesson.phase === 'complete' ? TRAINING_POST : RELIEF_START;
let reliefRoute;
let nextReliefAt = 0;
let castReadyAt = 0;
let regenAt = Infinity;
let castEpoch = 0;
let pendingCast;
let stepTimer;
let nextStepAt = 0;
let runEnabled = false;
let pendingShiftTap = false;
try {
  runEnabled = localStorage.getItem(runPreference) === 'on';
} catch {
  // The toggle also works for this page when browser storage is unavailable.
}
let route = [];
let markedThreats = [];
const tiles = [];
const rampartSurfaces = [];
const rampartWolves = [];
const raidPackWolves = [];
const forestEdges = [
  [-1, 0, { frame: 'bamboo-edge-east' }],
  [1, 0, { frame: 'bamboo-edge-east', flip: true }],
  [0, -1, { frame: 'bamboo-edge-south' }],
  [0, 1, { frame: 'bamboo-edge-south', flipY: true }],
];
const westernScrub = [
  [1.3, 5.3], [-1.1, 6.6], [-2.1, 8.5], [-2.6, 10.1], [-2.2, 12.7],
  [-1.3, 14.4], [-0.8, 14.8], [-1.5, 16.2], [0.6, 17.7], [1.5, 21.6],
];
const sheetUrls = Object.fromEntries(Object.entries(atlas.sheets).map(([id, sheet]) => [
  id, new URL(`./assets/rampart/${sheet.file}`, import.meta.url).href,
]));

function announce(message) {
  byId('world-announcement').textContent = message;
}

function renderRunToggle() {
  runToggle.setAttribute('aria-pressed', String(runEnabled));
  runToggle.textContent = runEnabled ? 'Chạy · Bật' : 'Chạy · Tắt';
}

function toggleRun() {
  if (world.mode === 'defeat') return;
  runEnabled = !runEnabled;
  renderRunToggle();
  announce(runEnabled ? 'Đã bật chạy.' : 'Đã chuyển sang đi bộ.');
  try {
    localStorage.setItem(runPreference, runEnabled ? 'on' : 'off');
  } catch {
    // Keep the in-memory choice for the rest of the session.
  }
}

function setHint(message, shouldAnnounce = false) {
  byId('field-hint').textContent = message;
  if (shouldAnnounce) announce(message);
}

function paintRampartFrame(node, id) {
  const frame = atlas.frames[id];
  const sheet = atlas.sheets[frame.sheet];
  const axis = (offset, excess) => excess ? 100 * offset / excess : 0;
  node.style.backgroundImage = `url("${sheetUrls[frame.sheet]}")`;
  node.style.backgroundSize = `${100 * sheet.width / frame.width}% ${100 * sheet.height / frame.height}%`;
  node.style.backgroundPosition = `${axis(frame.x, sheet.width - frame.width)}% ${axis(frame.y, sheet.height - frame.height)}%`;
  node.dataset.frame = id;
}

function surfaceTexture() {
  for (const { tile, family, cell } of rampartSurfaces) {
    paintRampartFrame(tile, chooseRampartFrame(family, cell, world.seed));
  }
}

function drawRampartOrnament(layer, col, row, { frame: id, flip, flipY, width, height, uphill }) {
  const frame = atlas.frames[id];
  const node = document.createElement('span');
  node.className = 'map-ornament';
  // Center the two-tile artwork on the lane. Its rails occupy the adjacent blocked cells.
  const insetX = uphill === 'north' ? 0.5 : 0;
  const insetY = uphill === 'west' ? 0.5 : 0;
  node.style.left = `calc(var(--tile) * ${col + insetX})`;
  node.style.top = `calc(var(--tile) * ${row + insetY})`;
  node.style.width = `calc(var(--tile) * ${(width ?? frame.width / atlas.tileSize) - 2 * insetX})`;
  node.style.height = `calc(var(--tile) * ${(height ?? frame.height / atlas.tileSize) - 2 * insetY})`;
  if (uphill) node.style.zIndex = '1';
  if (flip || flipY) node.style.transform = `scale(${flip ? -1 : 1}, ${flipY ? -1 : 1})`;
  paintRampartFrame(node, id);
  layer.append(node);
}

function drawWestClearing(layer) {
  function familyAt(col, row) {
    if (col < 0) return westForestFamily(col, row);
    return TERRAIN[row * MAP.columns + col]?.rampart?.family;
  }
  for (let row = 1; row < MAP.rows - 1; row++) {
    for (let col = -RAMPART_FOREST_WIDTH; col <= 2; col++) {
      if (familyAt(col, row) !== 'mud') continue;
      for (const [dx, dy, ornament] of forestEdges) {
        if (familyAt(col + dx, row + dy) === 'bamboo') drawRampartOrnament(layer, col, row, ornament);
      }
    }
  }
  const shade = document.createElement('span');
  shade.className = 'west-wall-shade';
  shade.style.setProperty('--wall-length', MAP.rows - 7);
  layer.append(shade);
  for (const [index, [col, row]] of westernScrub.entries()) {
    const tuft = document.createElement('span');
    tuft.className = 'apron-scrub';
    tuft.style.left = `calc(var(--tile) * ${col})`;
    tuft.style.top = `calc(var(--tile) * ${row})`;
    if (index % 2) tuft.classList.add('small');
    layer.append(tuft);
  }
}

function createMap() {
  plane.style.setProperty('--columns', MAP.columns);
  const forest = byId('rampart-forest');
  forest.style.setProperty('--forest-width', RAMPART_FOREST_WIDTH);
  for (let row = 0; row < MAP.rows; row++) {
    for (let col = -RAMPART_FOREST_WIDTH; col < 0; col++) {
      const tile = document.createElement('span');
      tile.className = 'map-ornament';
      tile.style.position = 'static';
      forest.append(tile);
      rampartSurfaces.push({ tile, family: westForestFamily(col, row), cell: row * MAP.columns + col });
    }
  }
  const fragment = document.createDocumentFragment();
  const overlays = document.createDocumentFragment();
  drawWestClearing(overlays);
  TERRAIN.forEach(({ ground, prop, variant, rampart }, cell) => {
    const { col, row } = toPoint(cell);
    const tile = document.createElement('button');
    tile.type = 'button';
    tile.className = ground ? `world-tile ${ground}` : 'world-tile';
    tile.dataset.cell = cell;
    tile.tabIndex = -1;
    if (!insideHunt(cell)) tile.classList.add('outside-hunt');
    if (rampart) {
      tile.classList.add('rampart-surface');
      rampartSurfaces.push({ tile, family: rampart.family, cell });
      for (const ornament of rampart.ornaments) drawRampartOrnament(overlays, col, row, ornament);
    } else {
      tile.style.setProperty('--tile-x', `${(variant % 8) * 100 / 7}%`);
      if (col <= RAMPART_EDGE + 6) {
        tile.classList.add('rampart-verge');
        tile.style.setProperty('--verge-tint', (RAMPART_EDGE + 7 - col) * 9 + '%');
      }
    }

    const name = coordinate(cell, MAP.columns);
    const blocked = Boolean(prop || rampart?.blocked);
    tile.classList.toggle('blocked', blocked);
    const detail = blocked ? ', ô bị chặn' : rampart?.stair ? ', cầu thang' : rampart?.elevation ? ', sàn lũy' : '';
    tile.setAttribute('aria-label', name + detail);
    if (prop) {
      const feature = document.createElement('span');
      feature.className = `prop ${prop}`;
      feature.setAttribute('aria-hidden', 'true');
      tile.append(feature);
    }
    tiles.push(tile);
    fragment.append(tile);
  });
  map.append(fragment);
  artwork.append(overlays);
  surfaceTexture();
}

function addRampartWolf(col, row) {
  const unit = beast.cloneNode(true);
  unit.removeAttribute('id');
  unit.classList.add('rampart-wolf');
  unit.hidden = true;
  unit.style.left = `calc(var(--tile) * ${col})`;
  unit.style.top = `calc(var(--tile) * ${row})`;
  const impact = document.createElement('i');
  impact.className = 'wall-impact';
  unit.append(impact);
  plane.append(unit);
  return { unit, motion: createWolfMotion(unit, motion, impact) };
}

function animateRampartWolves(guardVolley = true) {
  rampartWolves.forEach(({ unit, motion: wolf }, index) => {
    const { col, row, startCol, startRow } = RAMPART_WOLVES[index];
    unit.hidden = false;
    wolf.run(startCol - col, startRow - row, {
      duration: 1500, delay: 280 + index * 290, after: wolf.attackWall,
    });
  });
  rampartDefense.begin(guardVolley);
}

function rushRaidPack() {
  animateRampartWolves(false);
  raidPackWolves.forEach(({ unit, motion: wolf }, index) => {
    unit.hidden = false;
    wolf.run(-4.1, index % 2 ? -.5 : .5, { duration: 1080 + index * 170, delay: 80 + index * 120 });
  });
}

function showMentorLine() {
  const refilling = lesson.phase === 'refill';
  byId('mentor-line').textContent = refilling ? refillLine : mentorLines[mentorLine];
  mentorNext.textContent = refilling ? 'Tới chỗ tiếp tế' : mentorLine === mentorLines.length - 1 ? 'Tới vị trí bắn' : 'Tiếp tục';
}

function showMentor() {
  mentorLine = 0;
  mentorDialog.returnValue = '';
  showMentorLine();
  mentorDialog.showModal();
  aimCamera();
}

function beginArrival() {
  rampartDefense.stop();
  for (const wolf of [...rampartWolves, ...raidPackWolves]) {
    wolf.motion.stop();
    wolf.unit.hidden = true;
  }
  if (lesson.phase === 'complete') {
    if (raidStage === 'scene') startRaid();
    else {
      moveReliefOffPost();
      rushRaidPack();
      raid.aftermath();
      reinforcements.reset(rearPhase, performance.now());
      aimCamera();
    }
    return;
  }
  if (!arrival.outcome) {
    showMentor();
    return;
  }
  introDialog.showModal();
  if (!motion.matches) introTimer = setTimeout(() => introDialog.close(), 4500);
}

function place(node, cell, size) {
  const { col, row } = toPoint(cell);
  node.style.transform = `translate3d(${col * size}px,${row * size}px,0)`;
}

function aimCamera() {
  const { cell } = world.player;
  const { col, row } = toPoint(cell);
  const nearRampart = col <= RAMPART_EDGE;
  field.classList.toggle('rampart-view', nearRampart);
  const size = Number.parseFloat(getComputedStyle(field).getPropertyValue('--tile'));
  if (!size || !field.clientWidth) return;
  const offset = (point, screen, length, min = 0) =>
    Math.min(Math.max(0, length * size - screen), Math.max(min, (point + 0.5) * size - screen / 2));
  const lookWest = mentorDialog.open ? 0 : 4.7 * Math.min(1, Math.max(0, (RAMPART_EDGE - col) / 5));
  const westEdge = nearRampart ? -RAMPART_FOREST_WIDTH * size : 0;
  const [focusCol, focusRow] = raid.camera ?? [col - lookWest, row];
  const x = offset(focusCol, field.clientWidth, MAP.columns, westEdge);
  const y = offset(focusRow, field.clientHeight, MAP.rows);
  plane.style.transform = `translate3d(${-x}px,${-y}px,0)`;
  place(hero, cell, size);
  if (raidStage === 'lesson') place(byId('mentor-unit'), toCell(RAMPART_MENTOR.col, RAMPART_MENTOR.row), size);
  place(byId('gate-marker'), GATE, size);
  place(byId('end-marker'), CONTINUE, size);
  place(byId('training-marker'), TRAINING_POST, size);
  place(byId('supply-marker'), SUPPLY_POST, size);
  place(byId('rear-marker'), REAR_POST, size);
  place(byId('forest-marker'), FOREST_POST, size);
  place(rampartDefense.reliefUnit, reliefCell, size);
  if (!beast.hidden) place(beast, world.battle.rival.cell, size);
}

function meter(name, current, max) {
  byId(name).textContent = `${current} / ${max}`;
  const progress = byId(`${name}-meter`);
  progress.max = max;
  progress.value = current;
}

function rearInteractionAvailable(now) {
  return now >= nextStepAt && canAdvanceRear(rearPhase, world.player.cell, REAR_POST, reinforcements.ready(now)) !== rearPhase;
}

function renderObjective() {
  const atPost = world.player.cell === TRAINING_POST;
  const atSupply = world.player.cell === SUPPLY_POST;
  const pastGate = toPoint(world.player.cell).col >= RAMPART_EDGE;
  let title = 'Ra cổng đông';
  let detail = 'Qua cổng đông để vào đường rừng.';
  let button = 'Đi tới cổng';
  let interaction = false;
  if (world.mode === 'defeat') {
    title = 'Thử lại cuộc săn';
    detail = world.notice;
  } else if (world.mode === 'battle') {
    title = 'Hạ Điện Lang';
    detail = 'Di chuyển để né ô đỏ. Bấm F hoặc chạm Nguyệt Quang để bắn.';
  } else if (world.reached) {
    title = 'Đã tới lối mòn';
    detail = world.notice;
  } else if (world.cleared) {
    title = 'Đi tiếp về phía đông';
    detail = 'Điện Lang đã gục. Bạn có thể tự do đi lại qua bãi săn.';
    button = 'Đi tới lối mòn';
  } else if (raidStage === 'scene') {
    title = 'Thú vương xông tới';
    detail = 'Tĩnh Nghi đang giữ lũy tây.';
  } else if (raidStage === 'aid') {
    title = 'Đi gọi viện binh';
    detail = 'Về hậu trại theo lối đá phía sau lũy.';
    button = 'Tới hậu trại';
  } else if (raidStage === 'rear' && rearPhase === 'report') {
    interaction = world.player.cell === REAR_POST;
    title = interaction ? 'Báo tin cho đội trưởng' : 'Về hậu trại';
    detail = interaction ? 'Bấm E hoặc chạm Báo tin để gọi quân tiếp viện.' : 'Tới chỗ đội trưởng đang tập hợp quân.';
    button = interaction ? 'Báo tin' : 'Tới hậu trại';
  } else if (raidStage === 'rear' && rearPhase === 'gate') {
    title = 'Theo đội trưởng qua cổng đông';
    detail = 'Hai cổ sư đã nhận lệnh lên lũy tây.';
    button = 'Tới cổng đông';
  } else if (raidStage === 'rear' && rearPhase === 'forest') {
    interaction = world.player.cell === FOREST_POST;
    title = 'Tập kết ngoài rừng';
    const waiting = interaction && !reinforcements.ready(performance.now());
    detail = waiting ? 'Giữ vị trí, đội trưởng đang tới.' : interaction ? 'Gặp đội trưởng trước khi vào bãi săn.' : 'Theo lối đất tới điểm tập kết.';
    button = waiting ? 'Đợi đội trưởng' : interaction ? 'Trao đổi' : 'Tới điểm tập kết';
  } else if (pastGate) {
    title = 'Tới bãi săn';
    detail = 'Theo lối đất giữa rừng tới nơi Điện Lang phục kích.';
    button = 'Theo đường rừng';
  } else if (lesson.phase === 'training') {
    title = atPost ? 'Tập phóng Nguyệt Quang' : 'Lên sàn lũy tây';
    detail = atPost ? 'Bấm F hoặc chạm Nguyệt Quang để bắn. Theo dõi chân nguyên mỗi lần phóng.'
      : 'Theo cầu thang lên vị trí bắn. Quan sát các cổ sư phòng thủ.';
    button = 'Tới vị trí bắn';
  } else if (lesson.phase === 'refill') {
    title = atSupply ? 'Hồi chân nguyên' : 'Xuống lũy đổi ca';
    detail = atSupply ? 'Dùng một viên nguyên thạch. Đứng yên cho tới khi hấp thụ xong.'
      : 'Xuống theo cầu thang tới chỗ tiếp tế. Một cổ sư sẽ lên thay.';
    button = 'Tới chỗ tiếp tế';
  }
  byId('objective-title').textContent = title;
  byId('objective-detail').textContent = detail;
  guide.textContent = button;
  guide.disabled = interaction && !rearInteractionAvailable(performance.now());
  if (interaction) guide.setAttribute('aria-keyshortcuts', 'E');
  else guide.removeAttribute('aria-keyshortcuts');
  guide.hidden = world.mode !== 'explore' || world.reached || raidStage === 'scene' ||
    (lesson.phase === 'training' && atPost) || (lesson.phase === 'refill' && atSupply);
}

function render() {
  const now = performance.now();
  const fighting = world.mode === 'battle';
  const defeated = world.mode === 'defeat';
  const inTraining = world.player.cell === TRAINING_POST && lesson.phase === 'training' && now >= nextStepAt;
  const atSupply = world.player.cell === SUPPLY_POST;
  const absorbing = lesson.absorbUntil !== null;
  runToggle.hidden = defeated || raidStage === 'scene' || (lesson.phase === 'refill' && atSupply);
  castButton.hidden = !fighting && !inTraining;
  castButton.setAttribute('aria-disabled', String(world.player.qi < MOONLIGHT.cost || now < castReadyAt));
  absorbButton.hidden = lesson.phase !== 'refill' || !atSupply || now < nextStepAt;
  absorbButton.setAttribute('aria-disabled', String(absorbing));
  absorbProgress.hidden = !absorbing;
  byId('stone-status').hidden = lesson.phase === 'training';
  byId('stone-count').textContent = lesson.phase === 'refill' ? '1' : '0';
  byId('location').textContent = locationOf(world.player.cell);
  const terrain = TERRAIN[world.player.cell].rampart;
  const level = terrain?.stair ? ' · Cầu thang' : terrain?.elevation ? ' · Sàn lũy' : '';
  byId('coordinates').textContent = `Ô ${coordinate(world.player.cell, MAP.columns)}${level}`;
  byId('mode').textContent = fighting ? 'Giao chiến' : defeated ? 'Thất bại' :
    raidStage === 'scene' ? 'Thú triều' : raidStage === 'aid' ? 'Gọi viện binh' : raidStage === 'rear' ? 'Khám phá' : 'Tập phòng thủ';
  meter('world-hp', world.player.hp, world.player.maxHp);
  meter('world-qi', world.player.qi, world.player.maxQi);
  byId('training-marker').hidden = lesson.phase !== 'training' || world.player.cell === TRAINING_POST;
  byId('supply-marker').hidden = lesson.phase !== 'refill' || atSupply;
  byId('rear-marker').hidden = !(raidStage === 'aid' ||
    (raidStage === 'rear' && rearPhase === 'report' && world.player.cell !== REAR_POST));
  byId('forest-marker').hidden = raidStage !== 'rear' || rearPhase !== 'forest' || world.player.cell === FOREST_POST;
  byId('end-marker').hidden = !world.cleared;
  byId('gate-marker').hidden = raidStage !== 'rear' || !['gate', 'trail'].includes(rearPhase) || toPoint(world.player.cell).col >= 22;
  byId('wolf-status').hidden = !fighting;
  byId('wolf-intent').hidden = !fighting;
  byId('defeat').hidden = !defeated;
  beast.hidden = !world.battle;
  if (world.battle) {
    const { hp, maxHp } = world.battle.rival;
    updateWolfHealth(beast, hp, maxHp);
    meter('wolf-hp', hp, maxHp);
  }
  if (fighting) {
    byId('wolf-intent-name').textContent = world.battle.intent ? 'Vồ mồi' : 'Điện Lang';
    byId('wolf-intent-detail').textContent = world.battle.intent ? 'Rời vùng màu đỏ trước khi sói lao tới.' : 'Giữ khoảng cách và bắn khi Điện Lang trong tầm.';
  }
  field.classList.toggle('in-battle', fighting);
  for (const cell of markedThreats) tiles[cell].classList.remove('threat');
  markedThreats = fighting ? world.battle.intent?.cells ?? [] : [];
  for (const cell of markedThreats) tiles[cell].classList.add('threat');
  renderObjective();
  aimCamera();
}
function stopWalk() {
  clearTimeout(stepTimer);
  stepTimer = undefined;
  route = [];
}

function step(target) {
  const previous = world;
  if (raidStage === 'scene') return false;
  if (raidStage !== 'rear' && toPoint(target).col >= RAMPART_EDGE) {
    setHint(raidStage === 'aid' ? 'Tới hậu trại để gọi viện binh.' : 'Hoàn thành bài tập phòng thủ trước khi rời trại.', true);
    return false;
  }
  if (raidStage === 'rear' && rearPhase === 'report' && toPoint(target).col >= RAMPART_EDGE) {
    setHint('Báo tin cho đội trưởng ở hậu trại trước khi ra cổng.', true);
    return false;
  }
  if (raidStage === 'rear' && rearPhase !== 'trail' && insideHunt(target)) {
    setHint('Gặp đội trưởng ở điểm tập kết trước khi vào bãi săn.', true);
    return false;
  }
  if (target === reliefCell) {
    setHint('Ô này có cổ sư tiếp viện.', true);
    return false;
  }
  world = walk(world, target, performance.now());
  if (world === previous) return false;
  if (lesson.absorbUntil !== null) {
    lesson = advanceAbsorption(lesson, world.player.cell, performance.now());
    setHint('Đã dừng hấp thụ. Viên nguyên thạch vẫn còn.', true);
  }
  const delta = toPoint(world.player.cell).col - toPoint(previous.player.cell).col;
  if (delta && !pendingCast) hero.style.setProperty('--face', Math.sign(delta));
  const onStairs = Boolean(TERRAIN[target].rampart?.stair || TERRAIN[previous.player.cell].rampart?.stair);
  const gait = onStairs ? 'climb' : runEnabled ? 'run' : 'walk';
  const duration = stepDurations[gait];
  field.style.setProperty('--step-time', duration + 'ms');
  nextStepAt = performance.now() + duration;
  heroMotion.travel(gait, duration);
  field.classList.add('walking');
  if (raidStage === 'aid' && world.player.cell === REAR_POST) {
    saveRaid('rear');
    setHint('Đã đến hậu trại. Báo tin cho đội trưởng.', true);
  }
  if (raidStage === 'rear' && rearPhase === 'gate' && world.player.cell === GATE) {
    saveRear('forest');
    reinforcements.leadToForest(performance.now());
    setHint('Theo đội trưởng tới điểm tập kết ngoài rừng.', true);
  }
  render();
  if (world.mode === 'battle' && previous.mode !== 'battle') {
    wolfMotion.idle();
    stopWalk();
    setHint(world.notice, true);
  } else if (world.reached && !previous.reached) {
    announce(world.notice);
  } else if (locationOf(previous.player.cell) !== locationOf(world.player.cell)) {
    announce(`Đã đến ${locationOf(world.player.cell)}.`);
  }
  return true;
}

function afterCurrentStep(advance) {
  const remaining = Math.ceil(nextStepAt - performance.now());
  if (remaining > 0) stepTimer = setTimeout(() => afterCurrentStep(advance), remaining);
  else advance();
}

function followRoute() {
  if (!route.length) return;
  const target = route.shift();
  if (step(target) && route.length) afterCurrentStep(followRoute);
}

function go(target) {
  stopWalk();
  if (target === world.player.cell) return;
  route = findPath(world, target, reliefCell);
  if (route.length) {
    if (world.mode !== 'battle') setHint(walkHint);
    afterCurrentStep(followRoute);
  } else {
    setHint('Ô này bị chắn hoặc chưa có đường tới.', true);
  }
}

function direction(from, to) {
  const { col, row } = toPoint(from);
  const target = toPoint(to);
  return [target.col - col, target.row - row];
}

function castMoon() {
  const now = performance.now();
  const training = lesson.phase === 'training' && world.player.cell === TRAINING_POST;
  const inHunt = world.mode === 'battle';
  if ((!training && !inHunt) || (training && (now < nextStepAt || !rampartDefense.targetHp()))) return;
  if (now < castReadyAt) return setHint('Nguyệt Quang đang hồi.');
  if (world.player.qi < MOONLIGHT.cost) return setHint('Đợi chân nguyên hồi lại.');
  const aim = inHunt ? world.battle.rival.cell : undefined;
  const { col, row } = toPoint(world.player.cell);
  const target = inHunt ? toPoint(aim) : rampartDefense.trainingTarget;
  const destination = inHunt ? { col: target.col + .5, row: target.row + .53 } : target;
  if (inHunt && cellDistance(world.player.cell, aim) > MOONLIGHT.range) return setHint('Điện Lang ngoài tầm bắn.');
  if (inHunt && !clearShot(world.player.cell, aim)) return setHint('Có vật cản trên đường bắn.');
  const facing = destination.col < col + .5 ? -1 : 1;
  hero.style.setProperty('--face', facing);
  pendingCast = {
    training, aim, destination, facing, animation: heroMotion.cast(), releaseAt: now + MOONLIGHT_RELEASE_MS,
  };
  castReadyAt = now + MOONLIGHT.cooldown;
  if (inHunt) regenAt = now + 1050;
  world = { ...world, player: { ...world.player, qi: world.player.qi - MOONLIGHT.cost } };
  render();
}

function releaseMoon({ training, aim, destination, facing }) {
  const sprite = heroSprite.getBoundingClientRect();
  const { left, top } = plane.getBoundingClientRect();
  const tile = hero.getBoundingClientRect().width;
  const [handX, handY] = releasePalm(wearsAoReu);
  const from = {
    col: (sprite.left - left + sprite.width * (facing > 0 ? handX : 1 - handX)) / tile,
    row: (sprite.top - top + sprite.height * handY) / tile,
  };
  if (training) rampartDefense.playerShot(from, finishTrainingShot);
  else if (world.mode === 'battle') {
    if (cellDistance(world.player.cell, aim) > MOONLIGHT.range || !clearShot(world.player.cell, aim)) {
      setHint('Đường bắn bị chắn hoặc Điện Lang đã ngoài tầm.');
      return;
    }
    const epoch = castEpoch;
    rampartDefense.shoot({ from, target: destination, windup: 0 }, () => {
      if (epoch !== castEpoch) return false;
      const next = hitHunt(world, aim, MOONLIGHT.damage);
      if (next === world) {
        if (world.mode === 'battle') setHint('Điện Lang đã tránh khỏi đường bắn.');
        return false;
      }
      world = next;
      if (world.cleared) wolfMotion.fall();
      else if (!world.battle.intent) wolfMotion.play('hit', { direction: [facing, 0] });
      setHint(world.notice, true);
      render();
      return true;
    });
  }
}

function finishTrainingShot() {
  const next = settleTrainingShot(lesson, world.player.qi);
  if (next === lesson) return;
  lesson = next;
  stopWalk();
  setHint('Chân nguyên đã cạn. Xuống lũy để hồi phục.', true);
  render();
  showMentor();
}

function tickRelief(now) {
  if (raidStage !== 'lesson' || lesson.phase === 'training' || mentorDialog.open || now < nextReliefAt || reliefCell === TRAINING_POST) return;
  if (!reliefRoute) {
    const { cell } = world.player;
    const terrain = TERRAIN[cell].rampart;
    if (toPoint(cell).col < 9 || terrain?.stair || terrain?.elevation || now < nextStepAt) return;
    const from = { ...world, player: { ...world.player, cell: reliefCell } };
    reliefRoute = findPath(from, TRAINING_POST, cell);
  }
  const next = reliefRoute[0];
  if (next === undefined || next === world.player.cell) return;
  const climbing = TERRAIN[reliefCell].rampart?.stair || TERRAIN[next].rampart?.stair;
  const duration = climbing ? 440 : 230;
  reliefCell = reliefRoute.shift();
  nextReliefAt = now + duration;
  const unit = rampartDefense.reliefUnit;
  unit.style.setProperty('--relief-step', duration + 'ms');
  unit.classList.add('relief-moving');
  place(unit, reliefCell, hero.offsetWidth);
  if (reliefCell === TRAINING_POST) {
    rampartDefense.coverTrainingPost();
    renderObjective();
  }
}

function absorbStone() {
  if (performance.now() < nextStepAt || mentorDialog.open) return;
  const next = startAbsorption(lesson, world.player.cell, performance.now());
  if (next === lesson) return;
  lesson = next;
  stopWalk();
  absorbProgress.value = 0;
  setHint('Đang hấp thụ nguyên thạch…', true);
  render();
}

function tickAbsorption(now) {
  if (lesson.absorbUntil === null) return;
  absorbProgress.value = Math.max(0, 1 - (lesson.absorbUntil - now) / ABSORB_MS);
  const next = advanceAbsorption(lesson, world.player.cell, now);
  if (next === lesson) return;
  lesson = next;
  world = { ...world, player: { ...world.player, qi: world.player.maxQi } };
  startRaid();
}

function saveCheckpoint(stage) {
  try {
    sessionStorage.setItem(lessonCheckpointKey, checkpointId + '|' + stage);
  } catch {
    // The completed lesson remains playable in memory.
  }
}

function saveRaid(stage) {
  raidStage = stage;
  saveCheckpoint(stage);
}

function saveRear(phase) {
  rearPhase = phase;
  saveCheckpoint('rear-' + phase);
}

function showRearLine() {
  const lines = rearSpeech[rearPhase];
  const [speaker, line] = lines[rearLine];
  byId('rear-speaker').textContent = speaker;
  byId('rear-line').textContent = line;
  const confirm = rearPhase === 'report' ? 'Theo đội trưởng' : 'Vào bãi săn';
  rearNext.textContent = rearLine === lines.length - 1 ? confirm : 'Tiếp tục';
}

function talkToRearLeader() {
  if (raidStage !== 'rear' || !rearSpeech[rearPhase] || rearDialog.open || !rearInteractionAvailable(performance.now())) return;
  stopWalk();
  pendingShiftTap = false;
  rearLine = 0;
  rearDialog.returnValue = '';
  showRearLine();
  rearDialog.showModal();
}

function moveReliefOffPost() {
  reliefCell = toCell(5, 13);
  rampartDefense.reliefUnit.classList.add('relief-moving');
  place(rampartDefense.reliefUnit, reliefCell, hero.offsetWidth);
}

function startRaid() {
  stopWalk();
  pendingShiftTap = false;
  saveRaid('scene');
  reliefCell = TRAINING_POST;
  raid.start(performance.now());
  rushRaidPack();
  setHint('Chân nguyên đã đầy. Ngoài lũy, đàn sói đang tràn lên.', true);
  render();
}

function finishRaid() {
  moveReliefOffPost();
  saveRaid('aid');
  reinforcements.reset('report');
  setHint('Đi về hậu trại để gọi viện binh.', true);
  render();
  field.focus({ preventScroll: true });
}

function tick(now) {
  const castAnimation = pendingCast?.animation;
  const atRelease = castAnimation && castAnimation.playState !== 'idle'
    ? castAnimation.currentTime >= MOONLIGHT_RELEASE_MS : now >= pendingCast?.releaseAt;
  if (pendingCast && atRelease) {
    const cast = pendingCast;
    pendingCast = undefined;
    releaseMoon(cast);
  }
  if (now >= nextStepAt && (
    (lesson.phase === 'training' && world.player.cell === TRAINING_POST && castButton.hidden) ||
    (lesson.phase === 'refill' && world.player.cell === SUPPLY_POST && absorbButton.hidden)
  )) render();
  tickRelief(now);
  tickAbsorption(now);
  reinforcements.tick(now, world.player.cell);
  if (raidStage === 'rear' && guide.disabled && rearInteractionAvailable(now)) renderObjective();
  if (raidStage === 'scene') {
    raid.advance(now);
    aimCamera();
  }
  if (now >= regenAt && world.mode !== 'defeat') {
    const qi = Math.min(world.player.maxQi, world.player.qi + 1);
    world = { ...world, player: { ...world.player, qi } };
    regenAt = qi === world.player.maxQi ? Infinity : now + 1050;
    render();
  }
  if (now >= castReadyAt && castButton.getAttribute('aria-disabled') === 'true'
    && world.player.qi >= MOONLIGHT.cost) castButton.setAttribute('aria-disabled', 'false');
  const { state, event } = advanceHunt(world, now);
  if (state !== world) {
    const damaged = state.player.hp < world.player.hp;
    world = state;
    render();
    if (event?.type === 'move') {
      const [dx, dy] = direction(event.to, event.from);
      wolfMotion.run(dx, dy);
    } else if (event?.type === 'windup') {
      const [dx, dy] = direction(world.battle.rival.cell, world.player.cell);
      if (dx) beast.style.setProperty('--face', Math.sign(dx));
      wolfMotion.play('huntPounce', { direction: [dx, dy] });
      setHint(world.notice, true);
    } else if (event?.type === 'pounce') {
      if (damaged) heroMotion.hit();
      setHint(world.notice, true);
      if (world.mode === 'defeat') {
        pendingCast = undefined;
        stopWalk();
        byId('retry-encounter').focus();
      }
    }
  }
  requestAnimationFrame(tick);
}


function reset() {
  stopWalk();
  wolfMotion.stop();
  raid.clear();
  raidStage = 'lesson';
  rearPhase = 'report';
  reinforcements.reset();
  lesson = createLesson();
  try {
    sessionStorage.removeItem(lessonCheckpointKey);
  } catch {
    // The in-memory lesson was reset above.
  }
  reliefCell = RELIEF_START;
  reliefRoute = undefined;
  nextReliefAt = 0;
  rampartDefense.reliefUnit.classList.remove('relief-moving');
  castReadyAt = 0;
  regenAt = Infinity;
  castEpoch++;
  pendingCast = undefined;
  world = newTrip();
  nextStepAt = 0;
  field.style.removeProperty('--step-time');
  surfaceTexture();
  field.classList.remove('walking');
  hero.style.removeProperty('--face');
  heroMotion.stand();
  render();
  byId('field-hint').textContent = walkHint;
  beginArrival();
}

byId('field-hint').textContent = walkHint;
renderRunToggle();
runToggle.addEventListener('click', toggleRun);
createMap();
for (const { col, row } of RAMPART_WOLVES) rampartWolves.push(addRampartWolf(col, row));
for (const [col, row] of [[.7, 7.9], [-.55, 10.1], [1.25, 14.75]]) {
  const wolf = addRampartWolf(col, row);
  wolf.unit.classList.add('raid-pack-wolf');
  wolf.unit.querySelector('.wolf-health').hidden = true;
  raidPackWolves.push(wolf);
}
const rampartDefense = createRampartDefense(plane, rampartWolves, motion, (index, hp) => {
  if (index !== 1 || lesson.phase !== 'training') return;
  if (hp) {
    setHint(`Trúng đòn. Điện Lang còn ${hp} sinh lực.`, true);
    return;
  }
  setHint('Đã hạ Điện Lang.', true);
});
const raid = createBeastKingRaid({
  field, plane, mentor: byId('mentor-unit'), dialogue: byId('raid-dialogue'), skipButton: byId('raid-skip'),
  motion, defense: rampartDefense, onYield: moveReliefOffPost, onFinish: finishRaid,
});
const reinforcements = createReinforcements(plane);
castButton.addEventListener('click', castMoon);
absorbButton.addEventListener('click', absorbStone);
introDialog.addEventListener('close', () => {
  clearTimeout(introTimer);
  showMentor();
});
mentorNext.addEventListener('click', () => {
  if (lesson.phase === 'refill' || ++mentorLine === mentorLines.length) mentorDialog.close('guide');
  else showMentorLine();
});
mentorDialog.addEventListener('close', () => {
  field.focus({ preventScroll: true });
  aimCamera();
  const refilling = lesson.phase === 'refill';
  if (!refilling) animateRampartWolves();
  if (mentorDialog.returnValue === 'guide') go(refilling ? SUPPLY_POST : TRAINING_POST);
});
rearNext.addEventListener('click', () => {
  if (++rearLine === rearSpeech[rearPhase].length) rearDialog.close('confirm');
  else showRearLine();
});
rearDialog.addEventListener('close', () => {
  field.focus({ preventScroll: true });
  if (rearDialog.returnValue !== 'confirm') return;
  const now = performance.now();
  const next = canAdvanceRear(rearPhase, world.player.cell, REAR_POST, reinforcements.ready(now));
  if (next === rearPhase) return;
  saveRear(next);
  if (next === 'gate') {
    reinforcements.dispatch(now, world.player.cell);
    setHint('Đã gọi viện binh. Theo đội trưởng qua cổng đông.', true);
  } else {
    reinforcements.leadToHunt(now);
    setHint('Đã gặp đội trưởng. Tiến tới bãi săn.', true);
  }
  render();
});
render();
field.classList.add('ready');
new ResizeObserver(aimCamera).observe(field);
requestAnimationFrame(tick);
beginArrival();

map.addEventListener('click', (event) => {
  const tile = event.target.closest('button[data-cell]');
  if (!tile || world.mode === 'defeat' || raidStage === 'scene' || rearDialog.open) return;
  field.focus({ preventScroll: true });
  go(Number(tile.dataset.cell));
});

document.addEventListener('keydown', event => {
  if (introDialog.open || mentorDialog.open || rearDialog.open || event.ctrlKey || event.metaKey || event.altKey || world.mode === 'defeat') return;
  if (raidStage === 'scene') {
    if (event.key === 'Escape') {
      event.preventDefault();
      raid.finish();
    }
    return;
  }
  const key = event.key.toLowerCase();
  if (key === 'shift') {
    if (!event.repeat) pendingShiftTap = true;
  } else if (Object.hasOwn(keys, key)) {
    event.preventDefault();
    if (event.repeat && performance.now() < nextStepAt) return;
    stopWalk();
    afterCurrentStep(() => step(world.player.cell + keys[key]));
  } else {
    pendingShiftTap = false;
    if (key === 'f' && !event.repeat) {
      event.preventDefault();
      castMoon();
    } else if (key === 'e' && !event.repeat) {
      event.preventDefault();
      if (raidStage === 'rear') talkToRearLeader();
      else absorbStone();
    }
  }
});

document.addEventListener('keyup', event => {
  if (event.key !== 'Shift') return;
  if (pendingShiftTap) toggleRun();
  pendingShiftTap = false;
});
window.addEventListener('blur', () => { pendingShiftTap = false; });

guide.addEventListener('click', () => {
  field.focus({ preventScroll: true });
  if (raidStage === 'scene') return;
  if (raidStage === 'aid') go(REAR_POST);
  else if (raidStage === 'rear' && rearPhase === 'report') {
    if (world.player.cell === REAR_POST) talkToRearLeader();
    else go(REAR_POST);
  } else if (raidStage === 'rear' && rearPhase === 'gate') go(GATE);
  else if (raidStage === 'rear' && rearPhase === 'forest') {
    if (world.player.cell === FOREST_POST) talkToRearLeader();
    else go(FOREST_POST);
  } else if (lesson.phase === 'training') go(TRAINING_POST);
  else if (lesson.phase === 'refill') go(SUPPLY_POST);
  else go(world.cleared ? CONTINUE : toPoint(world.player.cell).col < RAMPART_EDGE ? GATE : TRAIL_ENTRY);
});
byId('reset-trip').addEventListener('click', reset);
byId('retry-encounter').addEventListener('click', () => {
  castEpoch++;
  pendingCast = undefined;
  castReadyAt = 0;
  regenAt = Infinity;
  world = retryEncounter(world, performance.now());
  heroMotion.stand();
  wolfMotion.idle();
  render();
  setHint(world.notice, true);
  field.focus({ preventScroll: true });
});
