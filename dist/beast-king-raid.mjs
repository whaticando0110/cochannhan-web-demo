import mentorMotion from './assets/rampart/tinh-nghi.json' with { type: 'json' };
import { buildTremorKeyframes, createKimChungDefense, playBeastKingTremor, spawnEnhancedGuCast, spawnEnhancedGuImpact } from './rampart-fx.mjs';
import { toCell } from './world.mjs';

export const REAR_POST = toCell(12, 13);
export const RAID_END = 11600;
export const RAID_CUE = Object.freeze({
  roar: 2460, wall: 3970, call: 4330, climb: 4740,
  cast: 6660, release: 6990, wound: 7350, guard: 7990, block: 9100,
});

const WEST_POST = { col: 5, row: 11 };
const BOSS_ROW = 12.13;
const SHOULDER = { col: .45, row: 10.60 };
const BELL_PIVOT = { col: 5.5, row: 11.82 };
// Paw at (154,58) in cel 15 meets the mirrored atlas contact (62,52) at the bell.
const STRIKE = [
  BELL_PIVOT.col - 2 * (62 - 48) / 96 - (154 - 80) * 5.95 / 160,
  BELL_PIVOT.row + 2 * (52 - 82) / 96 - (58 - 100) * 5.95 / 160,
];
const READY_FRAME = 16;
const bossTrack = [
  [0, -7.1, 12.2], [650, -7.1, 12.2], [1780, -2.15, BOSS_ROW], [2300, -1.65, BOSS_ROW],
  [3050, -1.65, BOSS_ROW], [3460, -1.86, BOSS_ROW], [RAID_CUE.wall, .65, BOSS_ROW],
  [4400, -.28, BOSS_ROW], [RAID_CUE.wound, -.28, BOSS_ROW], [7640, -.63, BOSS_ROW],
  [8450, -.45, BOSS_ROW], [RAID_CUE.block, ...STRIKE], [9285, ...STRIKE],
  [9660, .10, BOSS_ROW], [RAID_END, .04, BOSS_ROW],
];
const mentorTrack = [
  [0, 8, 11], [RAID_CUE.climb, 8, 11], [4990, 8, 12], [5280, 7, 12],
  [5610, 6, 12], [5950, 5, 12], [6420, WEST_POST.col, WEST_POST.row], [RAID_END, WEST_POST.col, WEST_POST.row],
];
const cameraTrack = [
  [0, 4.35, 13], [1800, .55, 11.25], [4150, .55, 11.25], [6440, 2.03, 11.55],
  [9650, 2.03, 11.55], [RAID_END, 4.35, 13],
];
const bossPoses = [
  [1800, 4], [2190, 5], [RAID_CUE.roar, 6], [2880, 7], [3240, 8], [3620, 9],
  [RAID_CUE.wall, 10], [4090, 11], [4490, READY_FRAME], [RAID_CUE.wound, 12], [7510, 13],
  [7790, 7], [8460, 14], [RAID_CUE.block, 15], [9350, 11], [9650, 5], [10140, READY_FRAME],
];

export function raidProgress(value, identity) {
  if (value === identity || value === identity + '|scene') return 'scene';
  if (value === identity + '|aid') return 'aid';
  if (value === identity + '|rear') return 'rear';
  return 'lesson';
}

function sample(track, elapsed) {
  const next = track.findIndex(([at]) => at > elapsed);
  if (next < 0) return track.at(-1).slice(1);
  const [start, x, y] = track[next - 1];
  const [end, nextX, nextY] = track[next];
  const weight = (elapsed - start) / (end - start);
  return [x + (nextX - x) * weight, y + (nextY - y) * weight];
}

function spriteFrame(clip, elapsed) {
  const local = clip.loop ? elapsed % clip.durationMs : elapsed;
  const column = Math.max(0, clip.timesMs.findLastIndex(start => start <= local));
  return [column, clip.row];
}

export function raidFrame(elapsed, reduced = false, woundDelay = 0) {
  const time = Math.max(0, Math.min(elapsed, RAID_END));
  const beastTime = time >= RAID_CUE.wound && time < RAID_CUE.guard
    ? Math.max(RAID_CUE.wound - 1, time - woundDelay) : time;
  const boss = sample(bossTrack, beastTime);
  const mentor = sample(mentorTrack, time);
  const camera = reduced ? [.65, 11.6] : sample(cameraTrack, time);
  const bossCel = beastTime < 1800 ? Math.floor(Math.max(0, beastTime - 650) / 96) % 4
    : bossPoses.findLast(([at]) => at <= beastTime)[1];
  const { idle, walk, cast, guard } = mentorMotion.clips;
  let mentorCel = spriteFrame(idle, time);
  if (time >= RAID_CUE.guard) mentorCel = time < RAID_CUE.block
    ? spriteFrame(guard, Math.min(time - RAID_CUE.guard, 315)) : [3, guard.row];
  else if (time >= RAID_CUE.cast) mentorCel = spriteFrame(cast, time - RAID_CUE.cast);
  else if (time >= RAID_CUE.climb && time < 6420) mentorCel = spriteFrame(walk, (time - RAID_CUE.climb) * 1.66);
  return { boss, bossCel, mentor, mentorCel, camera };
}

function tile(value) {
  return `calc(var(--tile) * ${value})`;
}

function position(node, [col, row]) {
  node.style.left = tile(col);
  node.style.top = tile(row);
}

