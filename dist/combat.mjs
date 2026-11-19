export const BOARD = Object.freeze({ columns: 8, rows: 5 });
export const ROCKS = Object.freeze([11, 28, 30]);

export const ACTIONS = Object.freeze({
  move: { name: 'Di chuyển', key: '1', range: 2 },
  strike: { name: 'Tay không', key: '2', range: 1, damage: 14, gain: 1 },
  moon: { name: 'Nguyệt Quang Cổ', key: '3', range: 4, damage: 26, cost: 2 },
  guard: { name: 'Bạch Ngọc Cổ', key: '4', reduction: 0.7, gain: 1 },
  heal: { name: 'Sinh Cơ Diệp', key: '5', healing: 20, cost: 2 },
});

const duelArena = Object.freeze({ ...BOARD, rocks: new Set(ROCKS) });
const duelOpponent = Object.freeze({
  name: 'Cổ sư Trung Châu',
  heavyName: 'Trảm sương', heavyEvery: 3, heavyRange: 5, heavyDamage: 28,
  strikeName: 'Đánh gần', strikeDamage: 14, pace: 2,
  victory: 'Bạn thắng trận trên Thềm Hứng Mây.',
  defeat: 'Bạn đã gục trên Thềm Hứng Mây.',
});

export function distance(from, to, columns = BOARD.columns) {
  return Math.abs((from % columns) - (to % columns)) +
    Math.abs(Math.floor(from / columns) - Math.floor(to / columns));
}

export function coordinate(cell, columns = BOARD.columns) {
  let letter = '';
  for (let col = cell % columns; col >= 0; col = Math.floor(col / 26) - 1) {
    letter = String.fromCharCode(65 + col % 26) + letter;
  }
  return letter + (Math.floor(cell / columns) + 1);
}

export function neighbors(cell, { columns, rows }) {
  const candidates = [cell - columns, cell - 1, cell + 1, cell + columns];
  return candidates.filter(next => next >= 0 && next < columns * rows && distance(cell, next, columns) === 1);
}

function openCell(arena, cell) {
  if (arena.rocks.has(cell)) return false;
  const bounds = arena.bounds;
  if (!bounds) return true;
  const col = cell % arena.columns;
  const row = Math.floor(cell / arena.columns);
  return col >= bounds.left && col <= bounds.right && row >= bounds.top && row <= bounds.bottom;
}

function movementDistances(arena, from, budget, blocker) {
  const distances = new Map([[from, 0]]);
  const queue = [from];
  for (let cursor = 0; cursor < queue.length; cursor++) {
    const current = queue[cursor];
    const steps = distances.get(current);
    if (steps >= budget) continue;
    for (const cell of neighbors(current, arena)) {
      if (cell === blocker || !openCell(arena, cell) || distances.has(cell)) continue;
      distances.set(cell, steps + 1);
      queue.push(cell);
    }
  }
  distances.delete(from);
  return distances;
}

export function moveTargets(state) {
  if (state.result) return [];
  return [...movementDistances(state.arena, state.player.cell, state.actions.move.range, state.rival.cell).keys()];
}

function enemyIntent(state) {
  const { arena, opponent: clock } = state;
  const gap = distance(state.player.cell, state.rival.cell, arena.columns);
  if ((state.turn - 1) % clock.heavyEvery === 0 && gap <= clock.heavyRange) {
    const cells = [state.player.cell, ...neighbors(state.player.cell, arena)].filter(cell => openCell(arena, cell));
    return { type: 'heavy', name: clock.heavyName, cells, damage: clock.heavyDamage };
  }
  if (gap === 1) return { type: 'strike', name: clock.strikeName, cells: [state.player.cell], damage: clock.strikeDamage };
  return { type: 'advance', name: 'Áp sát', cells: [], damage: 0 };
}

export function createBattle({
  arena = duelArena, opponent = duelOpponent, actions = ACTIONS,
  player = { cell: 18, hp: 72, maxHp: 72, qi: 4, maxQi: 6 },
  rival = { cell: 22, hp: 76, maxHp: 76 },
} = {}) {
  const state = {
    turn: 1,
    arena, opponent, actions,
    player: { ...player },
    rival: { ...rival },
    result: null,
    events: [],
  };
  state.intent = enemyIntent(state);
  state.report = [{
    text: state.intent.cells.length ? `${opponent.name} đã nhắm vào vùng ô đỏ.` : `${opponent.name} đang áp sát.`,
    tone: 'danger',
  }];
  return state;
}

