// Cinematic combat & Gu VFX helpers for Thú triều Thanh Mao Sơn (Act 1):
// 1. Beast King approaching seismic arena tremor (rung sàn đấu khi thú vương tới)
// 2. Kim Chung Tráo hit flash + 2-step Anime Impact Frame (lóe sáng + impact frame anime)
// 3. Enhanced Gu launch burst, foot back-draft, flight wake afterimages & hit-confirm flash

export const BEAST_KING_TREMOR_STEPS = Object.freeze([
  Object.freeze({ step: 1, label: 'footstep-far', delayMs: 0, durationMs: 240, amplitudePx: 5, lightning: false, danger: 0 }),
  Object.freeze({ step: 2, label: 'footstep-mid', delayMs: 520, durationMs: 280, amplitudePx: 8, lightning: true, danger: 0.08 }),
  Object.freeze({ step: 3, label: 'footstep-near', delayMs: 1020, durationMs: 320, amplitudePx: 11, lightning: true, danger: 0.14 }),
  Object.freeze({ step: 4, label: 'roar-quake', delayMs: 1480, durationMs: 620, amplitudePx: 14, lightning: true, danger: 0.25 }),
]);

export function buildTremorKeyframes(amplitudePx = 10, samples = 8) {
  const amp = Math.max(0, Number(amplitudePx) || 0);
  const frames = [{ offset: 0, translate: '0px 0px' }];
  for (let i = 1; i < samples; i++) {
    const t = i / samples;
    const decay = Math.pow(1 - t, 1.35);
    const sign = (i % 2 === 1) ? 1 : -1;
    const dx = Math.round(-sign * amp * 0.72 * decay);
    const dy = Math.round(sign * amp * decay);
    frames.push({
      offset: Number(t.toFixed(4)),
      translate: `${dx}px ${dy}px`,
    });
  }
  frames.push({ offset: 1, translate: '0px 0px' });
  return frames;
}

export function buildAnimeImpactSchedule({
  hitStopMs = 45,
  frameAMs = 48,
  frameBMs = 48,
  flashMs = 240,
  rippleMs = 470,
} = {}) {
  const t0 = 0;
  const tA = t0 + hitStopMs;
  const tB = tA + frameAMs;
  const tFlash = tB + frameBMs;
  const tEnd = tFlash + Math.max(flashMs, rippleMs);
  return {
    hitStop: { startMs: t0, endMs: tA, durationMs: hitStopMs },
    animeFrameA: { startMs: tA, endMs: tB, durationMs: frameAMs, className: 'anime-impact-a', atlasCol: 0 },
    animeFrameB: { startMs: tB, endMs: tFlash, durationMs: frameBMs, className: 'anime-impact-b', atlasCol: 1 },
    goldenFlash: { startMs: tFlash, endMs: tFlash + flashMs, durationMs: flashMs, className: 'bell-bloom', atlasCols: [2, 3, 4, 5, 6, 7] },
    sonicRipple: { startMs: tA, endMs: tA + rippleMs, durationMs: rippleMs, row: 1 },
    totalDurationMs: tEnd,
  };
}

export function buildGuWakeSchedule({
  from,
  target,
  bend = 0,
  count = 3,
  duration = 260,
  releaseDelay = 0,
} = {}) {
  const dx = target.col - from.col;
  const dy = target.row - from.row;
  const releaseAngle = Math.atan2(-dy, -dx);
  const wakes = [];
  for (let i = 1; i <= count; i++) {
    const t = i / (count + 1);
    const col = from.col + dx * t;
    const row = from.row + dy * t + 4 * t * (1 - t) * bend;
    const localDy = dy + 4 * (1 - 2 * t) * bend;
    const angleRad = Math.atan2(-localDy, -dx);
    wakes.push({
      index: i - 1,
      progress: Number(t.toFixed(4)),
      col: Number(col.toFixed(4)),
      row: Number(row.toFixed(4)),
      angleRad: Number(angleRad.toFixed(4)),
      delayMs: Math.round(releaseDelay + duration * t * 0.82),
      durationMs: 200,
      opacity: Number((0.88 - (i - 1) * 0.18).toFixed(2)),
    });
  }
  return {
    releaseBurst: {
      col: from.col,
      row: from.row,
      angleRad: Number(releaseAngle.toFixed(4)),
      delayMs: releaseDelay,
      durationMs: 180,
    },
    footDust: {
      col: Number((from.col + (dx < 0 ? 0.24 : -0.24)).toFixed(4)),
      row: Number((from.row + 0.42).toFixed(4)),
      flipX: dx < 0,
      delayMs: releaseDelay,
      durationMs: 210,
    },
    wakes,
  };
}

