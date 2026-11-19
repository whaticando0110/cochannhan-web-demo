// Huyền bào tay rộng, from the approved Activity atlas at 5738f80f.
// Each pair is [time in milliseconds, atlas frame]. The movement clips
// omit the ready pose before and after the actual dash or dodge.
const guardEnter = [[0, 0], [250, 6], [315, 7], [390, 8], [445, 9], [500, 10], [550, 11], [615, 12], [685, 13]];
const guardExit = [[0, 14], [75, 11], [150, 15], [215, 16], [285, 17], [360, 7], [430, 18], [505, 0]];
const forward = [[0, 7], [20, 19], [60, 20], [70, 21], [100, 22], [120, 23], [140, 24], [170, 25], [180, 26],
  [220, 27], [260, 28], [270, 29], [310, 30], [320, 31], [370, 7]];
const back = [[0, 13], [20, 32], [60, 33], [100, 34], [220, 35], [260, 36], [270, 37], [310, 35]];
const row = [[0, 13], [20, 32], [60, 38], [70, 39], [100, 40], [220, 41], [260, 42], [270, 43], [310, 41]];

function keyframes(cels, duration) {
  const frames = cels.map(([time, frame]) => ({
    offset: time / duration,
    backgroundPosition: `${(frame % 8) * 100 / 7}% ${Math.floor(frame / 8) * 100 / 5}%`,
    easing: 'steps(1)',
  }));
  if (frames.at(-1).offset < 1) frames.push({ ...frames.at(-1), offset: 1 });
  return frames;
}

const guardDuration = 740;
const guard = keyframes([
  ...guardEnter.map(([time, frame]) => [time * 340 / 685, frame]),
  ...guardExit.map(([time, frame]) => [480 + time * 260 / 505, frame]),
], guardDuration);
const ready = keyframes([[0, 13]], 470);

export const MOONLIGHT_RELEASE_MS = 330;
const castTimes = [0, 48, 112, 200, MOONLIGHT_RELEASE_MS, 406, 475, 536];
const recoveryTimes = [0, 30, 60, 110, 155, 215, 285, 370];

export function releasePalm(useAoReu) {
  return useAoReu ? [99.5 / 128, 72.5 / 128] : [97.5 / 128, 73.5 / 128];
}

function actionFrames(times, duration, row) {
  const frames = times.map((time, i) => ({
    offset: time / duration, backgroundPosition: `${100 * i / 7}% ${row}%`, easing: 'steps(1, end)',
  }));
  return [...frames, { ...frames.at(-1), offset: 1 }];
}

const castClip = actionFrames(castTimes, 610, 0);
const hitClip = actionFrames(recoveryTimes, 420, 100);

export function createHeroMotion(sprite, reducedMotion, useAoReu = false) {
  let current;
  let restTimer;
  let stride;
  let pendingHit = false;

  function stop() {
    clearTimeout(restTimer);
    sprite.classList.remove('at-rest', 'striding', 'climbing', 'running', 'guarding', 'casting', 'taking-hit');
    if (!current) return;
    current.onfinish = null;
    current.cancel();
    current = undefined;
  }

  function stand() {
    stop();
    stride = undefined;
    pendingHit = false;
    if (!reducedMotion.matches) sprite.classList.add('at-rest');
  }

  function travel(gait, duration) {
    if (reducedMotion.matches) return;
    stride = { gait, end: performance.now() + duration };
    if (sprite.classList.contains('casting') || sprite.classList.contains('taking-hit')) return;
    if (!sprite.classList.contains('striding')) {
      stop();
      sprite.classList.add('striding');
    }
    sprite.classList.toggle('climbing', gait === 'climb');
    sprite.classList.toggle('running', gait === 'run');
    const gaitRatio = gait === 'run' ? 0.95 : 0.68;
    sprite.style.setProperty('--gait-period', Math.round(duration * gaitRatio) + 'ms');
    clearTimeout(restTimer);
    restTimer = setTimeout(stand, duration + 32);
  }

  function playBattle(event, facing, columns, moveDuration) {
    stop();
    if (reducedMotion.matches) return;
    if (useAoReu) {
      if (event.type === 'move') {
        travel('walk', moveDuration);
      } else {
        sprite.classList.add('guarding');
        restTimer = setTimeout(stand, event.type === 'guard' ? guardDuration : 470);
      }
      return;
    }

    let frames = ready;
    let duration = 470;
    if (event.type === 'move') {
      const changesRow = Math.floor(event.to / columns) !== Math.floor(event.from / columns);
      const delta = event.to % columns - event.from % columns;
      frames = keyframes(changesRow ? row : delta * facing > 0 ? forward : back, 370);
      duration = moveDuration;
    } else if (event.type === 'guard') {
      frames = guard;
      duration = guardDuration;
    }

    current = sprite.animate(frames, { duration, fill: 'both' });
    current.onfinish = stand;
  }

  function playAction(className, frames, duration) {
    if (reducedMotion.matches) return;
    stop();
    sprite.classList.add(className);
    current = sprite.animate(frames, { duration, fill: 'both' });
    current.onfinish = () => {
      if (pendingHit) {
        pendingHit = false;
        hit();
      } else if (stride?.end > performance.now()) {
        stop();
        travel(stride.gait, stride.end - performance.now());
      } else stand();
    };
  }

  function cast() {
    playAction('casting', castClip, 610);
    return current;
  }

  function hit() {
    if (sprite.classList.contains('casting') && current.currentTime < MOONLIGHT_RELEASE_MS) {
      pendingHit = true;
      return;
    }
    pendingHit = false;
    playAction('taking-hit', hitClip, 420);
  }

  reducedMotion.addEventListener('change', stand);
  stand();
  return { stand, travel, playBattle, cast, hit };
}
