import { actionBlock, BOARD, coordinate, moveTargets } from './combat.mjs';
import { createHeroMotion } from './hero-motion.mjs';
import { createWolfMotion } from './wolf-motion.mjs';
import { advanceRun, FLOORS, REWARDS } from './roguelike.mjs';
import { readRun, runUrl, writeRun } from './roguelike-storage.mjs';

const byId = id => document.getElementById(id);
const shell = byId('run-shell');
const board = byId('board');
const stage = byId('stage');
const actionBar = byId('actions');
const actor = byId('hero');
const rival = byId('wolf');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const heroSprite = actor.querySelector('.sprite');
let run = readRun();
let selected = false;
let busy = false;
let activeCell = 17;
let message = '';
let heroMotion, wolfMotion;
const cells = [];
const buttons = new Map();

function createBoard() {
  for (let index = 0; index < BOARD.columns * BOARD.rows; index++) {
    const cell = document.createElement('button');
    cell.type = 'button';
    cell.className = 'run-cell';
    cell.dataset.cell = index;
    cell.tabIndex = -1;
    cell.style.setProperty('--tile-x', `${((index * 3 + Math.floor(index / 8) * 5) % 8) * 100 / 7}%`);
    const rock = document.createElement('i');
    rock.className = 'rock-art';
    cell.append(rock);
    cell.addEventListener('focus', () => { activeCell = index; });
    cell.addEventListener('click', () => {
      if (run.phase !== 'battle' || busy) return;
      if (selected) request('move', index);
      else show('Chọn Di chuyển để xem các ô có thể tới.');
    });
    cells.push(cell);
    board.append(cell);
  }
  for (const [id, ability] of Object.entries(run.battle.actions)) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'action-card';
    button.dataset.action = id;
    button.setAttribute('aria-keyshortcuts', ability.key);
    const meta = document.createElement('span');
    meta.className = 'action-meta';
    const key = document.createElement('kbd');
    key.textContent = ability.key;
    const detail = document.createElement('span');
    meta.append(key, detail);
    const name = document.createElement('b');
    name.textContent = ability.name;
    button.append(meta, name);
    button.addEventListener('click', () => request(id));
    buttons.set(id, { button, detail, key: ability.key });
    actionBar.append(button);
  }
}

function place(node, cell, face) {
  node.style.setProperty('--col', cell % BOARD.columns);
  node.style.setProperty('--row', Math.floor(cell / BOARD.columns));
  node.style.setProperty('--face', face);
}

function meter(id, current, max) {
  const node = byId(id);
  node.max = max;
  node.value = current;
  byId(id + '-text').textContent = `${current} / ${max}`;
}

function show(text) {
  message = text;
  byId('hint').textContent = text;
}

function renderRoute() {
  byId('route').replaceChildren(...FLOORS.map((floor, index) => {
    const node = document.createElement('li');
    const icon = document.createElement('i');
    icon.setAttribute('aria-hidden', 'true');
    icon.textContent = index < run.floor || run.phase === 'victory' ? '✓' : '◆';
    if (index === run.floor) node.setAttribute('aria-current', 'step');
    node.dataset.cleared = String(index < run.floor || run.phase === 'victory');
    node.append(icon, floor.name);
    return node;
  }));
}

function renderBattle() {
  const { battle, phase, floor } = run;
  const { player, rival: wolf, arena, intent } = battle;
  const active = phase === 'battle';
  const reachable = active && selected && !busy ? new Set(moveTargets(battle)) : new Set();
  const danger = new Set(intent?.cells);
  const face = player.cell % BOARD.columns > wolf.cell % BOARD.columns ? -1 : 1;
  place(actor, player.cell, face);
  place(rival, wolf.cell, -face);
  rival.dataset.floor = floor;
  rival.dataset.down = String(wolf.hp <= 0);
  actor.dataset.down = String(player.hp <= 0);
  for (const [index, cell] of cells.entries()) {
    const isRock = arena.rocks.has(index);
    const isDanger = danger.has(index);
    const canMove = reachable.has(index);
    cell.classList.toggle('rock', isRock);
    cell.classList.toggle('threat', isDanger);
    cell.classList.toggle('reachable', canMove);
    cell.tabIndex = active && selected && !busy && index === activeCell ? 0 : -1;
    const marks = [isRock && 'đá chặn', isDanger && 'vùng địch đánh', canMove && 'có thể tới',
      index === player.cell && 'cổ sư', index === wolf.cell && 'đối thủ'].filter(Boolean);
    cell.setAttribute('aria-label', [coordinate(index), ...marks].join(', '));
  }
  for (const [id, { button, detail }] of buttons) {
    const ability = battle.actions[id];
    const reason = actionBlock(battle, id);
    button.setAttribute('aria-disabled', String(Boolean(reason || busy)));
    if (id === 'move') button.setAttribute('aria-pressed', String(selected));
    button.title = reason;
    detail.textContent = id === 'move' ? `${ability.range} ô` : id === 'moon' ? `−${ability.cost} chân nguyên` : '+1 chân nguyên';
  }
  byId('turn').textContent = active ? `Lượt ${battle.turn}` : phase === 'death' ? 'Đã gục' : 'Đã thắng';
  meter('hp', player.hp, player.maxHp);
  meter('qi', player.qi, player.maxQi);
  meter('rival-hp', wolf.hp, wolf.maxHp);
  byId('rival-name').textContent = FLOORS[floor].enemy;
  byId('intent').textContent = intent?.name ?? (phase === 'death' ? 'Trận đã kết thúc' : 'Đối thủ đã gục');
  byId('intent-copy').textContent = intent?.cells.length
    ? `Gây ${intent.damage} sát thương trong vùng đỏ sau hành động của bạn.`
    : intent ? 'Sẽ tiến lại gần sau hành động của bạn.' : '';
  byId('log').replaceChildren(...battle.report.slice(0, 5).map(entry => {
    const li = document.createElement('li');
    li.textContent = entry.text;
    return li;
  }));
  byId('commands').hidden = !active;
  byId('outcome').hidden = active;
  show(message);
}

