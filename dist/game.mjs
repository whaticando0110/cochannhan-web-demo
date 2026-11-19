import { ACTIONS, BOARD, ROCKS, actionBlock, coordinate, createBattle, moveTargets, playTurn } from './combat.mjs';
import { createHeroMotion } from './hero-motion.mjs';

const byId = (id) => document.getElementById(id);
const grid = byId('board');
const effects = byId('effects');
const help = byId('help');
const actionGrid = byId('action-grid');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const actors = { player: byId('player-actor'), rival: byId('rival-actor') };
const playerSprite = actors.player.querySelector('.sprite');
const heroMotion = createHeroMotion(playerSprite, reducedMotion);

const summaries = {
  move: 'Tối đa 2 ô',
  strike: '+1 chân nguyên',
  moon: '−2 chân nguyên',
  guard: '+1 chân nguyên',
  heal: '−2 chân nguyên',
};
const tools = {
  move: 'Đi tối đa 2 ô. Đá và đối thủ chặn đường.',
  strike: 'Gây 14 sát thương ở ô kế bên và hồi 1 chân nguyên.',
  moon: 'Gây 26 sát thương ở tầm 4 ô. Tốn 2 chân nguyên.',
  guard: 'Giảm 70% sát thương trong lượt và hồi 1 chân nguyên.',
  heal: 'Hồi tối đa 20 sinh lực. Tốn 2 chân nguyên.',
};
let battle = createBattle();
let selectingMove = false;
let activeCell = battle.player.cell;
const cells = [];
const buttons = {};

function addCoordinates() {
  const add = (container, label) => {
    const span = document.createElement('span');
    span.textContent = label;
    container.append(span);
  };
  for (let column = 0; column < BOARD.columns; column++) add(byId('column-labels'), coordinate(column)[0]);
  for (let row = 0; row < BOARD.rows; row++) add(byId('row-labels'), row + 1);
}

function announce(text) {
  byId('announcement').textContent = text;
}

function showHint(text, speak = false) {
  byId('action-hint').textContent = text;
  if (speak) announce(text);
}

function focusCell(index, focus = true) {
  cells[activeCell].tabIndex = -1;
  activeCell = index;
  cells[activeCell].tabIndex = 0;
  if (focus) cells[activeCell].focus({ preventScroll: true });
}

function createControls() {
  for (let index = 0; index < BOARD.columns * BOARD.rows; index++) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'cell';
    button.dataset.cell = index;
    button.tabIndex = index === activeCell ? 0 : -1;
    button.addEventListener('focus', () => focusCell(index, false));
    button.addEventListener('click', () => {
      if (battle.result) return;
      if (!selectingMove) {
        showHint('Chọn Di chuyển hoặc nhấn 1 để đánh dấu các ô bạn có thể đến.', true);
        return;
      }
      applyAction('move', index);
    });
    cells.push(button);
    grid.append(button);
  }

  for (const [id, action] of Object.entries(ACTIONS)) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'action-card';
    button.dataset.action = id;
    button.setAttribute('aria-keyshortcuts', action.key);
    if (id === 'move') button.setAttribute('aria-pressed', 'false');
    const meta = document.createElement('span');
    meta.className = 'action-meta';
    meta.setAttribute('aria-hidden', 'true');
    const key = document.createElement('kbd');
    key.textContent = action.key;
    const summary = document.createElement('span');
    summary.textContent = summaries[id];
    meta.append(key, summary);
    const name = document.createElement('b');
    name.textContent = action.name;
    button.append(meta, name);
    button.addEventListener('click', () => chooseAction(id));
    button.addEventListener('pointerenter', () => {
      if (!selectingMove && !battle.result) showHint(actionBlock(battle, id) || tools[id]);
    });
    button.addEventListener('focus', () => {
      if (!selectingMove && !battle.result) showHint(actionBlock(battle, id) || tools[id]);
    });
    buttons[id] = button;
    actionGrid.append(button);
  }
}

function setVitals(meter, readout, { hp, maxHp }) {
  byId(readout).textContent = `${hp} / ${maxHp}`;
  const progress = byId(meter);
  progress.max = maxHp;
  progress.value = hp;
}

function renderIntent() {
  const intent = battle.intent;
  const message = {
    heavy: `Gây ${intent?.damage} sát thương trong vùng đỏ. Rời vùng đó hoặc dùng Bạch Ngọc Cổ để giảm sát thương.`,
    strike: `Đánh vào ô đang đánh dấu, gây ${intent?.damage} sát thương. Bạn có thể né hoặc phòng thủ.`,
    advance: 'Đối thủ sẽ áp sát tối đa 2 ô và chưa gây sát thương trong lượt này.',
  };
  byId('intent-name').textContent = intent?.name ?? 'Trận đấu kết thúc';
  byId('intent-description').textContent = intent ? message[intent.type] : 'Xem diễn biến hoặc bắt đầu một trận mới.';
}

