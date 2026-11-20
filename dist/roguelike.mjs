import { ACTIONS, BOARD, createBattle, playTurn } from './combat.mjs';
import { aptitude, finalDepth, minAwakeningDepth, seaEssenceRatio } from './awakening-rules.mjs';

export const FLOORS = [
  {
    name: 'Rìa rừng Thanh Mao', enemy: 'Điện Lang', theme: 'trail', hp: 48,
    heavy: 'Vồ mồi', damage: 12, strike: 8, heavyEvery: 2, pace: 1,
    layouts: [[3, 12, 30, 34], [4, 10, 27, 36], [2, 13, 25, 37]],
  },
  {
    name: 'Khe đá Hoang Nha', enemy: 'Điện Lang tinh anh', theme: 'mulch', hp: 62,
    heavy: 'Vồ xuyên khe', damage: 17, strike: 11, heavyEvery: 2, pace: 2,
    layouts: [[5, 12, 26, 36], [3, 10, 29, 38], [2, 11, 26, 35]],
  },
  {
    name: 'Hang Cuồng Điện Lang', enemy: 'Cuồng Điện Lang', theme: 'stone', hp: 84,
    heavy: 'Cuồng lôi vồ', damage: 23, strike: 13, heavyEvery: 2, pace: 2,
    layouts: [[2, 11, 28, 35], [5, 10, 29, 34], [3, 13, 26, 36]],
  },
];

export const REWARDS = {
  medicine: { name: 'Dược thảo', description: 'Hồi 24 sinh lực trước khi vào màn tới.' },
  stone: { name: 'Nguyên thạch', description: 'Hồi đầy chân nguyên và tăng giới hạn thêm 1 trong lượt chơi này.' },
  refine: { name: 'Luyện Nguyệt Quang', description: 'Nguyệt Quang gây thêm 7 sát thương trong lượt chơi này.' },
};

export function rebirthProfile(hero, depth) {
  if (!['huyen-bao', 'ao-reu'].includes(hero) || !Number.isInteger(depth) ||
      depth < minAwakeningDepth || depth > finalDepth) return null;
  const sea = seaEssenceRatio(depth);
  return { hero, depth, grade: aptitude(depth), seaPct: Math.round(sea * 100), maxQi: 3 + Math.floor(depth / 10) };
}

function encounter(run, player) {
  const floor = FLOORS[run.floor];
  const variant = Math.floor(run.seed / floor.layouts.length ** run.floor) % floor.layouts.length;
  return createBattle({
    arena: { ...BOARD, rocks: new Set(floor.layouts[variant]) },
    opponent: {
      name: floor.enemy, heavyName: floor.heavy, heavyEvery: floor.heavyEvery, heavyRange: 5, heavyDamage: floor.damage,
      strikeName: 'Cắn xé', strikeDamage: floor.strike, pace: floor.pace,
      victory: `Đã hạ ${floor.enemy}.`, defeat: `Bạn đã gục ở ${floor.name}.`,
    },
    actions: {
      move: ACTIONS.move, strike: ACTIONS.strike,
      moon: { ...ACTIONS.moon, damage: ACTIONS.moon.damage + run.moonBonus },
      guard: { ...ACTIONS.guard, name: 'Thủ thế' },
    },
    player: { ...player, cell: 17 },
    rival: { cell: 21, hp: floor.hp, maxHp: floor.hp },
  });
}

export function startRun(profile, seed) {
  const run = { profile, seed: seed >>> 0, floor: 0, phase: 'battle', moonBonus: 0, log: [] };
  return { ...run, battle: encounter(run, { hp: 48, maxHp: 48, qi: profile.maxQi, maxQi: profile.maxQi }) };
}

function chooseReward(run, id) {
  if (!Object.hasOwn(REWARDS, id)) return { run, error: 'Phần thưởng không hợp lệ.' };
  const player = { ...run.battle.player };
  const next = { ...run, floor: run.floor + 1, phase: 'battle' };
  if (id === 'medicine') player.hp = Math.min(player.maxHp, player.hp + 24);
  if (id === 'stone') player.qi = ++player.maxQi;
  if (id === 'refine') next.moonBonus += 7;
  return { run: { ...next, battle: encounter(next, player) }, error: '' };
}

function resolve(run, command) {
  const [id, target] = command;
  if (run.phase === 'reward') return chooseReward(run, id);
  if (run.phase !== 'battle') return { run, error: 'Lượt chơi đã kết thúc.' };
  const { state, error } = playTurn(run.battle, id, target);
  if (error) return { run, error };
  const phase = state.result === 'loss' ? 'death' : state.result === 'win'
    ? (run.floor === FLOORS.length - 1 ? 'victory' : 'reward') : 'battle';
  return { run: { ...run, battle: state, phase }, error: '' };
}

export function advanceRun(run, id, target) {
  const command = target === undefined ? [id] : [id, target];
  const result = resolve(run, command);
  if (result.error) return result;
  return { run: { ...result.run, log: [...run.log, command] }, error: '' };
}

export const canSkipAwakening = (run) => run?.phase === 'death';

export function serializeRun(run) {
  const { profile: { hero, depth }, seed, log } = run;
  return JSON.stringify({ version: 1, hero, depth, seed, log });
}

export function restoreRun(value) {
  try {
    const saved = JSON.parse(value);
    const profile = rebirthProfile(saved.hero, saved.depth);
    if (saved.version !== 1 || !profile || !Number.isInteger(saved.seed) ||
        saved.seed !== (saved.seed >>> 0) || !Array.isArray(saved.log)) return null;
    let run = startRun(profile, saved.seed);
    for (const command of saved.log) {
      if (!Array.isArray(command) || command.length < 1 || command.length > 2 || typeof command[0] !== 'string') return null;
      const result = resolve(run, command);
      if (result.error) return null;
      run = result.run;
    }
    return { ...run, log: saved.log };
  } catch {
    return null;
  }
}
