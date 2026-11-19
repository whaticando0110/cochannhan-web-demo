import { coordinate } from './combat.mjs';
import { createHeroMotion } from './hero-motion.mjs';
import { createRampartDefense, updateWolfHealth } from './rampart-defense.mjs';
import { createWolfMotion } from './wolf-motion.mjs';
import atlas from './assets/rampart/atlas.mjs';
import {
  chooseRampartFrame, RAMPART_EDGE, RAMPART_FOREST_WIDTH, RAMPART_WOLVES, westForestFamily,
} from './rampart.mjs';
import {
  CONTINUE, GATE, MAP, MOONLIGHT, TERRAIN, TRAIL_ENTRY, TRAINING_POST,
  advanceHunt, cellDistance, clearShot, createWorld, findPath, hitHunt, insideHunt, locationOf, retryEncounter, toPoint, walk,
} from './world.mjs';

const byId = (id) => document.getElementById(id);
const field = byId('field');
const plane = byId('world-plane');
const map = byId('map');
const artwork = byId('map-ornaments');
const hero = byId('hero-unit');
const beast = byId('wolf-unit');
const castButton = byId('cast-moon');
const guide = byId('guide');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
const walkHint = matchMedia('(pointer: coarse)').matches ? 'Chạm một ô để đi tới.' : 'WASD · Phím mũi tên · Shift bật/tắt chạy · Bấm ô để đi';
const runToggle = byId('run-toggle');
const runPreference = 'cochannhan.explore.run';
const wearsAoReu = new URLSearchParams(location.search).get('hero') === 'ao-reu';
if (wearsAoReu) {
  document.body.classList.add('hero-ao-reu');
  byId('hero-name').textContent = 'Cổ sư Áo rêu';
}
const heroMotion = createHeroMotion(hero.querySelector('.sprite'), motion, wearsAoReu);
const wolfMotion = createWolfMotion(beast, motion);
const stepDurations = { walk: 485, run: 280, climb: 630 };

const keys = {
  arrowup: -MAP.columns, w: -MAP.columns,
  arrowleft: -1, a: -1,
  arrowright: 1, d: 1,
  arrowdown: MAP.columns, s: MAP.columns,
};
const newTrip = () => createWorld({ seed: (Math.random() * 2 ** 32) >>> 0 });
let world = newTrip();
let trainingComplete = false;
let castReadyAt = 0;
let regenAt = Infinity;
let castEpoch = 0;
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

function createRampartWolves() {
  for (const { col, row } of RAMPART_WOLVES) {
    const unit = beast.cloneNode(true);
    unit.removeAttribute('id');
    unit.classList.add('rampart-wolf');
    unit.hidden = false;
    unit.style.left = `calc(var(--tile) * ${col})`;
    unit.style.top = `calc(var(--tile) * ${row})`;
    const impact = document.createElement('i');
    impact.className = 'wall-impact';
    unit.append(impact);
    plane.append(unit);
    rampartWolves.push({ unit, motion: createWolfMotion(unit, motion, impact) });
  }
}

function animateRampartWolves() {
  rampartWolves.forEach(({ motion: wolf }, index) => {
    const { col, row, startCol, startRow } = RAMPART_WOLVES[index];
    wolf.run(startCol - col, startRow - row, {
      duration: 1500, delay: 280 + index * 290, after: wolf.attackWall,
    });
  });
  rampartDefense.begin();
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
  const lookWest = 4.7 * Math.min(1, Math.max(0, (RAMPART_EDGE - col) / 5));
  const westEdge = nearRampart ? -RAMPART_FOREST_WIDTH * size : 0;
  const x = offset(col - lookWest, field.clientWidth, MAP.columns, westEdge);
  const y = offset(row, field.clientHeight, MAP.rows);
  plane.style.transform = `translate3d(${-x}px,${-y}px,0)`;
  place(hero, cell, size);
  place(byId('gate-marker'), GATE, size);
  place(byId('end-marker'), CONTINUE, size);
  place(byId('training-marker'), TRAINING_POST, size);
  if (!beast.hidden) place(beast, world.battle.rival.cell, size);
}

function meter(name, current, max) {
  byId(name).textContent = `${current} / ${max}`;
  const progress = byId(`${name}-meter`);
  progress.max = max;
  progress.value = current;
}

function renderObjective() {
  const atPost = world.player.cell === TRAINING_POST;
  const pastGate = toPoint(world.player.cell).col >= 14;
  let title = 'Ra cổng đông';
  let detail = 'Qua cổng đông để vào đường rừng.';
  let button = 'Đi tới cổng';
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
  } else if (pastGate) {
    title = 'Tới bãi săn';
    detail = 'Theo lối đất giữa rừng tới nơi Điện Lang phục kích.';
    button = 'Theo đường rừng';
  } else if (!trainingComplete) {
    title = atPost ? 'Tập phóng Nguyệt Quang' : 'Lên sàn lũy tây';
    detail = atPost ? 'Bấm F hoặc chạm Nguyệt Quang hai lần để hạ con Điện Lang trước mặt.'
      : 'Theo cầu thang lên vị trí bắn. Quan sát các cổ sư phòng thủ.';
    button = 'Tới vị trí bắn';
  }
  byId('objective-title').textContent = title;
  byId('objective-detail').textContent = detail;
  guide.textContent = button;
  guide.hidden = world.mode !== 'explore' || world.reached || (atPost && !trainingComplete);
}