function facing() {
  return battle.rival.cell % BOARD.columns >= battle.player.cell % BOARD.columns ? 1 : -1;
}

function placeActor(node, cell) {
  node.style.left = `${(cell % BOARD.columns) * 100 / BOARD.columns}%`;
  node.style.top = `${Math.floor(cell / BOARD.columns) * 100 / BOARD.rows}%`;
}

function renderField() {
  const threats = new Set(battle.intent?.cells);
  const reachable = selectingMove ? new Set(moveTargets(battle)) : new Set();
  for (let index = 0; index < cells.length; index++) {
    const cell = cells[index];
    const rock = ROCKS.includes(index);
    const danger = threats.has(index);
    const destination = reachable.has(index);
    cell.classList.toggle('rock', rock);
    cell.classList.toggle('threat', danger);
    cell.classList.toggle('reachable', destination);
    const parts = [coordinate(index)];
    if (rock) parts.push('đá chắn');
    if (index === battle.player.cell) parts.push('Phương Nguyên');
    if (index === battle.rival.cell) parts.push('đối thủ');
    if (danger) parts.push('vùng nguy hiểm');
    if (destination) parts.push('có thể đến');
    cell.setAttribute('aria-label', parts.join(', '));
  }
  placeActor(actors.player, battle.player.cell);
  placeActor(actors.rival, battle.rival.cell);
  playerSprite.style.transform = `translateX(-50%) scaleX(${facing()})`;
  actors.rival.querySelector('.rival-sprite').style.transform = `translateX(-50%) scaleX(${-facing()})`;
}

function renderLog() {
  const fragment = document.createDocumentFragment();
  for (const entry of battle.report) {
    const item = document.createElement('li');
    item.className = entry.tone;
    if (entry.turn) {
      const number = document.createElement('span');
      number.textContent = `L${String(entry.turn).padStart(2, '0')}`;
      number.setAttribute('aria-label', `Lượt ${entry.turn}`);
      item.append(number);
    }
    item.append(entry.text);
    fragment.append(item);
  }
  byId('log').replaceChildren(fragment);
}

function render() {
  byId('turn').textContent = `Lượt ${String(battle.turn).padStart(2, '0')}`;
  setVitals('player-meter', 'player-hp', battle.player);
  setVitals('rival-meter', 'rival-hp', battle.rival);
  byId('player-qi').textContent = `${battle.player.qi} / ${battle.player.maxQi}`;
  byId('qi-pips').replaceChildren(...Array.from({ length: battle.player.maxQi }, (_, index) => {
    const pip = document.createElement('i');
    pip.classList.toggle('filled', index < battle.player.qi);
    return pip;
  }));
  for (const [id, button] of Object.entries(buttons)) {
    const reason = actionBlock(battle, id);
    button.setAttribute('aria-disabled', String(Boolean(reason)));
    button.title = reason || tools[id];
  }
  buttons.move.setAttribute('aria-pressed', String(selectingMove));
  byId('result').hidden = !battle.result;
  grid.inert = Boolean(battle.result);
  renderIntent();
  renderField();
  renderLog();
}

function offset(from, to) {
  const box = grid.getBoundingClientRect();
  return {
    x: (to % BOARD.columns - from % BOARD.columns) * box.width / BOARD.columns,
    y: (Math.floor(to / BOARD.columns) - Math.floor(from / BOARD.columns)) * box.height / BOARD.rows,
  };
}

function effect(cell, type, content = '') {
  const node = document.createElement('span');
  node.className = `effect fx-${type}`;
  node.textContent = content;
  node.style.left = `${((cell % BOARD.columns) + 0.5) * 100 / BOARD.columns}%`;
  node.style.top = `${(Math.floor(cell / BOARD.columns) + 0.5) * 100 / BOARD.rows}%`;
  effects.append(node);
  return node;
}

function transient(node, frames, options) {
  const animation = node.animate(frames, options);
  animation.onfinish = () => node.remove();
}