const GU_ROW_BY_KIND = Object.freeze({
  moonlight: 0,
  whirl: 1,
  needles: 2,
  blood: 3,
  'huyet-nguyet': 3,
});

function tile(value) {
  return `calc(var(--tile) * ${value})`;
}

function cel(col, maxCol, rowIndex = 0, maxRow = 1) {
  const xPct = maxCol > 0 ? (col * 100) / maxCol : 0;
  const yPct = maxRow > 0 ? (rowIndex * 100) / maxRow : 0;
  return {
    backgroundPosition: `${xPct}% ${yPct}%`,
    easing: 'steps(1, end)',
  };
}

export function playBeastKingTremor(field, plane, effectsLayer, reducedMotion, {
  dustPoints = [{ col: 3.2, row: 10.2 }, { col: 5.4, row: 10.6 }, { col: 7.8, row: 11.1 }],
  onComplete,
} = {}) {
  const timers = new Set();
  const animations = new Set();

  function cleanup() {
    for (const id of timers) clearTimeout(id);
    timers.clear();
    for (const anim of animations) {
      anim.onfinish = null;
      anim.cancel();
    }
    animations.clear();
    field?.classList.remove('beast-king-quake');
  }

  if (reducedMotion?.matches) {
    if (onComplete) onComplete();
    return { stop: cleanup };
  }

  for (const step of BEAST_KING_TREMOR_STEPS) {
    const timer = setTimeout(() => {
      timers.delete(timer);
      if (field) {
        field.classList.toggle('beast-king-quake', step.danger >= 0.15);
        const shake = field.animate(buildTremorKeyframes(step.amplitudePx, step.step === 4 ? 12 : 8), {
          duration: step.durationMs,
          easing: 'ease-out',
        });
        animations.add(shake);
        shake.onfinish = () => {
          animations.delete(shake);
          if (step.step === 4) field.classList.remove('beast-king-quake');
        };
      }
      if (effectsLayer) {
        dustPoints.forEach((pt, idx) => {
          const node = document.createElement('span');
          node.className = 'rampart-fx-tremor';
          node.style.left = tile(pt.col);
          node.style.top = tile(pt.row);
          const dust = document.createElement('i');
          dust.className = 'tremor-dust-art';
          node.append(dust);
          if (step.lightning && idx <= 1) {
            const arc = document.createElement('i');
            arc.className = 'tremor-lightning-art';
            node.append(arc);
            const arcAnim = arc.animate(Array.from({ length: 8 }, (_, c) => cel(c, 7, 1, 1)), {
              duration: 460,
            });
            animations.add(arcAnim);
          }
          effectsLayer.append(node);
          const dustAnim = dust.animate(Array.from({ length: 8 }, (_, c) => cel(c, 7, 0, 1)), {
            duration: 520,
          });
          animations.add(dustAnim);
          dustAnim.onfinish = () => {
            animations.delete(dustAnim);
            node.remove();
          };
        });
      }
    }, step.delayMs);
    timers.add(timer);
  }

  const last = BEAST_KING_TREMOR_STEPS.at(-1);
  const doneTimer = setTimeout(() => {
    timers.delete(doneTimer);
    field?.classList.remove('beast-king-quake');
    if (onComplete) onComplete();
  }, last.delayMs + last.durationMs);
  timers.add(doneTimer);

  return { stop: cleanup };
}

