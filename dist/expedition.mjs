import { actionBlock, coordinate, moveTargets, neighbors } from './combat.mjs';
import { createHeroMotion } from './hero-motion.mjs';
import atlas from './assets/rampart/atlas.mjs';
import { chooseRampartFrame } from './rampart.mjs';
import {
  CONTINUE, FIELD_ACTIONS, GATE, MAP, TERRAIN, TRAIL_ENTRY,
  createWorld, fight, findPath, insideHunt, locationOf, retryEncounter, toPoint, walk,
} from './world.mjs';

const byId = (id) => document.getElementById(id);
const field = byId('field');
const plane = byId('world-plane');
const map = byId('map');
const artwork = byId('map-ornaments');
const hero = byId('hero-unit');
const beast = byId('wolf-unit');
const cursor = byId('target-cursor');
const guide = byId('guide');
const motion = matchMedia('(prefers-reduced-motion: reduce)');
const heroMotion = createHeroMotion(hero.querySelector('.sprite'), motion);

const keys = {
  arrowup: -MAP.columns, w: -MAP.columns,
  arrowleft: -1, a: -1,
  arrowright: 1, d: 1,
  arrowdown: MAP.columns, s: MAP.columns,
};
const actionNotes = {
  move: 'Tối đa 2 ô',
  strike: 'Tầm 1 ô · +1 nguyên',
  moon: 'Tầm 4 ô · −2 nguyên',
  guard: 'Giảm sát thương · +1 nguyên',
};
const actionHints = {
  move: 'Đi tối đa 2 ô. Cây, đá và đối thủ chặn đường.',
  strike: 'Đánh tay không ở ô kế bên và hồi 1 chân nguyên.',
  moon: 'Dùng 2 chân nguyên để gây 26 sát thương trong tầm 4 ô.',
  guard: 'Giảm một nửa sát thương trong lượt và hồi 1 chân nguyên.',
};

const newTrip = () => createWorld({ seed: (Math.random() * 2 ** 32) >>> 0 });
let world = newTrip();
let selecting = false;
let selectedCell = world.player.cell;
let stepTimer;
let nextStepAt = 0;
let route = [];
let markedThreats = [];
let markedMoves = [];
const buttons = {};
const tiles = [];
const rampartSurfaces = [];
const sheetUrls = Object.fromEntries(Object.entries(atlas.sheets).map(([id, sheet]) => [
  id, new URL(`./assets/rampart/${sheet.file}`, import.meta.url).href,
]));

function announce(message) {
  byId('world-announcement').textContent = message;
}

