export const BOARD = Object.freeze({ columns: 8, rows: 5 });
export const ROCKS = Object.freeze([11, 28, 30]);

export const ACTIONS = Object.freeze({
  move: { name: 'Di chuyển', key: '1', range: 2 },
  strike: { name: 'Tay không', key: '2', range: 1, damage: 14, gain: 1 },
  moon: { name: 'Nguyệt Quang Cổ', key: '3', range: 4, damage: 26, cost: 2 },
  guard: { name: 'Bạch Ngọc Cổ', key: '4', reduction: 0.7, gain: 1 },
  heal: { name: 'Sinh Cơ Diệp', key: '5', healing: 20, cost: 2 },
});

const clock = Object.freeze({ heavyEvery: 3, heavyRange: 5, heavyDamage: 28, strikeDamage: 14, pace: 2 });

export function distance(from, to) {
  return Math.abs((from % BOARD.columns) - (to % BOARD.columns)) +
    Math.abs(Math.floor(from / BOARD.columns) - Math.floor(to / BOARD.columns));
}

export function coordinate(cell) {
  return String.fromCharCode(65 + cell % BOARD.columns) + (Math.floor(cell / BOARD.columns) + 1);
}

function neighbors(cell) {
  const candidates = [cell - BOARD.columns, cell - 1, cell + 1, cell + BOARD.columns];
  return candidates.filter(next => next >= 0 && next < BOARD.columns * BOARD.rows && distance(cell, next) === 1);
}

function movementDistances(from, budget, blocker) {
  const distances = new Map([[from, 0]]);
  const queue = [from];
  for (let cursor = 0; cursor < queue.length; cursor++) {
    const current = queue[cursor];
    const steps = distances.get(current);
    if (steps >= budget) continue;
    for (const cell of neighbors(current)) {
      if (cell === blocker || ROCKS.includes(cell) || distances.has(cell)) continue;
      distances.set(cell, steps + 1);
      queue.push(cell);
    }
  }
  distances.delete(from);
  return distances;
}

export function moveTargets(state) {
  if (state.result) return [];
  return [...movementDistances(state.player.cell, ACTIONS.move.range, state.rival.cell).keys()];
}

function enemyIntent(state) {
  const gap = distance(state.player.cell, state.rival.cell);
  if ((state.turn - 1) % clock.heavyEvery === 0 && gap <= clock.heavyRange) {
    const cells = [state.player.cell, ...neighbors(state.player.cell)].filter(cell => !ROCKS.includes(cell));
    return { type: 'heavy', name: 'Trảm sương', cells, damage: clock.heavyDamage };
  }
  if (gap === 1) return { type: 'strike', name: 'Đánh gần', cells: [state.player.cell], damage: clock.strikeDamage };
  return { type: 'advance', name: 'Áp sát', cells: [], damage: 0 };
}

export function createBattle() {
  const state = {
    turn: 1,
    player: { cell: 18, hp: 72, maxHp: 72, qi: 4, maxQi: 6 },
    rival: { cell: 22, hp: 76, maxHp: 76 },
    result: null,
    report: [{ text: 'Cổ sư Trung Châu đã nhắm vào vùng ô đỏ.', tone: 'danger' }],
    events: [],
  };
  state.intent = enemyIntent(state);
  return state;
}

export function actionBlock(state, id) {
  if (state.result) return 'Trận đấu đã kết thúc.';
  if (!Object.hasOwn(ACTIONS, id)) return 'Hành động không hợp lệ.';
  const rule = ACTIONS[id];
  if ((rule.cost ?? 0) > state.player.qi) return 'Thiếu chân nguyên.';
  if (id === 'move' && moveTargets(state).length === 0) return 'Không còn ô để di chuyển.';
  if (id === 'heal' && state.player.hp === state.player.maxHp) return 'Sinh lực đã đầy.';
  if ((id === 'strike' || id === 'moon') && distance(state.player.cell, state.rival.cell) > rule.range) {
    return `Đối thủ ngoài tầm ${rule.range} ô.`;
  }
  return '';
}

function approach(state) {
  const { player, rival } = state;
  const reach = movementDistances(rival.cell, clock.pace, player.cell);
  const distancesFromPlayer = movementDistances(player.cell, BOARD.columns * BOARD.rows);
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
  const rule = ACTIONS[id];
  player.qi = Math.min(player.maxQi, player.qi - (rule.cost ?? 0) + (rule.gain ?? 0));
  const report = [];
  const note = (text, tone = 'neutral') => report.push({ text, tone, turn: state.turn });

  if (id === 'move') {
    note(`Bạn di chuyển đến ô ${coordinate(target)}.`);
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
    note(`Bạch Ngọc Cổ che chắn${restored}.`, 'player');
    events.push({ actor: 'player', type: 'guard', to: player.cell });
  }
  if (id === 'heal') {
    const heal = Math.min(rule.healing, player.maxHp - player.hp);
    player.hp += heal;
    note(`Sinh Cơ Diệp hồi ${heal} sinh lực.`, 'player');
    events.push({ actor: 'player', type: 'heal', to: player.cell, heal });
  }

  if (rival.hp === 0) {
    next.result = 'win';
    note('Bạn thắng trận trên Thềm Hứng Mây.', 'player');
  } else if (state.intent.type === 'advance') {
    const to = approach(next);
    if (to !== rival.cell) {
      events.push({ actor: 'rival', type: 'move', from: rival.cell, to });
      note(`Đối thủ áp sát đến ô ${coordinate(to)}.`);
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
      note('Bạn đã gục trên Thềm Hứng Mây.', 'danger');
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