export function createKimChungDefense(field, plane, effectsLayer, reducedMotion) {
  let root;
  let backArt;
  let frontArt;
  let impactArt;
  let rippleArt;
  let clashArt;
  const timers = new Set();
  const animations = new Set();

  function clearTimers() {
    for (const id of timers) clearTimeout(id);
    timers.clear();
    for (const anim of animations) {
      anim.onfinish = null;
      anim.cancel();
    }
    animations.clear();
    field?.classList.remove('anime-impact-a', 'anime-impact-b');
    root?.classList.remove('bell-bloom');
  }

  function ensureMounted(post) {
    if (!root && plane) {
      root = document.createElement('div');
      root.className = 'kim-chung-unit';
      root.setAttribute('aria-hidden', 'true');
      backArt = document.createElement('i');
      backArt.className = 'kim-chung-back';
      frontArt = document.createElement('i');
      frontArt.className = 'kim-chung-front';
      impactArt = document.createElement('i');
      impactArt.className = 'kim-chung-impact-art';
      rippleArt = document.createElement('i');
      rippleArt.className = 'kim-chung-ripple-art';
      clashArt = document.createElement('i');
      clashArt.className = 'kim-chung-clash-art';
      root.append(backArt, frontArt, rippleArt, clashArt, impactArt);
      plane.append(root);
    }
    if (root && post) {
      root.style.left = tile(post.col);
      root.style.top = tile(post.row);
    }
  }

  function startSustainLoop() {
    if (!root || reducedMotion?.matches) return;
    backArt.hidden = false;
    frontArt.hidden = false;
    const backLoop = backArt.animate(Array.from({ length: 8 }, (_, c) => cel(c, 7, 1, 4)), {
      duration: 640,
      iterations: Infinity,
    });
    const frontLoop = frontArt.animate(Array.from({ length: 8 }, (_, c) => cel(c, 7, 2, 4)), {
      duration: 640,
      iterations: Infinity,
    });
    animations.add(backLoop);
    animations.add(frontLoop);
  }

  function activate(post) {
    clearTimers();
    ensureMounted(post);
    if (!root) return;
    impactArt.hidden = true;
    rippleArt.hidden = true;
    clashArt.hidden = true;
    backArt.hidden = true;
    frontArt.hidden = false;
    if (reducedMotion?.matches) {
      backArt.hidden = false;
      Object.assign(backArt.style, cel(0, 7, 1, 4));
      Object.assign(frontArt.style, cel(0, 7, 2, 4));
      return;
    }
    const castAnim = frontArt.animate(Array.from({ length: 6 }, (_, c) => cel(c, 7, 0, 4)), {
      duration: 420,
    });
    animations.add(castAnim);
    castAnim.onfinish = () => {
      animations.delete(castAnim);
      startSustainLoop();
    };
  }

  function triggerHit(post, { shatter = false, onComplete } = {}) {
    clearTimers();
    ensureMounted(post);
    if (!root) return;
    const schedule = buildAnimeImpactSchedule();
    if (reducedMotion?.matches) {
      Object.assign(frontArt.style, cel(0, 7, shatter ? 4 : 3, 4));
      if (onComplete) onComplete();
      return schedule;
    }

    impactArt.hidden = false;
    rippleArt.hidden = false;
    clashArt.hidden = false;

    // Frame A: Stark monochrome B&W + gold core anime impact
    const tA = setTimeout(() => {
      timers.delete(tA);
      field?.classList.add('anime-impact-a');
      Object.assign(impactArt.style, cel(0, 7, 0, 2));
      Object.assign(clashArt.style, cel(0, 7, 2, 2));
    }, schedule.animeFrameA.startMs);
    timers.add(tA);

    // Frame B: Inverted pitch-black / blazing white-gold anime speed-lines
    const tB = setTimeout(() => {
      timers.delete(tB);
      field?.classList.remove('anime-impact-a');
      field?.classList.add('anime-impact-b');
      Object.assign(impactArt.style, cel(1, 7, 0, 2));
      Object.assign(clashArt.style, cel(1, 7, 2, 2));
    }, schedule.animeFrameB.startMs);
    timers.add(tB);

    // Blinding Golden Bell Flash + Sonic Bronze Shockwave + Camera Kick
    const tFlash = setTimeout(() => {
      timers.delete(tFlash);
      field?.classList.remove('anime-impact-a', 'anime-impact-b');
      root.classList.add('bell-bloom');
      if (field) {
        const kick = field.animate(buildTremorKeyframes(9, 6), { duration: 240, easing: 'ease-out' });
        animations.add(kick);
      }
      const bellRow = shatter ? 4 : 3;
      if (shatter) backArt.hidden = true;
      const bellAnim = frontArt.animate(Array.from({ length: 6 }, (_, c) => cel(c, 7, bellRow, 4)), {
        duration: shatter ? 495 : 455,
        fill: 'forwards',
      });
      const flashAnim = impactArt.animate([2, 3, 4, 5, 6, 7].map(c => cel(c, 7, 0, 2)), {
        duration: 360,
      });
      const rippleAnim = rippleArt.animate(Array.from({ length: 8 }, (_, c) => cel(c, 7, 1, 2)), {
        duration: schedule.sonicRipple.durationMs,
      });
      const clashAnim = clashArt.animate([2, 3, 4, 5, 6, 7].map(c => cel(c, 7, 2, 2)), {
        duration: 320,
      });
      animations.add(bellAnim);
      animations.add(flashAnim);
      animations.add(rippleAnim);
      animations.add(clashAnim);
      bellAnim.onfinish = () => {
        animations.delete(bellAnim);
        root.classList.remove('bell-bloom');
        impactArt.hidden = true;
        rippleArt.hidden = true;
        clashArt.hidden = true;
        if (!shatter) startSustainLoop();
        if (onComplete) onComplete();
      };
    }, schedule.goldenFlash.startMs);
    timers.add(tFlash);

    return schedule;
  }

  function stop() {
    clearTimers();
    root?.remove();
    root = undefined;
  }

  return { activate, triggerHit, stop };
}

