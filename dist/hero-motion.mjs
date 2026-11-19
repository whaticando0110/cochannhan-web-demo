// Huyền bào tay rộng, from the approved Activity atlas at 5738f80f.
// Each pair is [time in milliseconds, atlas frame]. The movement clips
// omit the ready pose before and after the actual dash or dodge.
const idleFrames = [[0, 0], [460, 1], [660, 2], [890, 3], [1130, 4], [1340, 5], [1510, 0]];
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

const idleDuration = 1950;
const idle = keyframes(idleFrames, idleDuration);
const guardDuration = 740;
const guard = keyframes([
  ...guardEnter.map(([time, frame]) => [time * 340 / 685, frame]),
  ...guardExit.map(([time, frame]) => [480 + time * 260 / 505, frame]),
], guardDuration);
const ready = keyframes([[0, 13]], 470);

export function createHeroMotion(sprite, reducedMotion) {
  let current;
  let restTimer;

  function stop() {
    clearTimeout(restTimer);
    sprite.classList.remove('striding', 'climbing');
    if (!current) return;
    current.onfinish = null;
    current.cancel();
    current = undefined;
  }

  function stand() {
    stop();
    if (!reducedMotion.matches) current = sprite.animate(idle, { duration: idleDuration, iterations: Infinity });
  }

  function travel(onStairs, duration) {
    if (reducedMotion.matches) return;
    if (!sprite.classList.contains('striding')) {
      stop();
      sprite.classList.add('striding');
    }
    sprite.classList.toggle('climbing', onStairs);
    clearTimeout(restTimer);
    restTimer = setTimeout(stand, duration + 45);
  }

  function playBattle(event, facing, columns, moveDuration) {
    stop();
    if (reducedMotion.matches) return;

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

  reducedMotion.addEventListener('change', stand);
  stand();
  return { stand, travel, playBattle };
}
