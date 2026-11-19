const beats = [
  [0, 'silence'],
  [260, 'aura'],
  [690, 'arrival'],
  [1360, 'line'],
  [2420, 'windup'],
  [2670, 'slash'],
  [2980, 'rift'],
  [3550, 'white'],
  [4650, 'end'],
];

export function endingBeat(elapsed) {
  return beats[Math.max(0, beats.findLastIndex(([at]) => at <= elapsed))][1];
}

export function createForestEnding(field, plane, screen, onEnd) {
  const scene = field.querySelector('.immortal-scene');
  const dialogue = scene.querySelector('.immortal-line');
  const terrain = scene.querySelector('.rupture');
  const heading = screen.querySelector('h2');
  let started = null;

  function splitTerrain() {
    for (const half of terrain.children) {
      const fragment = plane.cloneNode(true);
      fragment.removeAttribute('id');
      for (const node of fragment.querySelectorAll('[id]')) node.removeAttribute('id');
      for (const node of fragment.querySelectorAll('.field-marker, .rampart-defense-effects')) node.remove();
      half.replaceChildren(fragment);
    }
  }

  function finish() {
    started = null;
    field.classList.remove('forest-ending');
    scene.hidden = true;
    for (const half of terrain.children) half.replaceChildren();
    screen.hidden = false;
    screen.dataset.stage = 'end';
    if (!screen.open) screen.showModal();
    heading.focus({ preventScroll: true });
  }

  function advance(now) {
    if (started === null) return;
    const stage = endingBeat(now - started);
    if (scene.dataset.stage === stage) return;
    const previous = scene.dataset.stage;
    scene.dataset.stage = stage;
    dialogue.hidden = stage !== 'line';
    // Preserve the fracture when a suspended tab resumes during the fade.
    if (stage === 'rift' || (stage === 'white' && previous !== 'rift')) splitTerrain();
    if (stage === 'white') {
      screen.hidden = false;
      screen.dataset.stage = 'white';
      screen.showModal();
    } else if (stage === 'end') {
      finish();
      onEnd();
    }
  }

  function start(now) {
    if (started !== null) return;
    started = now;
    scene.hidden = false;
    field.classList.add('forest-ending');
    advance(now);
  }

  function reset() {
    started = null;
    field.classList.remove('forest-ending');
    scene.hidden = true;
    dialogue.hidden = true;
    delete scene.dataset.stage;
    for (const half of terrain.children) half.replaceChildren();
    if (screen.open) screen.close();
    screen.hidden = true;
    delete screen.dataset.stage;
  }

  screen.addEventListener('cancel', event => event.preventDefault());
  return { start, advance, restore: finish, reset };
}