export function spawnEnhancedGuCast(effectsLayer, reducedMotion, {
  kind = 'moonlight',
  from,
  target,
  bend = 0,
  duration = 260,
  releaseDelay = 0,
} = {}) {
  const schedule = buildGuWakeSchedule({ from, target, bend, duration, releaseDelay });
  if (!effectsLayer || reducedMotion?.matches) return schedule;
  const row = GU_ROW_BY_KIND[kind] ?? 0;

  // 1. Palm Release Muzzle Burst
  const burstNode = document.createElement('span');
  burstNode.className = `rampart-gu-fx release-burst ${kind}`;
  burstNode.style.left = tile(schedule.releaseBurst.col);
  burstNode.style.top = tile(schedule.releaseBurst.row);
  const burstArt = document.createElement('i');
  burstArt.style.rotate = `${schedule.releaseBurst.angleRad}rad`;
  burstNode.append(burstArt);
  effectsLayer.append(burstNode);
  burstNode.animate([{ opacity: 1 }, { opacity: 1, offset: 0.75 }, { opacity: 0 }], {
    duration: schedule.releaseBurst.durationMs,
    delay: schedule.releaseBurst.delayMs,
    fill: 'both',
  });
  const bAnim = burstArt.animate([0, 1, 2, 3].map(c => cel(c, 7, row, 4)), {
    duration: schedule.releaseBurst.durationMs,
    delay: schedule.releaseBurst.delayMs,
  });
  bAnim.onfinish = () => burstNode.remove();

  // 2. Caster Foot Back-Draft Dust
  const dustNode = document.createElement('span');
  dustNode.className = 'rampart-gu-fx foot-dust';
  dustNode.style.left = tile(schedule.footDust.col);
  dustNode.style.top = tile(schedule.footDust.row);
  const dustArt = document.createElement('i');
  if (schedule.footDust.flipX) dustArt.style.transform = 'scaleX(-1)';
  dustNode.append(dustArt);
  effectsLayer.append(dustNode);
  dustNode.animate([{ opacity: 0.92 }, { opacity: 0 }], {
    duration: schedule.footDust.durationMs,
    delay: schedule.footDust.delayMs,
    fill: 'both',
  });
  const dAnim = dustArt.animate([0, 1, 2, 3].map(c => cel(c, 7, 4, 4)), {
    duration: schedule.footDust.durationMs,
    delay: schedule.footDust.delayMs,
  });
  dAnim.onfinish = () => dustNode.remove();

  // 3. Staggered Flight Qi Wake / Afterimages
  for (const w of schedule.wakes) {
    const wakeNode = document.createElement('span');
    wakeNode.className = `rampart-gu-fx flight-wake ${kind}`;
    wakeNode.style.left = tile(w.col);
    wakeNode.style.top = tile(w.row);
    const wakeArt = document.createElement('i');
    wakeArt.style.rotate = `${w.angleRad}rad`;
    wakeNode.append(wakeArt);
    effectsLayer.append(wakeNode);
    wakeNode.animate([{ opacity: 0 }, { opacity: w.opacity, offset: 0.2 }, { opacity: 0 }], {
      duration: w.durationMs,
      delay: w.delayMs,
      fill: 'both',
    });
    const wAnim = wakeArt.animate([4, 5, 6, 7].map(c => cel(c, 7, row, 4)), {
      duration: w.durationMs,
      delay: w.delayMs,
    });
    wAnim.onfinish = () => wakeNode.remove();
  }

  return schedule;
}

