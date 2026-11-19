import { MOONLIGHT, toCell } from './world.mjs';

export const SUPPLY_POST = toCell(9, 13);
export const RELIEF_START = toCell(8, 14);
export const ABSORB_MS = 1500;

export function createLesson(completed = false) {
  return { phase: completed ? 'complete' : 'training', absorbUntil: null };
}

export function settleTrainingShot(lesson, qi) {
  return lesson.phase === 'training' && qi < MOONLIGHT.cost
    ? { ...lesson, phase: 'refill' } : lesson;
}

export function startAbsorption(lesson, cell, now) {
  return lesson.phase === 'refill' && cell === SUPPLY_POST && lesson.absorbUntil === null
    ? { ...lesson, absorbUntil: now + ABSORB_MS } : lesson;
}

export function advanceAbsorption(lesson, cell, now) {
  if (lesson.absorbUntil === null) return lesson;
  if (cell !== SUPPLY_POST) return { ...lesson, absorbUntil: null };
  return now >= lesson.absorbUntil ? createLesson(true) : lesson;
}