function renderOutcome(saved) {
  const title = byId('outcome-title');
  const copy = byId('outcome-copy');
  const rewards = byId('rewards');
  rewards.replaceChildren();
  if (run.phase === 'reward') {
    title.textContent = 'Chọn chiến lợi phẩm';
    copy.textContent = `Chọn một phần thưởng rồi tiến vào ${FLOORS[run.floor + 1].name}.`;
    for (const [id, reward] of Object.entries(REWARDS)) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'action-card';
      button.dataset.reward = id;
      const name = document.createElement('b');
      name.textContent = reward.name;
      const desc = document.createElement('small');
      desc.textContent = reward.description;
      button.append(name, desc);
      button.addEventListener('click', () => request(id));
      rewards.append(button);
    }
  } else {
    const died = run.phase === 'death';
    title.textContent = died ? 'Bạn đã chết' : 'Vượt qua Thanh Mao Sơn';
    copy.textContent = died
      ? 'Hồi sinh sẽ bắt đầu từ màn đầu. Tư chất cũ cho phép bỏ qua Khai Khiếu.'
      : 'Cuồng Điện Lang đã gục. Bạn đã vượt qua cả ba màn.';
    const next = document.createElement('a');
    next.className = 'primary nav-link';
    next.href = runUrl('index.html', run, saved);
    next.textContent = died ? 'Hồi sinh' : 'Lượt chơi mới';
    rewards.append(next);
  }
  title.focus({ preventScroll: true });
}

function moonEffect(from, to) {
  const blade = document.createElement('i');
  blade.className = 'run-moon';
  const xy = cell => [
    (cell % BOARD.columns + .5) * stage.clientWidth / BOARD.columns,
    (Math.floor(cell / BOARD.columns) + .5) * stage.clientHeight / BOARD.rows,
  ];
  const [x, y] = xy(from);
  const [tx, ty] = xy(to);
  const dx = tx - x;
  const dy = ty - y;
  stage.append(blade);
  blade.style.left = `${x - blade.offsetWidth / 2}px`;
  blade.style.top = `${y - blade.offsetHeight / 2}px`;
  const rotation = Math.atan2(dy, dx) + Math.PI;
  const motion = blade.animate(Array.from({ length: 8 }, (_, i) => ({
    translate: `${dx * i / 7}px ${dy * i / 7}px`, rotate: `${rotation}rad`,
    backgroundPosition: `${i * 100 / 7}% 0%`, easing: 'steps(1)',
  })), { delay: 280, duration: 240, fill: 'none' });
  blade.style.opacity = '0';
  // Opacity is animated only while the projectile is in flight.
  blade.animate([{ opacity: 1 }, { opacity: 1 }], { delay: 280, duration: 240 });
  motion.onfinish = () => blade.remove();
}