export function spawnEnhancedGuImpact(effectsLayer, reducedMotion, { target, angleRad = 0 } = {}) {
  if (!effectsLayer || reducedMotion?.matches || !target) return;
  const flashNode = document.createElement('span');
  flashNode.className = 'rampart-gu-fx hit-flash';
  flashNode.style.left = tile(target.col);
  flashNode.style.top = tile(target.row);
  const flashArt = document.createElement('i');
  flashArt.style.rotate = `${angleRad}rad`;
  flashNode.append(flashArt);
  effectsLayer.append(flashNode);
  flashNode.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 160, fill: 'both' });
  const fAnim = flashArt.animate([4, 5, 6, 7].map(c => cel(c, 7, 4, 4)), { duration: 160 });
  fAnim.onfinish = () => flashNode.remove();
}

export const PRIMEVAL_STONE_FRAME_WEIGHTS = Object.freeze([180, 185, 190, 190, 190, 195, 185, 185]);
export const SUPPLY_STAND_POST = Object.freeze({ col: 9, row: 13 });
export const SUPPLY_CRATE_POST = Object.freeze({ col: 10, row: 13 });

export function buildStoneAbsorptionSchedule({
  durationMs = 1500,
  standPost = SUPPLY_STAND_POST,
  cratePost = SUPPLY_CRATE_POST,
} = {}) {
  const scale = durationMs / 1500;
  let elapsed = 0;
  const frames = PRIMEVAL_STONE_FRAME_WEIGHTS.map((w, col) => {
    const startMs = Math.round(elapsed * scale);
    elapsed += w;
    const endMs = col === 7 ? durationMs : Math.round(elapsed * scale);
    const phase = col <= 1 ? 'ignite' : col <= 4 ? 'spiral-absorb' : col === 5 ? 'aperture-full' : 'crumble-powder';
    return {
      col,
      phase,
      startMs,
      endMs,
      durationMs: endMs - startMs,
      offset: Number((startMs / durationMs).toFixed(4)),
    };
  });
  return {
    durationMs,
    standPost,
    cratePost,
    facingTowardCrate: Math.sign(cratePost.col - standPost.col) || 1,
    apertureFullFrame: 5,
    apertureFullMs: frames[5].startMs,
    powderStartFrame: 6,
    powderStartMs: frames[6].startMs,
    frames,
  };
}

export function createSupplyStationFx(plane, reducedMotion) {
  let crateNode;
  let crateArt;
  let crateLoop;
  let absorbRoot;
  let underRingArt;
  let overSpiralArt;
  const animations = new Set();

  function stopAbsorbAnimations() {
    for (const anim of animations) {
      anim.onfinish = null;
      anim.cancel();
    }
    animations.clear();
    if (absorbRoot) absorbRoot.hidden = true;
  }

  function mountCrate(post = SUPPLY_CRATE_POST, { depleted = false } = {}) {
    if (!crateNode && plane) {
      crateNode = document.createElement('div');
      crateNode.className = 'supply-crate-unit';
      crateNode.setAttribute('aria-hidden', 'true');
      crateArt = document.createElement('i');
      crateArt.className = 'supply-crate-art';
      crateNode.append(crateArt);
      plane.append(crateNode);
    }
    if (crateNode && post) {
      crateNode.style.left = tile(post.col);
      crateNode.style.top = tile(post.row);
    }
    setDepleted(depleted);
  }

  function setDepleted(depleted) {
    if (!crateArt) return;
    if (crateLoop) {
      crateLoop.cancel();
      crateLoop = undefined;
    }
    if (depleted) {
      Object.assign(crateArt.style, cel(3, 3, 0, 1));
    } else if (reducedMotion?.matches) {
      Object.assign(crateArt.style, cel(0, 3, 0, 1));
    } else {
      crateLoop = crateArt.animate([0, 1, 2, 1].map(c => cel(c, 3, 0, 1)), {
        duration: 1200,
        iterations: Infinity,
      });
    }
  }

  function startAbsorption(post = SUPPLY_STAND_POST, { durationMs = 1500, onComplete } = {}) {
    stopAbsorbAnimations();
    const schedule = buildStoneAbsorptionSchedule({ durationMs });
    if (!plane || reducedMotion?.matches) return schedule;
    if (!absorbRoot) {
      absorbRoot = document.createElement('div');
      absorbRoot.className = 'stone-absorb-unit';
      absorbRoot.setAttribute('aria-hidden', 'true');
      underRingArt = document.createElement('i');
      underRingArt.className = 'stone-absorb-under';
      overSpiralArt = document.createElement('i');
      overSpiralArt.className = 'stone-absorb-over';
      absorbRoot.append(underRingArt, overSpiralArt);
      plane.append(absorbRoot);
    }
    if (post) {
      absorbRoot.style.left = tile(post.col);
      absorbRoot.style.top = tile(post.row);
    }
    absorbRoot.hidden = false;

    const overKeyframes = schedule.frames.map(f => ({
      ...cel(f.col, 7, 0, 1),
      offset: f.offset,
    }));
    const underKeyframes = schedule.frames.map(f => ({
      ...cel(f.col, 7, 1, 1),
      offset: f.offset,
    }));

    const overAnim = overSpiralArt.animate(overKeyframes, { duration: durationMs, fill: 'forwards' });
    const underAnim = underRingArt.animate(underKeyframes, { duration: durationMs, fill: 'forwards' });
    animations.add(overAnim);
    animations.add(underAnim);
    overAnim.onfinish = () => {
      animations.delete(overAnim);
      animations.delete(underAnim);
      if (absorbRoot) absorbRoot.hidden = true;
      setDepleted(true);
      if (onComplete) onComplete();
    };
    return schedule;
  }

  function cancelAbsorption() {
    // Player stepped away before completion: stop qi spiral without crumbling the stone into powder
    stopAbsorbAnimations();
  }

  function destroy() {
    stopAbsorbAnimations();
    if (crateLoop) crateLoop.cancel();
    crateNode?.remove();
    absorbRoot?.remove();
    crateNode = undefined;
    absorbRoot = undefined;
  }

  return { mountCrate, setDepleted, startAbsorption, cancelAbsorption, destroy };
}