export function createBeastKingRaid({ field, plane, mentor, dialogue, skipButton, motion, defense, onYield, onFinish }) {
  const boss = document.createElement('div');
  boss.id = 'raid-boss';
  boss.className = 'raid-boss';
  boss.hidden = true;
  boss.setAttribute('aria-hidden', 'true');
  boss.innerHTML = '<i class="raid-boss-shadow"></i><i class="raid-boss-art"></i>';
  const bossArt = boss.lastElementChild;
  plane.append(boss);
  const effects = document.createElement('div');
  effects.className = 'raid-effects';
  effects.setAttribute('aria-hidden', 'true');
  plane.append(effects);
  const mentorArt = mentor.querySelector('.mentor-art');
  const speech = dialogue.querySelector('p');
  const bell = createKimChungDefense(null, plane, effects, motion);
  let startedAt;
  let frame;
  let nextCue;
  let tremor;
  let wallShake;
  let woundDelay;
  let shielded = false;

  function speak(line) {
    dialogue.hidden = !line;
    speech.textContent = line;
  }

  function show(frame) {
    boss.hidden = false;
    position(boss, frame.boss);
    const cel = frame.bossCel;
    bossArt.style.backgroundPosition = `${(cel % 4) * 100 / 3}% ${Math.floor(cel / 4) * 25}%`;
    mentor.classList.add('raid-mentor');
    mentor.style.transform = `translate3d(${tile(frame.mentor[0])}, ${tile(frame.mentor[1])}, 0)`;
    const [col, row] = frame.mentorCel;
    mentorArt.style.backgroundPosition = `${col * 100 / 7}% ${row * 25}%`;
  }

  function setShield() {
    if (shielded) return;
    shielded = true;
    bell.activate(BELL_PIVOT);
  }

  function effectsStop() {
    tremor?.stop();
    tremor = undefined;
    wallShake?.cancel();
    wallShake = undefined;
    effects.getAnimations({ subtree: true }).forEach(animation => animation.cancel());
    effects.replaceChildren();
    defense.stop();
  }

  function clear() {
    effectsStop();
    bell.stop();
    shielded = false;
    startedAt = undefined;
    frame = undefined;
    boss.hidden = true;
    skipButton.hidden = true;
    field.classList.remove('raid-playing');
    mentor.classList.remove('raid-mentor');
    mentorArt.style.backgroundPosition = '';
    speak('');
  }

  const cues = [
    [980, () => {
      tremor = playBeastKingTremor(field, plane, effects, motion, {
        dustPoints: [{ col: -2.0, row: 12.0 }, { col: -.75, row: 12.3 }],
      });
    }],
    [RAID_CUE.roar, () => speak('Thú vương!!!')],
    [RAID_CUE.wall, () => {
      field.classList.remove('beast-king-quake');
      if (motion.matches) return;
      defense.recoilAtWall();
      wallShake = field.animate(buildTremorKeyframes(9), { duration: 270 });
      const dust = document.createElement('span');
      dust.className = 'rampart-fx-tremor raid-wall-dust';
      position(dust, [3.2, 11.75]);
      const art = document.createElement('i');
      dust.append(art);
      effects.append(dust);
      art.animate(Array.from({ length: 8 }, (_, col) => ({
        backgroundPosition: `${col * 100 / 7}% 0%`, easing: 'steps(1, end)',
      })), { duration: 430 }).onfinish = () => dust.remove();
    }],
    [RAID_CUE.call, () => {
      speak('Nhóc con! Ngươi mau đi gọi người đến trợ giúp!');
      onYield();
    }],
    [6730, () => speak('')],
    [RAID_CUE.release, () => {
      const [x, y] = mentorMotion.sockets.releasePalm128;
      const from = { col: WEST_POST.col + .5 - 1.46 * (x / 128 - .5), row: WEST_POST.row + .89 - 1.46 * (1 - y / 128) };
      const duration = RAID_CUE.wound - RAID_CUE.release;
      spawnEnhancedGuCast(effects, motion, { kind: 'huyet-nguyet', from, target: SHOULDER, duration });
      defense.shoot({ from, target: SHOULDER, kind: 'huyet-nguyet', windup: 0, travelMs: duration }, () => {
        woundDelay = Math.max(0, performance.now() - startedAt - RAID_CUE.wound);
        spawnEnhancedGuImpact(effects, motion, { target: SHOULDER });
        return true;
      });
    }],
    [RAID_CUE.guard, setShield],
    [RAID_CUE.block, () => bell.triggerHit(BELL_PIVOT)],
  ];

  function aftermath() {
    show(raidFrame(RAID_END, motion.matches));
    setShield();
  }

  function finish() {
    if (startedAt === undefined) return;
    startedAt = undefined;
    frame = undefined;
    skipButton.hidden = true;
    field.classList.remove('raid-playing');
    speak('');
    effectsStop();
    aftermath();
    onFinish();
  }

  function advance(now) {
    if (startedAt === undefined) return;
    const elapsed = now - startedAt;
    if (elapsed >= RAID_END) return finish();
    for (; nextCue < cues.length && elapsed >= cues[nextCue][0]; nextCue++) cues[nextCue][1]();
    frame = raidFrame(elapsed, motion.matches, woundDelay);
    show(frame);
  }

  function start(now) {
    clear();
    nextCue = 0;
    woundDelay = Infinity;
    startedAt = now;
    field.classList.add('raid-playing');
    skipButton.hidden = false;
    skipButton.focus({ preventScroll: true });
    advance(now);
  }

  skipButton.addEventListener('click', finish);
  return { start, finish, clear, advance, aftermath, get camera() { return frame?.camera; } };
}