function request(id, target) {
  if (busy || !['battle', 'reward'].includes(run.phase)) return;
  if (run.phase === 'battle' && id === 'move' && target === undefined) {
    const reason = actionBlock(run.battle, id);
    if (reason) return show(reason);
    selected = !selected;
    activeCell = run.battle.player.cell;
    show(selected ? 'Chọn ô viền xanh. Tránh vùng đỏ nếu có thể.' : 'Chọn một hành động.');
    renderBattle();
    if (selected) cells[activeCell].focus({ preventScroll: true });
    return;
  }
  const next = advanceRun(run, id, target);
  if (next.error) return show(next.error);
  const previous = run;
  const saved = writeRun(next.run);
  byId('home').href = runUrl('index.html', next.run, saved);
  if (location.hash || !saved) history.replaceState(null, '', runUrl('run.html', next.run, saved));
  if (previous.phase === 'reward') {
    run = next.run;
    enterFloor();
    byId('floor').focus();
    return;
  }
  const { events } = next.run.battle;
  const playerEvent = events.find(event => event.actor === 'player');
  const wolfEvent = events.find(event => event.actor === 'rival');
  const face = Number(actor.style.getPropertyValue('--face'));
  selected = false;
  busy = true;
  renderBattle();
  let delay = 220;
  if (!reduced.matches && id === 'moon') {
    heroMotion.cast();
    moonEffect(playerEvent.from, playerEvent.to);
    delay = 520;
  } else if (!reduced.matches && id === 'move') {
    heroMotion.travel('walk', 265);
    place(actor, next.run.battle.player.cell, face);
    delay = 265;
  } else if (!reduced.matches && id === 'guard') {
    heroMotion.playBattle(playerEvent, face, BOARD.columns, delay);
  } else if (!reduced.matches && id === 'strike') {
    heroSprite.animate([{ translate: '0' }, { translate: `${face * 20}% 0` }, { translate: '0' }], { duration: delay });
  }
  setTimeout(() => {
    run = next.run;
    busy = false;
    const report = run.battle.report.filter(entry => entry.turn === previous.battle.turn);
    show(report.map(entry => entry.text).join(' '));
    renderBattle();
    if (wolfEvent?.damage) heroMotion.hit();
    if (run.floor < 2) {
      if (run.battle.rival.hp === 0) wolfMotion.fall();
      else if (wolfEvent?.type === 'move') wolfMotion.play('run', { duration: 250 });
      else if (wolfEvent) wolfMotion.play(wolfEvent.type === 'heavy' ? 'pounce' : 'bite', { direction: [-face, 0] });
      else if (playerEvent.damage) wolfMotion.play('hit', { direction: [face, 0] });
    } else if (wolfEvent && wolfEvent.type !== 'move' && !reduced.matches) {
      rival.querySelector('.wolf-art').animate([{ translate: '0' }, { translate: `${-face * 22}% -8%` }, { translate: '0' }],
        { duration: 360, easing: 'ease-out' });
    }
    if (run.phase !== 'battle') renderOutcome(saved);
    else if (document.activeElement === document.body || board.contains(document.activeElement)) buttons.get(id).button.focus({ preventScroll: true });
  }, reduced.matches ? 0 : delay);
}

function enterFloor() {
  selected = false;
  activeCell = run.battle.player.cell;
  heroMotion.stand();
  wolfMotion.stop();
  if (run.floor < 2 && run.battle.rival.hp > 0) wolfMotion.idle();
  if (run.floor < 2 && run.battle.rival.hp === 0) wolfMotion.fall();
  const floor = FLOORS[run.floor];
  stage.dataset.theme = floor.theme;
  byId('floor').textContent = floor.name;
  show('Mỗi hành động tốn một lượt. Quan sát vùng đỏ trước khi ra tay.');
  renderRoute();
  renderBattle();
  if (run.phase !== 'battle') renderOutcome(!location.hash);
}

window.addEventListener('pageshow', event => {
  if (event.persisted) location.reload();
});

if (!run) {
  location.replace('index.html');
} else {
  const { hero, grade, seaPct } = run.profile;
  const isAoReu = hero === 'ao-reu';
  actor.classList.toggle('ao-reu', isAoReu);
  byId('hero-portrait').src = `assets/${hero}-selection.png`;
  byId('hero-name').textContent = isAoReu ? 'Cổ sư Áo rêu' : 'Cổ sư Huyền bào';
  byId('grade').textContent = `${grade} · Nguyên Hải ${seaPct}%`;
  byId('home').href = runUrl('index.html', run, !location.hash);
  heroMotion = createHeroMotion(heroSprite, reduced, isAoReu);
  wolfMotion = createWolfMotion(rival, reduced);
  createBoard();
  shell.hidden = false;
  enterFloor();
  document.addEventListener('keydown', event => {
    if (event.repeat || event.ctrlKey || event.altKey || event.metaKey || busy || run.phase !== 'battle') return;
    for (const [id, entry] of buttons) {
      if (event.key !== entry.key) continue;
      event.preventDefault();
      request(id);
      return;
    }
    if (!selected || !board.contains(document.activeElement)) return;
    const [x, y] = [activeCell % BOARD.columns, Math.floor(activeCell / BOARD.columns)];
    const delta = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[event.key];
    if (!delta) return;
    event.preventDefault();
    const [col, row] = [x + delta[0], y + delta[1]];
    if (col < 0 || col >= BOARD.columns || row < 0 || row >= BOARD.rows) return;
    cells[activeCell].tabIndex = -1;
    const cell = cells[row * BOARD.columns + col];
    cell.tabIndex = 0;
    cell.focus({ preventScroll: true });
  });
}
