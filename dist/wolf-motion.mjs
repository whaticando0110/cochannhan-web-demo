const idleFrame = '0% 0%';
const clips = {
  idle: { frames: [0, 1, 0, 2, 3, 0], duration: 2000 },
  run: { frames: [4, 5, 6, 7], duration: 300 },
  bite: { frames: [8, 9, 10, 11, 0], duration: 380, reach: [0, .21, .16, .05, 0] },
  pounce: { frames: [8, 8, 9, 10, 11, 0], duration: 520, reach: [0, 0, .55, .36, .12, 0] },
  hit: { frames: [12, 13, 14, 15], duration: 240, reach: [.10, .08, .02, 0] },
  wall: {
    frames: [0, 8, 9, 10, 12, 13, 15, 0],
    offsets: [0, .14, .26, .33, .39, .45, .54, .61],
    reach: [0, -.21, .06, .04, -.10, -.16, -.06, 0],
    duration: 2120,
  },
};

function framePosition(index) {
  return `${index % 4 * 100 / 3}% ${Math.floor(index / 4) * 100 / 3}%`;
}

export function createWolfMotion(unit, reducedMotion, impact) {
  const sprite = unit.querySelector('.wolf-art');
  let animation;
  let travel;
  let dust;
  let pose;
  let finishWhenReduced;

  function stop() {
    pose = undefined;
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
    if (dust) {
      dust.cancel();
      dust = undefined;
    }
    sprite.style.backgroundPosition = idleFrame;
  }

  function play(name, { delay = 0, duration, cycles = 1, direction = [0, 0], after = idle } = {}) {
    stop();
    pose = name;
    const repeats = cycles === Infinity;
    if (reducedMotion.matches) {
      if (!repeats) after();
      return;
    }
    const clip = clips[name];
    const frames = clip.frames.map((frame, index) => {
      const reach = clip.reach?.[index] ?? 0;
      const [dx, dy] = direction;
      return {
        offset: clip.offsets?.[index] ?? index / clip.frames.length,
        backgroundPosition: framePosition(frame),
        translate: `${100 * dx * reach}% ${100 * dy * reach}%`,
        easing: 'steps(1, end)',
      };
    });
    frames.push({ ...frames.at(-1), offset: 1 });
    animation = sprite.animate(frames, { delay, duration: duration ?? clip.duration, iterations: cycles });
    if (repeats) return;
    finishWhenReduced = after;
    animation.onfinish = after;
  }

  function idle() {
    play('idle', { cycles: Infinity });
  }

  function attackWall() {
    play('wall', { cycles: Infinity, direction: [1, 0] });
    if (reducedMotion.matches) return;
    const { duration, offsets } = clips.wall;
    // Kick up splinters at the exact frame where the forepaws reach the palisade.
    dust = impact.animate([
      { offset: 0, opacity: 0, translate: '0 0', easing: 'steps(1, end)' },
      { offset: offsets[2], opacity: .85, translate: '0 0', easing: 'ease-out' },
      { offset: offsets[4], opacity: 0, translate: 'calc(var(--tile) * -.22) calc(var(--tile) * .12)' },
      { offset: 1, opacity: 0, translate: '0 0' },
    ], { duration, iterations: Infinity });
  }

  // The parent moves across the map while its child cycles through the running poses.
  function run(fromX, fromY, { duration = 340, delay = 0, after = idle } = {}) {
    if (fromX) unit.style.setProperty('--face', -Math.sign(fromX));
    const cycles = Math.max(1, Math.round(duration / clips.run.duration));
    play('run', { cycles, duration: duration / cycles, delay, after });
    if (reducedMotion.matches) return;
    travel = unit.animate([
      { translate: `${100 * fromX}% ${100 * fromY}%` },
      { translate: '0 0' },
    ], { delay, duration, fill: 'backwards' });
  }

  reducedMotion.addEventListener('change', () => {
    const finish = finishWhenReduced;
    const wasActive = Boolean(animation);
    const atWall = pose === 'wall';
    stop();
    if (finish) finish();
    else if (atWall) attackWall();
    else if (wasActive || !unit.hidden) idle();
  });

  return { idle, play, run, stop, attackWall };
}