function animateTurn(events) {
  effects.replaceChildren();
  for (const actor of Object.values(actors)) {
    actor.getAnimations().forEach(animation => animation.cancel());
  }
  if (reducedMotion.matches) return;

  for (const event of events) {
    const actor = actors[event.actor];
    if (event.actor === 'player') {
      heroMotion.playBattle(event, facing(), BOARD.columns, 300);
    }
    if (event.type === 'move') {
      const start = offset(event.to, event.from);
      actor.animate([{ transform: `translate(${start.x}px, ${start.y}px)` }, { transform: 'translate(0,0)' }],
        { duration: 300, easing: 'ease-out' });
    }
    if (event.type === 'moon') {
      const end = offset(event.from, event.to);
      const angle = Math.atan2(end.y, end.x);
      transient(effect(event.from, 'moon'), [
        { transform: `rotate(${angle}rad)` },
        { transform: `translate(${end.x}px, ${end.y}px) rotate(${angle}rad)` },
      ], { duration: 240, delay: 90, fill: 'backwards' });
    }
    if (event.type === 'guard') {
      transient(effect(event.to, 'ring'), [{ opacity: 1, scale: 0.7 }, { opacity: 0, scale: 1.35 }], { duration: 500 });
    }
    if (event.damage || event.heal) {
      const gain = Boolean(event.heal);
      transient(effect(event.to, gain ? 'heal' : 'damage', gain ? `+${event.heal}` : `−${event.damage}`), [
        { opacity: 0, transform: 'translateY(0)' },
        { opacity: 1, offset: 0.2 },
        { opacity: 1, offset: 0.6 },
        { opacity: 0, transform: 'translateY(-34px)' },
      ], { duration: 600, delay: gain ? 120 : event.actor === 'rival' ? 310 : 240 });
    }
  }
}

function defaultHint() {
  return battle.intent?.cells.length
    ? 'Chọn Di chuyển để né vùng đỏ, hoặc dùng Bạch Ngọc Cổ để giảm sát thương.'
    : 'Canh tầm đánh hoặc hồi chân nguyên trước lượt tiếp theo.';
}

function applyAction(id, cell) {
  const { state, error } = playTurn(battle, id, cell);
  if (error) {
    showHint(error, true);
    return;
  }
  battle = state;
  selectingMove = false;
  render();
  animateTurn(battle.events);
  if (battle.result) {
    const won = battle.result === 'win';
    byId('result-title').textContent = won ? 'Chiến thắng' : 'Thất bại';
    byId('result-description').textContent = won
      ? `Hạ đối thủ sau ${battle.turn} lượt, còn ${battle.player.hp} sinh lực.`
      : `Trụ được ${battle.turn} lượt. Đối thủ còn ${battle.rival.hp} sinh lực.`;
    showHint('Trận đấu đã kết thúc.');
    byId('replay-button').focus();
  } else {
    showHint(defaultHint());
  }
  const current = battle.report.filter(entry => entry.turn === (battle.result ? battle.turn : battle.turn - 1));
  announce(current.map(entry => entry.text).join(' '));
}

function chooseAction(id) {
  const reason = actionBlock(battle, id);
  if (reason) {
    showHint(reason, true);
    return;
  }
  if (id !== 'move') {
    applyAction(id);
    return;
  }
  selectingMove = !selectingMove;
  buttons.move.setAttribute('aria-pressed', String(selectingMove));
  renderField();
  showHint(selectingMove ? 'Chọn một ô sáng. Ô có vạch đỏ vẫn nằm trong vùng đối thủ sẽ đánh.' : defaultHint(), true);
  if (selectingMove) {
    const available = moveTargets(battle);
    const threatened = battle.intent?.cells ?? [];
    focusCell(available.find(cell => !threatened.includes(cell)) ?? available[0]);
  }
}

function restart() {
  battle = createBattle();
  selectingMove = false;
  focusCell(battle.player.cell, false);
  render();
  animateTurn([]);
  heroMotion.stand();
  showHint(defaultHint());
  announce('Trận mới. Đối thủ đã nhắm vùng đỏ.');
  buttons.move.focus({ preventScroll: true });
}

addCoordinates();
createControls();
render();
showHint(defaultHint());

grid.addEventListener('keydown', (event) => {
  const moves = { ArrowUp: -BOARD.columns, ArrowDown: BOARD.columns, ArrowLeft: -1, ArrowRight: 1 };
  if (!Object.hasOwn(moves, event.key)) return;
  event.preventDefault();
  const next = activeCell + moves[event.key];
  if (cells[next] && (Math.abs(moves[event.key]) !== 1 || Math.floor(next / BOARD.columns) === Math.floor(activeCell / BOARD.columns))) {
    focusCell(next);
  }
});
document.addEventListener('keydown', (event) => {
  if (event.ctrlKey || event.altKey || event.metaKey || event.repeat || help.open || battle.result) return;
  if (event.key === 'Escape' && selectingMove) {
    chooseAction('move');
    buttons.move.focus({ preventScroll: true });
    return;
  }
  const action = Object.entries(ACTIONS).find(([, info]) => info.key === event.key);
  if (action) {
    event.preventDefault();
    chooseAction(action[0]);
  }
});
byId('help-button').addEventListener('click', () => help.showModal());
byId('reset-button').addEventListener('click', restart);
byId('replay-button').addEventListener('click', restart);