function render() {
  const now = performance.now();
  const fighting = world.mode === 'battle';
  const defeated = world.mode === 'defeat';
  const inTraining = world.player.cell === TRAINING_POST && !trainingComplete && now >= nextStepAt;
  runToggle.hidden = defeated;
  castButton.hidden = !fighting && !inTraining;
  castButton.setAttribute('aria-disabled', String(world.player.qi < MOONLIGHT.cost || now < castReadyAt));
  byId('location').textContent = locationOf(world.player.cell);
  const terrain = TERRAIN[world.player.cell].rampart;
  const level = terrain?.stair ? ' · Cầu thang' : terrain?.elevation ? ' · Sàn lũy' : '';
  byId('coordinates').textContent = `Ô ${coordinate(world.player.cell, MAP.columns)}${level}`;
  byId('mode').textContent = fighting ? 'Giao chiến' : defeated ? 'Thất bại' : trainingComplete ? 'Khám phá' : 'Tập phòng thủ';
  meter('world-hp', world.player.hp, world.player.maxHp);
  meter('world-qi', world.player.qi, world.player.maxQi);
  byId('training-marker').hidden = trainingComplete;
  byId('end-marker').hidden = !world.cleared;
  byId('gate-marker').hidden = !trainingComplete || toPoint(world.player.cell).col >= 22;
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
  if (!trainingComplete && toPoint(target).col >= RAMPART_EDGE) {
    setHint('Tập phóng Nguyệt Quang trên lũy tây trước khi rời trại.', true);
    return false;
  }
  world = walk(world, target, performance.now());
  if (world === previous) return false;
  const delta = toPoint(world.player.cell).col - toPoint(previous.player.cell).col;
  if (delta) hero.style.setProperty('--face', Math.sign(delta));
  const onStairs = Boolean(TERRAIN[target].rampart?.stair || TERRAIN[previous.player.cell].rampart?.stair);
  const gait = onStairs ? 'climb' : runEnabled ? 'run' : 'walk';
  const duration = stepDurations[gait];
  field.style.setProperty('--step-time', duration + 'ms');
  nextStepAt = performance.now() + duration;
  heroMotion.travel(gait, duration);
  field.classList.add('walking');
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
  route = findPath(world, target);
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
  const training = !trainingComplete && world.player.cell === TRAINING_POST;
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
  heroMotion.cast();
  const from = { col: col + .5 + facing * .23, row: row + .26 };
  castReadyAt = now + MOONLIGHT.cooldown;
  regenAt = now + 1050;
  world = { ...world, player: { ...world.player, qi: world.player.qi - MOONLIGHT.cost } };
  if (training) rampartDefense.playerShot(from);
  else {
    const epoch = castEpoch;
    rampartDefense.shoot({ from, target: destination }, () => {
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
  render();
}

function tick(now) {
  if (world.player.cell === TRAINING_POST && !trainingComplete && castButton.hidden && now >= nextStepAt) render();
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
      setHint(world.notice, true);
      if (world.mode === 'defeat') {
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
  trainingComplete = false;
  castReadyAt = 0;
  regenAt = Infinity;
  castEpoch++;
  world = newTrip();
  nextStepAt = 0;
  field.style.removeProperty('--step-time');
  surfaceTexture();
  field.classList.remove('walking');
  hero.style.removeProperty('--face');
  heroMotion.stand();
  render();
  animateRampartWolves();
  byId('field-hint').textContent = walkHint;
  field.focus({ preventScroll: true });
  announce('Bạn đang ở Cổ Nguyệt Sơn Trại.');
}

byId('field-hint').textContent = walkHint;
renderRunToggle();
runToggle.addEventListener('click', toggleRun);
createMap();
createRampartWolves();
const rampartDefense = createRampartDefense(plane, rampartWolves, motion, (index, hp) => {
  if (index !== 1) return;
  if (hp) {
    setHint(`Trúng đòn. Điện Lang còn ${hp} sinh lực.`, true);
    return;
  }
  trainingComplete = true;
  setHint('Đã hạ Điện Lang. Qua cổng đông để tới bãi săn.', true);
  render();
});
castButton.addEventListener('click', castMoon);
render();
animateRampartWolves();
field.classList.add('ready');
new ResizeObserver(aimCamera).observe(field);
requestAnimationFrame(tick);

map.addEventListener('click', (event) => {
  const tile = event.target.closest('button[data-cell]');
  if (!tile || world.mode === 'defeat') return;
  field.focus({ preventScroll: true });
  go(Number(tile.dataset.cell));
});

document.addEventListener('keydown', event => {
  if (event.ctrlKey || event.metaKey || event.altKey || world.mode === 'defeat') return;
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
  go(world.cleared ? CONTINUE : !trainingComplete ? TRAINING_POST : toPoint(world.player.cell).col < RAMPART_EDGE ? GATE : TRAIL_ENTRY);
});
byId('reset-trip').addEventListener('click', reset);
byId('retry-encounter').addEventListener('click', () => {
  castEpoch++;
  castReadyAt = 0;
  regenAt = Infinity;
  world = retryEncounter(world, performance.now());
  heroMotion.stand();
  wolfMotion.idle();
  render();
  setHint(world.notice, true);
  field.focus({ preventScroll: true });
});
