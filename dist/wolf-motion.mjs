const idleFrame = '0% 0%';
// First opaque row of each 128 px atlas frame, used to pin the health bar above the pose.
const frameTop = [55, 54, 53, 56, 62, 57, 57, 50, 65, 31, 55, 62, 57, 62, 58, 56];
const clips = {
  idle: { frames: [0, 1, 0, 2, 3, 0], duration: 2000 },
  run: { frames: [4, 5, 6, 7], duration: 300 },
  bite: { frames: [8, 9, 10, 11, 0], duration: 380, reach: [0, .21, .16, .05, 0] },
  pounce: { frames: [8, 8, 9, 10, 11, 0], duration: 520, reach: [0, 0, .55, .36, .12, 0] },
  huntPounce: {
    frames: [0, 8, 9, 10, 11, 0], offsets: [0, .24, .8, .86, .92, .97],
    duration: 1187.5, reach: [0, -.05, .63, .44, .15, 0],
  },
  hit: { frames: [12, 13, 14, 15], duration: 240, reach: [.10, .08, .02, 0] },
  wall: {
    frames: [0, 8, 9, 10, 12, 13, 15, 0],
    offsets: [0, .14, .26, .33, .39, .45, .54, .61],
    reach: [0, -.21, .06, .04, -.10, -.16, -.06, 0],
    duration: 2120,
  },
  fall: {
    frames: [12, 13, 8, 8], duration: 320,
    reach: [.10, .14, .15, .15], drop: [0, .03, .07, .08], bodyScale: [1, .81, .67, .58],
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
    if (pose === 'down') unit.classList.remove('wolf-down');
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
        '--wolf-head-top': `${100 * frameTop[frame] / 128}%`,
        translate: `${100 * dx * reach}% ${100 * (dy * reach + (clip.drop?.[index] ?? 0))}%`,
        ...(clip.bodyScale && { scale: `1 ${clip.bodyScale[index]}` }),
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

  function down() {
    stop();
    pose = 'down';
    sprite.style.backgroundPosition = framePosition(8);
    unit.classList.add('wolf-down');
  }

  function fall() {
    play('fall', { direction: [-1, 0], after: down });
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
    if (pose === 'down') return;
    stop();
    if (finish) finish();
    else if (atWall) attackWall();
    else if (wasActive || !unit.hidden) idle();
  });

  return { idle, play, run, stop, attackWall, fall };
}
