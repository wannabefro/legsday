// Boot, input, and the frame loop. The sim decides; this drives it.
import { boot, tick, text, draw, setLights, REF } from './legday.js';

const canvas = document.getElementById('stage');
const ctx = canvas.getContext('2d');
const bootPane = document.getElementById('boot');
let size = { w: 0, h: 0 }, running = false, last = 0, ended = false;
const pending = [];
setLights(!location.search.includes('lights=off'));

// 100dvh is not innerHeight while the address bar is up.
function resize() {
  const dpr = Math.min(devicePixelRatio || 1, 3);
  const r = canvas.getBoundingClientRect();
  size = { w: r.width, h: r.height, dpr };
  canvas.width = Math.round(r.width * dpr);
  canvas.height = Math.round(r.height * dpr);
}
addEventListener('resize', resize);
resize();

/// Client pixels to the sim's reference points — the inverse of draw()'s fit.
function toRef(e) {
  const r = canvas.getBoundingClientRect();
  const s = Math.min(size.w / REF.w, size.h / REF.h);
  return {
    x: (e.clientX - r.left - (size.w - REF.w * s) / 2) / s,
    y: (e.clientY - r.top - (size.h - REF.h * s) / 2) / s,
  };
}

// The sim takes one input per tick, so events queue. Drags coalesce; a
// down or an up is never dropped.
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
  // Every queued touch lands this frame. One per frame let a drag lag.
  const batch = pending.length ? pending.splice(0) : [{ phase: 0, x: 0, y: 0 }];
  let f;
  for (const i of batch) f = tick(dt / batch.length, i.phase, i.x, i.y);
  ended = f[8] === 1;
  draw(ctx, f, text(), size, dt);
}

async function start() {
  ended = false; pending.length = 0; last = performance.now();
  resize();
  await boot(WASM_BYTES, TUNABLES, (Math.random() * 2 ** 32) >>> 0, SPRITES, size);
  running = true;
}

document.getElementById('go').addEventListener('click', async () => {
  bootPane.hidden = true;
  await start();
});
requestAnimationFrame(frame);