function setHint(message, shouldAnnounce = false) {
  const hint = world.mode === 'battle' ? 'field-action-hint' : 'field-hint';
  byId(hint).textContent = message;
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

function drawRampartOrnament(layer, cell, { frame: id, flip, width, height }) {
  const { col, row } = toPoint(cell);
  const frame = atlas.frames[id];
  const node = document.createElement('span');
  node.className = 'map-ornament';
  node.style.left = `calc(var(--tile) * ${col})`;
  node.style.top = `calc(var(--tile) * ${row})`;
  node.style.width = `calc(var(--tile) * ${width ?? frame.width / atlas.tileSize})`;
  node.style.height = `calc(var(--tile) * ${height ?? frame.height / atlas.tileSize})`;
  if (flip) node.style.transform = 'scaleX(-1)';
  paintRampartFrame(node, id);
  layer.append(node);
}

function createMap() {
  plane.style.setProperty('--columns', MAP.columns);
  const fragment = document.createDocumentFragment();
  const overlays = document.createDocumentFragment();
  TERRAIN.forEach(({ ground, prop, variant, rampart }, cell) => {
    const tile = document.createElement('button');
    tile.type = 'button';
    tile.className = ground ? `world-tile ${ground}` : 'world-tile';
    tile.dataset.cell = cell;
    tile.tabIndex = -1;
    if (!insideHunt(cell)) tile.classList.add('outside-hunt');
    if (rampart) {
      rampartSurfaces.push({ tile, family: rampart.family, cell });
      for (const ornament of rampart.ornaments) drawRampartOrnament(overlays, cell, ornament);
    } else {
      tile.style.setProperty('--tile-x', `${(variant % 8) * 100 / 7}%`);
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

function createActions() {
  for (const [id, action] of Object.entries(FIELD_ACTIONS)) {
    const node = document.createElement('button');
    node.type = 'button';
    node.className = 'action-card';
    node.dataset.action = id;
    node.setAttribute('aria-keyshortcuts', action.key);
    const meta = document.createElement('span');
    meta.className = 'action-meta';
    meta.setAttribute('aria-hidden', 'true');
    const key = document.createElement('kbd');
    key.textContent = action.key;
    const details = document.createElement('span');
    details.textContent = actionNotes[id];
    meta.append(key, details);
    const label = document.createElement('b');
    label.textContent = action.name;
    node.append(meta, label);
    node.addEventListener('click', () => chooseAction(id));
    node.addEventListener('pointerenter', () => {
      if (world.mode === 'battle' && !selecting) setHint(actionBlock(world.battle, id) || actionHints[id]);
    });
    buttons[id] = node;
    byId('field-action-grid').append(node);
  }
}

function place(node, cell, size) {
  const { col, row } = toPoint(cell);
  node.style.transform = `translate3d(${col * size}px,${row * size}px,0)`;
}

function aimCamera() {
  const size = Number.parseFloat(getComputedStyle(field).getPropertyValue('--tile'));
  if (!size || !field.clientWidth) return;
  const { cell } = world.player;
  const { col, row } = toPoint(cell);
  const offset = (point, screen, length) => Math.min(Math.max(0, length * size - screen), Math.max(0, (point + 0.5) * size - screen / 2));
  const x = offset(col, field.clientWidth, MAP.columns);
  const lookTowardRampart = 1.65 * Math.min(1, Math.max(0, (19 - col) / 6));
  const y = offset(row - lookTowardRampart, field.clientHeight, MAP.rows);
  plane.style.transform = `translate3d(${-x}px,${-y}px,0)`;
  place(hero, cell, size);
  place(byId('gate-marker'), GATE, size);
  place(byId('end-marker'), CONTINUE, size);
  if (!beast.hidden) {
    place(beast, world.battle.rival.cell, size);
    const face = toPoint(world.battle.rival.cell).col >= col ? 1 : -1;
    hero.style.setProperty('--face', face);
    beast.style.setProperty('--face', -face);
  }
  if (selecting) place(cursor, selectedCell, size);
}

function meter(name, current, max) {
  byId(name).textContent = `${current} / ${max}`;
  const progress = byId(`${name}-meter`);
  progress.max = max;
  progress.value = current;
}

function renderObjective() {
  const inBattle = world.mode === 'battle';
  const pastGate = toPoint(world.player.cell).col >= 14;
  let title = 'Ra cổng đông';
  let detail = 'Thử lên sàn lũy bằng cầu thang hoặc đi qua cổng đông để tới đường rừng.';
  let button = 'Đi tới cổng';
  if (world.mode === 'defeat') {
    title = 'Thử lại cuộc săn';
    detail = world.notice;
  } else if (inBattle) {
    title = 'Hạ sói rừng';
    detail = 'Chọn đường tránh vùng đỏ hoặc dùng Thủ thế. Đánh tay không để hồi chân nguyên.';
  } else if (world.reached) {
    title = 'Đã tới lối mòn';
    detail = world.notice;
  } else if (world.cleared) {
    title = 'Đi tiếp về phía đông';
    detail = 'Sói rừng đã gục. Bạn có thể tự do đi lại qua bãi săn.';
    button = 'Đi tới lối mòn';
  } else if (pastGate) {
    title = 'Tới bãi săn';
    detail = 'Theo lối đất giữa rừng. Chạm trán thú sẽ bắt đầu lượt ngay trên bản đồ.';
    button = 'Theo đường rừng';
  }
  byId('objective-title').textContent = title;
  byId('objective-detail').textContent = detail;
  guide.textContent = button;
  guide.hidden = world.mode !== 'explore' || world.reached;
}

function renderBattle() {
  const inBattle = world.mode === 'battle';
  const defeat = world.mode === 'defeat';
  const { battle } = world;
  const intent = battle?.intent;
  byId('wolf-status').hidden = !inBattle;
  byId('wolf-intent').hidden = !inBattle;
  byId('field-actions').hidden = !inBattle;
  byId('defeat').hidden = !defeat;
  byId('encounter-log').hidden = !battle;
  beast.hidden = !inBattle && !defeat;

  if (inBattle) {
    meter('wolf-hp', battle.rival.hp, battle.rival.maxHp);
    byId('wolf-intent-name').textContent = intent.name;
    byId('wolf-intent-detail').textContent = intent.cells.length
      ? `Sói gây ${intent.damage} sát thương ở vùng đỏ trong lượt này.`
      : 'Sói sẽ tiến về phía bạn tối đa hai ô.';
    for (const [id, node] of Object.entries(buttons)) {
      const reason = actionBlock(battle, id);
      node.setAttribute('aria-disabled', String(Boolean(reason)));
      node.title = reason || actionHints[id];
    }
  }
  buttons.move.setAttribute('aria-pressed', String(selecting));

  const log = byId('world-log');
  log.replaceChildren(...(battle?.report.slice(0, 4) ?? []).map(({ text, tone }) => {
    const item = document.createElement('li');
    item.className = tone;
    item.textContent = text;
    return item;
  }));
  field.classList.toggle('in-battle', inBattle);
  for (const cell of markedThreats) tiles[cell].classList.remove('threat');
  for (const cell of markedMoves) tiles[cell].classList.remove('reachable');
  markedThreats = inBattle ? intent.cells : [];
  markedMoves = selecting ? moveTargets(battle) : [];
  for (const cell of markedThreats) tiles[cell].classList.add('threat');
  for (const cell of markedMoves) tiles[cell].classList.add('reachable');
  cursor.hidden = !selecting;
}

function render() {
  byId('location').textContent = locationOf(world.player.cell);
  const terrain = TERRAIN[world.player.cell].rampart;
  const level = terrain?.stair ? ' · Cầu thang' : terrain?.elevation ? ' · Sàn lũy' : '';
  byId('coordinates').textContent = `Ô ${coordinate(world.player.cell, MAP.columns)}${level}`;
  byId('mode').textContent = world.mode === 'battle'
    ? `Giao chiến · Lượt ${world.battle.turn}` : world.mode === 'defeat' ? 'Thất bại' : 'Khám phá';
  meter('world-hp', world.player.hp, world.player.maxHp);
  meter('world-qi', world.player.qi, world.player.maxQi);
  byId('end-marker').hidden = !world.cleared;
  byId('gate-marker').hidden = toPoint(world.player.cell).col >= 22;
  renderObjective();
  renderBattle();
  aimCamera();
}

function stopWalk() {
  clearTimeout(stepTimer);
  stepTimer = undefined;
  route = [];
}

function step(target) {
  const previous = world;
  world = walk(world, target);
  if (world === previous) return false;
  const delta = toPoint(world.player.cell).col - toPoint(previous.player.cell).col;
  if (delta) hero.style.setProperty('--face', Math.sign(delta));
  const onStairs = Boolean(TERRAIN[target].rampart?.stair || TERRAIN[previous.player.cell].rampart?.stair);
  const duration = onStairs ? 215 : 165;
  field.style.setProperty('--step-time', duration + 'ms');
  nextStepAt = performance.now() + duration;
  heroMotion.travel(onStairs, duration);
  field.classList.add('walking');
  render();
  if (world.mode === 'battle') {
    stopWalk();
    byId('field-hint').textContent = 'Ô đỏ báo vùng sói sẽ đánh. Chọn Di chuyển để xem các ô có thể đến.';
    setHint('Sói xuất hiện. Né vùng đỏ hoặc chọn một hành động.', true);
    if (document.activeElement === guide) field.focus({ preventScroll: true });
  } else if (world.reached && !previous.reached) {
    announce(world.notice);
  } else if (locationOf(previous.player.cell) !== locationOf(world.player.cell)) {
    announce(`Đã đến ${locationOf(world.player.cell)}.`);
  }
  return true;
}

function followRoute() {
  if (!route.length) return;
  const target = route.shift();
  if (step(target) && route.length) stepTimer = setTimeout(followRoute, motion.matches ? 45 : Math.max(0, nextStepAt - performance.now()));
}

function go(target) {
  stopWalk();
  if (target === world.player.cell) return;
  route = findPath(world, target);
  if (route.length) {
    byId('field-hint').textContent = 'Bấm ô để đi, hoặc dùng WASD và phím mũi tên.';
    followRoute();
  } else {
    setHint('Ô này bị chắn hoặc chưa có đường tới.', true);
  }
}

function resolve(action, cell) {
  const { state, error } = fight(world, action, cell);
  if (error) return setHint(error, true);
  world = state;
  selecting = false;
  field.style.removeProperty('--step-time');
  render();
  const event = world.battle.events.find(entry => entry.actor === 'player');
  if (event) {
    const facing = Number(hero.style.getPropertyValue('--face')) || 1;
    heroMotion.playBattle(event, facing, MAP.columns, 170);
  }
  if (world.mode === 'battle') {
    setHint('Chọn hành động tiếp theo theo ý định của sói.');
    announce(world.battle.report.slice(0, 2).map(entry => entry.text).join(' '));
  } else {
    byId('field-hint').textContent = world.notice;
    announce(world.notice);
    if (world.mode === 'defeat') byId('retry-encounter').focus();
    else field.focus({ preventScroll: true });
  }
}

function chooseAction(action) {
  const error = actionBlock(world.battle, action);
  if (error) return setHint(error, true);
  if (action !== 'move') return resolve(action);
  selecting = !selecting;
  if (selecting) {
    const targets = moveTargets(world.battle);
    selectedCell = targets.find(cell => !world.battle.intent.cells.includes(cell)) ?? targets[0];
    field.focus({ preventScroll: true });
  }
  render();
  setHint(selecting ? 'Chọn ô sáng; ô có vạch đỏ vẫn nguy hiểm. Dùng Enter để chốt ô đang chọn.' : 'Chọn hành động theo ý định của sói.', true);
}

function reset() {
  stopWalk();
  world = newTrip();
  nextStepAt = 0;
  field.style.removeProperty('--step-time');
  surfaceTexture();
  selecting = false;
  field.classList.remove('walking');
  hero.style.removeProperty('--face');
  heroMotion.stand();
  render();
  byId('field-hint').textContent = 'Bấm ô để đi, hoặc dùng WASD và phím mũi tên.';
  field.focus({ preventScroll: true });
  announce('Bạn đang ở Cổ Nguyệt Sơn Trại.');
}

createMap();
createActions();
render();
field.classList.add('ready');
new ResizeObserver(aimCamera).observe(field);

map.addEventListener('click', (event) => {
  const tile = event.target.closest('button[data-cell]');
  if (!tile) return;
  const cell = Number(tile.dataset.cell);
  field.focus({ preventScroll: true });
  if (world.mode === 'explore') go(cell);
  if (world.mode === 'battle' && selecting) resolve('move', cell);
  else if (world.mode === 'battle') setHint('Chọn Di chuyển để đổi vị trí trong lượt.', true);
});

document.addEventListener('keydown', (event) => {
  if (event.ctrlKey || event.metaKey || event.altKey || world.mode === 'defeat') return;
  const key = event.key.toLowerCase();
  if (Object.hasOwn(keys, key)) {
    if (world.mode === 'battle' && !selecting) return;
    event.preventDefault();
    if (world.mode === 'explore') {
      if (event.repeat && performance.now() < nextStepAt) return;
      stopWalk();
      step(world.player.cell + keys[key]);
    } else {
      const candidate = selectedCell + keys[key];
      if (neighbors(selectedCell, MAP).includes(candidate) && insideHunt(candidate)) {
        selectedCell = candidate;
        aimCamera();
        announce(`Chọn ô ${coordinate(candidate, MAP.columns)}.`);
      }
    }
    return;
  }
  if (world.mode !== 'battle' || event.repeat) return;
  if (selecting && (key === 'enter' || key === 'escape')) {
    event.preventDefault();
    if (key === 'enter') resolve('move', selectedCell);
    else chooseAction('move');
  } else {
    const action = Object.entries(FIELD_ACTIONS).find(([, info]) => info.key === key);
    if (action) {
      event.preventDefault();
      chooseAction(action[0]);
    }
  }
});

guide.addEventListener('click', () => {
  field.focus({ preventScroll: true });
  go(world.cleared ? CONTINUE : toPoint(world.player.cell).col < 14 ? GATE : TRAIL_ENTRY);
});
byId('reset-trip').addEventListener('click', reset);
byId('retry-encounter').addEventListener('click', () => {
  world = retryEncounter(world);
  selecting = false;
  heroMotion.stand();
  render();
  byId('field-hint').textContent = 'Ô đỏ báo vùng sói sẽ đánh.';
  setHint(world.notice, true);
  field.focus({ preventScroll: true });
});
