// Boot, input, and the frame loop. The sim decides; this drives it.
import { boot, tick, text, draw, REF } from './legday.js';

const canvas = document.getElementById('stage');
const ctx = canvas.getContext('2d');
const bootPane = document.getElementById('boot');
let size = { w: 0, h: 0 }, running = false, last = 0, ended = false;
const pending = [];

function resize() {
  const dpr = Math.min(devicePixelRatio || 1, 2);
  size = { w: innerWidth, h: innerHeight };
  canvas.width = size.w * dpr;
  canvas.height = size.h * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}
addEventListener('resize', resize);
resize();

/// Client pixels to the sim's reference points — the inverse of draw()'s fit.
function toRef(e) {
  const s = Math.min(size.w / REF.w, size.h / REF.h);
  return {
    x: (e.clientX - (size.w - REF.w * s) / 2) / s,
    y: (e.clientY - (size.h - REF.h * s) / 2) / s,
  };
}

// The sim takes one input per tick, so events queue. Consecutive drags
// coalesce: only the newest position matters, but a down or an up never
// gets dropped, and the sim anchors the drag on the down.
let down = false;
for (const [type, phase] of [['pointerdown', 1], ['pointermove', 2], ['pointerup', 3], ['pointercancel', 3]]) {
  canvas.addEventListener(type, (e) => {
    e.preventDefault();
    if (!running) return;
    if (ended && phase === 1) { start(); return; }
    if (phase === 2 && !down) return;
    if (phase === 1) { down = true; canvas.setPointerCapture(e.pointerId); }
    if (phase === 3) down = false;
    const p = toRef(e);
    const tail = pending[pending.length - 1];
    if (phase === 2 && tail && tail.phase === 2) { tail.x = p.x; tail.y = p.y; return; }
    pending.push({ phase, x: p.x, y: p.y });
  }, { passive: false });
}

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min((now - last) / 1000, 1 / 20);
  last = now;
  if (!running || dt <= 0) return;
  const input = pending.shift() || { phase: 0, x: 0, y: 0 };
  const f = tick(dt, input.phase, input.x, input.y);
  ended = f[8] === 1;
  draw(ctx, f, text(), size);
}

async function start() {
  ended = false; pending.length = 0; last = performance.now();
  await boot(WASM_BYTES, TUNABLES, (Math.random() * 2 ** 32) >>> 0);
  running = true;
}

document.getElementById('go').addEventListener('click', async () => {
  bootPane.hidden = true;
  await start();
});
requestAnimationFrame(frame);