// ============================================================================
// 5. RELIEF GUARD WALK & STANCE MOTION (CỔ SƯ TIẾP VIỆN DI CHUYỂN LÊN LŨY)
// ============================================================================

export const RELIEF_WALK_TIMES_MS = Object.freeze([0, 160, 300, 460]);
export const RELIEF_WALK_DURATION_MS = 600;

/**
 * Builds the 4-frame Web Animations API keyframe track for Row 1 (`walk[0..3]`)
 * of `guard-ivory-motion.png` (512x256, 4 cols x 2 rows @ 128x128).
 */
export function buildReliefWalkKeyframes() {
  const stops = [
    [RELIEF_WALK_TIMES_MS[0], 0],
    [RELIEF_WALK_TIMES_MS[1], 1],
    [RELIEF_WALK_TIMES_MS[2], 2],
    [RELIEF_WALK_TIMES_MS[3], 3],
    [RELIEF_WALK_DURATION_MS, 3],
  ];
  return stops.map(([timeMs, col]) => ({
    ...cel(col, 3, 1, 1),
    offset: Number((timeMs / RELIEF_WALK_DURATION_MS).toFixed(4)),
  }));
}

/**
 * Controller for `.ivory-guard.relief-guard` that switches `.guard-art` to
 * `guard-ivory-motion.png` (400% x 200%), loops Row 1 (`walk[0..3]`) while
 * advancing along the relief route, and settles back to Row 0 (`cast[0]`) on arrival.
 */
export function createReliefGuardMotion(unit, reducedMotion) {
  const art = unit?.querySelector?.('.guard-art') ?? unit;
  let walkAnim;
  let settleTimer;

  function clearSettleTimer() {
    if (settleTimer) {
      clearTimeout(settleTimer);
      settleTimer = undefined;
    }
  }

  function face(from, to) {
    if (!unit || !from || !to) return;
    const dx = to.col - from.col;
    if (dx > 0.01) unit.style.setProperty('--relief-face', '1');
    else if (dx < -0.01) unit.style.setProperty('--relief-face', '-1');
  }

  function walk({ from, to } = {}) {
    clearSettleTimer();
    face(from, to);
    unit?.classList?.add('relief-moving');
    if (!art || reducedMotion?.matches) return;
    if (!walkAnim) {
      walkAnim = art.animate(buildReliefWalkKeyframes(), {
        duration: RELIEF_WALK_DURATION_MS,
        iterations: Infinity,
      });
    }
  }

  function stand() {
    clearSettleTimer();
    if (walkAnim) {
      walkAnim.cancel();
      walkAnim = undefined;
    }
    unit?.classList?.remove('relief-moving');
    unit?.style?.setProperty('--relief-face', '-1');
    if (art?.style) {
      Object.assign(art.style, cel(0, 3, 0, 1));
    }
  }

  function step(from, to, durationMs = 230, { arrived = false } = {}) {
    unit?.style?.setProperty('--relief-step', `${durationMs}ms`);
    walk({ from, to });
    if (arrived) {
      settleTimer = setTimeout(stand, durationMs);
    }
  }

  return { face, walk, stand, step };
}
