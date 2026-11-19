const idleFrame = '0% 0%';
const clips = {
  idle: { frames: [0, 1, 0, 2, 3, 0], duration: 2000 },
  run: { frames: [4, 5, 6, 7], duration: 300 },
  bite: { frames: [8, 9, 10, 11, 0], duration: 380, reach: [0, .21, .16, .05, 0] },
  pounce: { frames: [8, 8, 9, 10, 11, 0], duration: 520, reach: [0, 0, .55, .36, .12, 0] },
  hit: { frames: [12, 13, 14, 15], duration: 240, reach: [.10, .08, .02, 0] },
};

function framePosition(index) {
  return `${index % 4 * 100 / 3}% ${Math.floor(index / 4) * 100 / 3}%`;
}

export function createWolfMotion(unit, reducedMotion) {
  const sprite = unit.querySelector('.wolf-art');
  let animation;
  let travel;
  let finishWhenReduced;

  function stop() {
    finishWhenReduced = undefined;
    if (animation) {
      animation.onfinish = null;
      animation.cancel();
      animation = undefined;
    }
    if (travel) {
      travel.cancel();
      travel = undefined;
    }
    sprite.style.backgroundPosition = idleFrame;
  }

  function play(name, { delay = 0, duration, cycles = 1, direction = [0, 0], after = idle } = {}) {
    stop();
    if (reducedMotion.matches) {
      if (name !== 'idle') after();
      return;
    }
    const clip = clips[name];
    const frames = clip.frames.map((frame, index) => {
      const reach = clip.reach?.[index] ?? 0;
      const [dx, dy] = direction;
      return {
        offset: index / clip.frames.length,
        backgroundPosition: framePosition(frame),
        translate: `${100 * dx * reach}% ${100 * dy * reach}%`,
        easing: 'steps(1, end)',
      };
    });
    frames.push({ ...frames.at(-1), offset: 1 });
    animation = sprite.animate(frames, { delay, duration: duration ?? clip.duration, iterations: cycles });
    if (name === 'idle') return;
    finishWhenReduced = after;
    animation.onfinish = after;
  }

  function idle() {
    play('idle', { cycles: Infinity });
  }

  // The parent moves across the map while its child cycles through the running poses.
  function run(fromX, fromY, { duration = 340, delay = 0 } = {}) {
    if (fromX) unit.style.setProperty('--face', -Math.sign(fromX));
    const cycles = Math.max(1, Math.round(duration / clips.run.duration));
    play('run', { cycles, duration: duration / cycles, delay });
    if (reducedMotion.matches) return;
    travel = unit.animate([
      { translate: `${100 * fromX}% ${100 * fromY}%` },
      { translate: '0 0' },
    ], { delay, duration, fill: 'backwards' });
  }

  reducedMotion.addEventListener('change', () => {
    const finish = finishWhenReduced;
    const wasActive = Boolean(animation);
    stop();
    if (finish) finish();
    else if (wasActive || !unit.hidden) idle();
  });

  return { idle, play, run, stop };
}