export function actionBlock(state, id) {
  if (state.result) return 'Trận đấu đã kết thúc.';
  if (!Object.hasOwn(state.actions, id)) return 'Hành động không hợp lệ.';
  const rule = state.actions[id];
  if ((rule.cost ?? 0) > state.player.qi) return 'Thiếu chân nguyên.';
  if (id === 'move' && moveTargets(state).length === 0) return 'Không còn ô để di chuyển.';
  if (id === 'heal' && state.player.hp === state.player.maxHp) return 'Sinh lực đã đầy.';
  if (rule.damage && distance(state.player.cell, state.rival.cell, state.arena.columns) > rule.range) {
    return `Đối thủ ngoài tầm ${rule.range} ô.`;
  }
  return '';
}

function approach(state) {
  const { arena, player, rival, opponent } = state;
  const reach = movementDistances(arena, rival.cell, opponent.pace, player.cell);
  const distancesFromPlayer = movementDistances(arena, player.cell, arena.columns * arena.rows);
  let next = rival.cell;
  let best = distancesFromPlayer.get(next) ?? Infinity;
  for (const cell of reach.keys()) {
    const steps = distancesFromPlayer.get(cell) ?? Infinity;
    if (steps < best) {
      best = steps;
      next = cell;
    }
  }
  return next;
}

export function playTurn(state, id, target) {
  const error = actionBlock(state, id);
  if (error) return { state, error };
  if (id === 'move' && !moveTargets(state).includes(target)) return { state, error: 'Chọn một ô sáng trong tầm di chuyển.' };

  const next = { ...state, player: { ...state.player }, rival: { ...state.rival }, events: [] };
  const { player, rival, events } = next;
  const rule = state.actions[id];
  player.qi = Math.min(player.maxQi, player.qi - (rule.cost ?? 0) + (rule.gain ?? 0));
  const report = [];
  const note = (text, tone = 'neutral') => report.push({ text, tone, turn: state.turn });

  if (id === 'move') {
    note(`Bạn di chuyển đến ô ${coordinate(target, state.arena.columns)}.`);
    events.push({ actor: 'player', type: 'move', from: player.cell, to: target });
    player.cell = target;
  }
  if (rule.damage) {
    const damage = Math.min(rival.hp, rule.damage);
    rival.hp -= damage;
    note(`${rule.name} gây ${damage} sát thương.`, 'player');
    events.push({ actor: 'player', type: id, from: player.cell, to: rival.cell, damage });
  }
  if (id === 'guard') {
    const restored = player.qi > state.player.qi ? ' và hồi 1 chân nguyên' : '';
    note(`${rule.name} che chắn${restored}.`, 'player');
    events.push({ actor: 'player', type: 'guard', to: player.cell });
  }
  if (id === 'heal') {
    const heal = Math.min(rule.healing, player.maxHp - player.hp);
    player.hp += heal;
    note(`${rule.name} hồi ${heal} sinh lực.`, 'player');
    events.push({ actor: 'player', type: 'heal', to: player.cell, heal });
  }

  if (rival.hp === 0) {
    next.result = 'win';
    note(state.opponent.victory, 'player');
  } else if (state.intent.type === 'advance') {
    const to = approach(next);
    if (to !== rival.cell) {
      events.push({ actor: 'rival', type: 'move', from: rival.cell, to });
      note(`Đối thủ áp sát đến ô ${coordinate(to, state.arena.columns)}.`);
      rival.cell = to;
    } else {
      note('Đối thủ giữ vị trí.');
    }
  } else if (state.intent.cells.includes(player.cell)) {
    const damage = id === 'guard' ? Math.ceil(state.intent.damage * (1 - rule.reduction)) : state.intent.damage;
    const taken = Math.min(player.hp, damage);
    player.hp -= taken;
    note(`${state.intent.name} trúng bạn, mất ${taken} sinh lực.`, 'danger');
    events.push({ actor: 'rival', type: state.intent.type, from: rival.cell, to: player.cell, damage: taken });
    if (player.hp === 0) {
      next.result = 'loss';
      note(state.opponent.defeat, 'danger');
    }
  } else {
    note(`Bạn né được ${state.intent.name.toLowerCase()}.`, 'player');
  }

  if (!next.result) {
    next.turn++;
    next.intent = enemyIntent(next);
  } else {
    next.intent = null;
  }
  next.report = [...report, ...state.report].slice(0, 10);
  return { state: next, error: '' };
}
