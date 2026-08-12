// The browser half of LEGDAY. It owns pixels and touches; it owns no rules.
// Every number it draws came out of the Swift sim across the wasm boundary.
import { load, sprite, tinted, stamp, fit, hex, ZONES, AIR, SPINE, variants, seeded } from './art.js';

const REF = { w: 393, h: 852 };      // the sim's reference space, in points
const H = 64;                         // frame buffer header length
const SAFE_TOP = 26;

// A reactor module still expects WASI. Nothing here touches a real file.
function wasiShim() {
  const ok = () => 0;
  const bad = () => 8;                // EBADF: there is no filesystem
  const pair = (a, b) => { view().setUint32(a, 0, true); view().setUint32(b, 0, true); return 0; };
  return {
    args_get: ok, args_sizes_get: pair, environ_get: ok, environ_sizes_get: pair,
    fd_close: bad, fd_fdstat_get: bad, fd_prestat_get: bad, fd_prestat_dir_name: bad,
    fd_read: bad, fd_seek: bad, path_open: bad,
    fd_write: (fd, iovs, n, out) => {
      const v = view(); let written = 0, msg = '';
      for (let i = 0; i < n; i++) {
        const p = v.getUint32(iovs + i * 8, true), len = v.getUint32(iovs + i * 8 + 4, true);
        msg += new TextDecoder().decode(new Uint8Array(memory.buffer, p, len));
        written += len;
      }
      if (msg.trim()) console.log('[sim]', msg.trim());
      v.setUint32(out, written, true);
      return 0;
    },
    proc_exit: (code) => { throw new Error('sim exited: ' + code); },
    random_get: (p, n) => { crypto.getRandomValues(new Uint8Array(memory.buffer, p, n)); return 0; },
  };
}

let memory, wasm;
const view = () => new DataView(memory.buffer);

export async function boot(wasmBytes, tunables, seed, sprites) {
  if (sprites) await load(sprites);
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wasiShim(),
  });
  memory = instance.exports.memory;
  wasm = instance.exports;
  wasm._initialize();
  wasm.legday_boot();
  const inbox = new Float64Array(memory.buffer, wasm.legday_inbox(), 32);
  tunables.forEach((v, i) => { inbox[i] = v; });
  wasm.legday_start(BigInt(seed), REF.w, REF.h);
  reset();
}

/// Matches `Layout.capacity` in Bridge.swift.
const FRAME = H + 200 * 6 + 300 * 4 + 80 * 5 + 60 * 8 + 12 * 2 + 64 + 40 * 2 + 48 * 6;

export function tick(dt, phase, x, y) {
  wasm.legday_tick(dt, phase, x, y);
  // Growing the sim's memory detaches the old buffer, so re-read it each frame.
  return new Float64Array(memory.buffer, wasm.legday_frame(), FRAME);
}

export function text() {
  const bytes = new Uint8Array(memory.buffer, wasm.legday_text(), 8192);
  const end = bytes.indexOf(0);
  try { return JSON.parse(new TextDecoder().decode(bytes.subarray(0, end))); }
  catch { return {}; }
}

// ---- render state that outlives a frame ---------------------------------

const INK = {
  dead: '#1E1813', ambient: '#332C40', lantern: '#FFE29E', fogHue: '#A98CD4',
  parchment: '#E9DCBC', ink: '#241C12', gold: '#C99A2E', dormant: '#6B5A3D',
  priceIdle: '#8C7A57', priceLit: '#7A2E1E', muted: '#3B2C1C', dim: '#6B5238',
};

let marks = [], relic = null, birds = null, air = null, airStage = -1;
let corpses = [], effects = [], banner = { text: '', at: -99 };
let lit, lamp;   // offscreen: the lit world, and the light map

function reset() {
  const r = seeded(0xF1000000);
  marks = Array.from({ length: 26 }, () => ({
    terrainY: r() * REF.h, x: r() * REF.w, width: 34 + r() * 54,
    rot: r() * 6.28, alpha: 0.16 + r() * 0.24,
  }));
  relic = { terrainY: REF.h + 400, x: REF.w / 2, rest: 0, rng: seeded(0xFA11E4) };
  birds = { terrainY: REF.h + 600, x: REF.w * 0.5, bank: 0, rng: seeded(0xB12D5) };
  air = null; airStage = -1;
  corpses = []; effects = []; banner = { text: '', at: -99 };
}

function buffer(store, w, h) {
  if (store && store.canvas.width === w && store.canvas.height === h) return store;
  const canvas = document.createElement('canvas');
  canvas.width = w; canvas.height = h;
  return { canvas, ctx: canvas.getContext('2d') };
}

// ---- the frame ----------------------------------------------------------

export function draw(ctx, f, t, size, dt) {
  // The fit and the device-pixel ratio go in one matrix. Setting only the
  // fit drew the run at half size.
  const d = size.dpr || 1;
  const s = Math.min(size.w / REF.w, size.h / REF.h);
  ctx.setTransform(s * d, 0, 0, s * d,
                   (size.w - REF.w * s) / 2 * d, (size.h - REF.h * s) / 2 * d);
  ctx.clearRect(0, 0, REF.w, REF.h);

  const n = {
    foes: f[15], motes: f[16], bands: f[17], feats: f[18],
    fog: f[25], events: f[26], rope: f[27],
  };
  let p = H;
  const at = { foes: p };
  p += n.foes * 6; at.motes = p;
  p += n.motes * 4; at.bands = p;
  p += n.bands * 5; at.feats = p;
  p += n.feats * 8; at.cloak = p;
  p += 12 * 2; at.fog = p;
  p += n.fog; at.rope = p;
  p += n.rope * 2; at.events = p;

  const zone = ZONES[Math.max(0, Math.min(ZONES.length - 1, f[24] | 0))];
  const time = f[0];

  lit = buffer(lit, REF.w, REF.h);
  lamp = buffer(lamp, REF.w, REF.h);
  buildLightMap(f, time);

  // One opaque layer: canvas `multiply` on a transparent pixel returns the
  // source, and a sparse layer copied the light map.
  lit.ctx.setTransform(1, 0, 0, 1, 0, 0);
  lit.ctx.clearRect(0, 0, REF.w, REF.h);
  drawFloor(lit.ctx, f, zone, time);
  drawWalls(lit.ctx, f, at, n, zone, time);
  drawFeatures(lit.ctx, f, at, n, time);
  drawAir(lit.ctx, f, dt);
  drawFoes(lit.ctx, f, at, n);
  drawCorpses(lit.ctx, f, dt);
  multiplyByLight(lit.ctx);
  ctx.drawImage(lit.canvas, 0, 0);

  drawLanternPool(ctx, f, time);
  drawRope(ctx, f, at, n);
  drawLanternRig(ctx, f);
  drawHero(ctx, f, at, time);
  drawMotes(ctx, f, at, n, time);
  takeEvents(f, at, n, time, t);
  drawEffects(ctx, dt);
  drawSky(ctx, f, time);
  drawFog(ctx, f, at, n);
  drawChargeTrack(ctx, f);
  if (f[9]) drawCard(ctx, f, t);
  drawHud(ctx, f, t);
  drawBanner(ctx, time);
  if (f[8]) drawEnd(ctx, f);
}

/// The lantern, and four lights along the fog line.
/// The ambient is lighter than iOS; web/README.md says why.
function buildLightMap(f, time) {
  const c = lamp.ctx;
  c.setTransform(1, 0, 0, 1, 0, 0);
  c.globalCompositeOperation = 'source-over';
  c.fillStyle = INK.ambient;
  c.fillRect(0, 0, REF.w, REF.h);
  c.globalCompositeOperation = 'lighter';

  const flicker = 0.86 + 0.14 * Math.sin(time * 11.3) * Math.sin(time * 4.1);
  const bob = lanternBob(f);
  pour(c, bob.x, bob.y, 210, INK.lantern, flicker, 2.2);

  // The fog breathes on its own clock, slower than the lantern flickers.
  const swell = 0.82 + 0.18 * Math.sin(time * 0.9);
  const fogTop = f[4] - 30;
  for (let i = 0; i < 4; i++) {
    pour(c, REF.w * (i + 0.5) / 4, fogTop, 620, INK.fogHue, swell * 0.45, 1.6);
  }
}

/// One point light as a radial gradient. A larger `falloff` keeps it near
/// its source.
function pour(ctx, x, y, reach, colour, gain, falloff) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, reach);
  const r = parseInt(colour.slice(1, 3), 16), gg = parseInt(colour.slice(3, 5), 16);
  const b = parseInt(colour.slice(5, 7), 16);
  for (let k = 0; k <= 8; k++) {
    const d = k / 8;
    const a = gain * Math.pow(1 - d, falloff);
    g.addColorStop(d, `rgba(${r},${gg},${b},${a.toFixed(3)})`);
  }
  ctx.fillStyle = g;
  ctx.fillRect(x - reach, y - reach, reach * 2, reach * 2);
}

/// `?lights=off` shows the world before the light map. The scene is
/// near-black, so nothing else proves a layer drew.
let lightsOn = true;
export function setLights(on) { lightsOn = on; }

function multiplyByLight(ctx) {
  if (!lightsOn) return;
  ctx.globalCompositeOperation = 'multiply';
  ctx.drawImage(lamp.canvas, 0, 0);
  ctx.globalCompositeOperation = 'source-over';
}

// ---- floor --------------------------------------------------------------

function drawFloor(ctx, f, zone, time) {
  ctx.fillStyle = hex(zone.rock);
  ctx.fillRect(0, 0, REF.w, REF.h);
  const worldY = f[37];
  const tex = tinted(variants(zone.floor)[0], null, 0);
  for (const m of marks) {
    const y = worldY + REF.h - m.terrainY;
    if (y > REF.h + m.width) { m.terrainY += marks.length * 44; continue; }
    stamp(ctx, tex, m.x, y, m.width, m.width, m.rot, m.alpha);
  }
  const ry = worldY + REF.h - relic.terrainY;
  if (ry > REF.h + 120) {
    relic.terrainY += 1400 + relic.rng() * 2200;
    relic.x = 60 + relic.rng() * (REF.w - 120);
    relic.rest = relic.rng() * 6.28;
  } else {
    // Cloth on a dead pilgrim still moves. Nothing else about her does.
    stamp(ctx, tinted('fallen-pilgrim', null, 0), relic.x, ry, 62, 62,
          -(relic.rest + Math.sin(time * 0.7) * 0.03), 0.42);
  }
}

// ---- the two cliffs -----------------------------------------------------

function drawWalls(ctx, f, at, n, zone, time) {
  const band = f[43], tile = band * 1.55, worldY = f[37];
  const b = (i) => ({
    y: f[at.bands + i * 5], l: f[at.bands + i * 5 + 1], r: f[at.bands + i * 5 + 2],
    sl: f[at.bands + i * 5 + 3], sr: f[at.bands + i * 5 + 4],
  });

  // Solid ground behind the face, so a cliff has mass rather than an outline.
  ctx.fillStyle = INK.dead;
  ctx.beginPath();
  ctx.moveTo(0, b(0).y);
  for (let i = 0; i < n.bands; i++) ctx.lineTo(b(i).l, b(i).y);
  ctx.lineTo(0, b(n.bands - 1).y);
  ctx.closePath(); ctx.fill();
  ctx.beginPath();
  ctx.moveTo(REF.w, b(0).y);
  for (let i = 0; i < n.bands; i++) ctx.lineTo(b(i).r, b(i).y);
  ctx.lineTo(REF.w, b(n.bands - 1).y);
  ctx.closePath(); ctx.fill();
  for (let i = 0; i < n.bands; i++) {
    const k = b(i);
    if (k.sl >= 0) ctx.fillRect(k.sl, k.y - band / 2, k.sr - k.sl, band + 1);
  }

  const courses = zone.depth + 1;
  const names = variants(zone.wall);
  for (let i = 0; i < n.bands; i++) {
    const k = b(i);
    const index = Math.round((worldY + REF.h - k.y - band / 2) / band);
    for (let side = 0; side < 2; side++) {
      const edge = side === 0 ? k.l : k.r;
      const dir = side === 0 ? -1 : 1;
      for (let course = 0; course < courses; course++) {
        const x = edge + dir * (course * tile * 0.62 + tile * 0.30);
        if (x < -tile || x > REF.w + tile) break;
        placeWall(ctx, x, k.y, course, zone, names, index + side, band, tile, time);
      }
    }
    if (k.sl >= 0) {
      const span = k.sr - k.sl;
      const slots = Math.max(1, Math.round(span / (tile * 0.62)));
      for (let slot = 0; slot < slots; slot++) {
        placeWall(ctx, k.sl + span * (slot + 0.5) / slots, k.y, 0, zone, names,
                  index + slot + 97, band, tile, time);
      }
    }
  }
}

function placeWall(ctx, x, y, course, zone, names, seedIndex, band, tile, time) {
  const variant = Math.abs(seedIndex + course * 7) % names.length;
  // Raw parchment outshines the Pilgrim, so the cliff takes the zone's stone.
  const tex = tinted(names[variant], zone.wall === 'fog' ? null : hex(zone.rock), 0.80);
  const rest = ((seedIndex * 2654435761) % 628) / 100;
  const alpha = Math.max(0.32, 0.88 - course * 0.26);
  // Rock and masonry hold still. Mist and briar are not rock.
  if (zone.wall === 'masonry') {
    stamp(ctx, tex, x, y, tile * 0.92, band * 0.98, 0, course === 0 ? 0.90 : 0.55);
  } else if (zone.wall === 'fog') {
    const breath = Math.sin(time * 0.42 + rest);
    stamp(ctx, tex, x + breath * 7, y, tile * 1.4, tile * 1.4, -(rest + breath * 0.06),
          0.28 + 0.12 * (0.5 + 0.5 * Math.sin(time * 0.63 + rest)));
  } else if (zone.wall === 'briar') {
    stamp(ctx, tex, x, y, tile, tile, -(rest + Math.sin(time * 1.1 + rest) * 0.035), alpha);
  } else {
    stamp(ctx, tex, x, y, tile, tile, -rest, alpha);
  }
}

// ---- the channel's furniture --------------------------------------------

function drawFeatures(ctx, f, at, n, time) {
  const briar = tinted('briar-bed', '#39421A', 0.80);
  const slab = tinted('ground-slab', '#4A3626', 0.80);
  for (let i = 0; i < n.feats; i++) {
    const o = at.feats + i * 8;
    const x = f[o], y = f[o + 1], extent = f[o + 2], cairn = f[o + 3];
    const hp = f[o + 4], rot = f[o + 5], struckAgo = f[o + 6], id = f[o + 7];
    if (!cairn) {
      // Each bed keeps its own phase, so a field of briars never sways as one.
      const phase = id * 1.7;
      const side = extent * 2.2 * (1 + Math.sin(time * 0.9 + phase) * 0.035);
      stamp(ctx, briar, x, y, side, side,
            -(rot + Math.sin(time * 1.3 + phase) * 0.045), 0.5);
      continue;
    }
    const full = extent * 2, scale = 0.55 + 0.15 * hp, phase = id * 2.3;
    const alpha = struckAgo < 0.18 ? 0.55 : 1;
    // A stack is never quite settled, and the top slab teeters most.
    for (let k = 0; k < hp && k < 3; k++) {
      const width = full * scale * 1.16 * (1 - k * 0.16);
      const lift = k * full * 0.10;
      const teeter = Math.sin(time * 0.8 + phase + k * 0.9) * 0.014 * (k + 1);
      const c = Math.cos(-rot), s = Math.sin(-rot);
      const dx = -lift * 0.5, dy = -lift;
      stamp(ctx, slab, x + dx * c - dy * s, y + dx * s + dy * c,
            width, width * 0.82, -(rot + k * 0.22 + teeter), alpha);
    }
  }
}

// ---- the Pilgrim --------------------------------------------------------

const RIG = {
  core: 0.26, outer: 1.60, pad: 0.055, pivotX: 0.513, pivotY: 0.360,
  bodyH: 26, arm: { x: 0.02, y: 0.239 }, bodyW: 25.3,
};

function heroTexture(f) {
  return f[7] ? tinted('pilgrim-body', '#8A6FB3', 0.62) : tinted('pilgrim-body', null, 0);
}

function drawHero(ctx, f, at, time) {
  const tex = heroTexture(f);
  if (!tex) return;
  const size = fit('pilgrim-body', RIG.bodyH);
  const ox = (0.5 - RIG.pivotX) * size.w, oy = (0.5 - RIG.pivotY) * size.h;
  const blink = f[14] > 0 && Math.floor(time * 18) % 2 === 0;

  ctx.save();
  ctx.globalAlpha = blink ? 0.3 : 1;
  ctx.translate(f[5], f[6]);
  ctx.rotate(f[13] + f[20] + f[21]);

  // Never perfectly still, and the stride swells the body as it lands.
  const gait = Math.min(1, f[22] * 4);
  const breath = 1 + Math.sin(time * 2.1) * 0.012 * (1 - gait);
  const bob = 1 + Math.sin(f[22] * 6.2832 * 2) * 0.055 * gait;
  ctx.rotate(-Math.sin(f[22] * 6.2832) * 0.05 * gait);
  ctx.scale(breath, bob * breath);

  const half = Math.PI / 12;
  const inner = RIG.bodyH * RIG.core * 0.92, outer = RIG.bodyH * RIG.outer;
  for (let i = 0; i < 12; i++) {
    const phi = (i + 0.5) * (2 * Math.PI / 12) - Math.PI;
    ctx.save();
    ctx.rotate(f[at.cloak + i * 2]);
    ctx.beginPath();
    ctx.arc(0, 0, inner, phi - half - RIG.pad, phi + half + RIG.pad);
    ctx.arc(0, 0, outer, phi + half + RIG.pad, phi - half - RIG.pad, true);
    ctx.closePath();
    ctx.clip();
    const stretch = f[at.cloak + i * 2 + 1];
    ctx.scale(stretch, stretch);
    ctx.drawImage(tex, ox - size.w / 2, oy - size.h / 2, size.w, size.h);
    ctx.restore();
  }
  // The hood is a solid disc, so the figure never opens at the centre.
  ctx.save();
  ctx.beginPath();
  ctx.arc(0, 0, RIG.bodyH * RIG.core, 0, 7);
  ctx.clip();
  ctx.drawImage(tex, ox - size.w / 2, oy - size.h / 2, size.w, size.h);
  ctx.restore();
  ctx.restore();
}

/// Where the lantern hangs: on the arm, on a grip a tenth of the body long.
function lanternBob(f) {
  const angle = f[13] + f[20];
  const ax = (RIG.arm.x - 0.5) * RIG.bodyW, ay = (RIG.arm.y - 0.5) * RIG.bodyH;
  const mx = f[5] + ax * Math.cos(angle) - ay * Math.sin(angle);
  const my = f[6] + ax * Math.sin(angle) + ay * Math.cos(angle);
  const len = RIG.bodyH * 0.10;
  return { x: mx + len * Math.sin(f[23]), y: my + len * Math.cos(f[23]), mx, my };
}

function drawLanternRig(ctx, f) {
  const b = lanternBob(f);
  ctx.strokeStyle = INK.ink;
  ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(b.mx, b.my); ctx.lineTo(b.x, b.y); ctx.stroke();
  stamp(ctx, tinted('pilgrim-lantern', null, 0), b.x, b.y, 7.8, 7.8, f[13] + f[20], 1);
}

/// The pool the lantern throws. Two beating sines flicker it, so it never
/// settles into a disc.
function drawLanternPool(ctx, f, time) {
  const b = lanternBob(f);
  const reach = 26 * 2.6 * (0.86 + 0.14 * Math.sin(time * 11.3) * Math.sin(time * 4.1));
  const g = ctx.createRadialGradient(b.x, b.y, 0, b.x, b.y, reach);
  g.addColorStop(0, 'rgba(201,154,46,0.30)');
  g.addColorStop(0.45, 'rgba(201,154,46,0.11)');
  g.addColorStop(1, 'rgba(201,154,46,0)');
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  ctx.fillStyle = g;
  ctx.fillRect(b.x - reach, b.y - reach, reach * 2, reach * 2);
  ctx.restore();
}

// ---- foes, motes, corpses ----------------------------------------------

function drawFoes(ctx, f, at, n) {
  const base = tinted('foe-base', '#C06430', 0.62);
  const elite = tinted('foe-elite', '#7A2E1E', 0.62);
  for (let i = 0; i < n.foes; i++) {
    const o = at.foes + i * 6;
    const x = f[o], y = f[o + 1], radius = f[o + 2], isElite = f[o + 3];
    // A foe carries its own dark ground, so it never depends on the wall behind.
    ctx.globalAlpha = 0.5;
    ctx.fillStyle = '#000';
    ctx.beginPath(); ctx.arc(x, y, 15.5, 0, 7); ctx.fill();
    ctx.globalAlpha = 1;
    const rot = -(f[o + 4] - Math.PI / 2 + 0.09 * Math.sin(f[o + 5]));
    const scale = isElite ? 1 : radius / 9;
    const size = fit(isElite ? 'foe-elite' : 'foe-base', isElite ? 30 : 18);
    stamp(ctx, isElite ? elite : base, x, y, size.w * scale, size.h * scale, rot, 1);
  }
}

function drawMotes(ctx, f, at, n, time) {
  for (let i = 0; i < n.motes; i++) {
    const o = at.motes + i * 4;
    const beat = Math.sin(time * 4.4 + f[o + 3] * 0.8);
    ctx.globalAlpha = 0.78 + 0.22 * beat;
    ctx.fillStyle = '#8A6FB3';
    ctx.beginPath(); ctx.arc(f[o], f[o + 1], 5 * (1 + 0.20 * beat), 0, 7); ctx.fill();
  }
  ctx.globalAlpha = 1;
}

/// Debris that tumbles and is taken by the fog. Cosmetic, so a ballistic
/// step stands in for a physics body.
function drawCorpses(ctx, f, dt) {
  const tex = tinted('foe-base', '#C06430', 0.62);
  const size = fit('foe-base', 18);
  corpses = corpses.filter((c) => {
    c.vy += 620 * dt;
    c.x += c.vx * dt; c.y += c.vy * dt; c.rot += c.spin * dt;
    stamp(ctx, tex, c.x, c.y, size.w * c.scale, size.h * c.scale, c.rot, 1);
    return c.y < f[4];
  });
}

// ---- air, sky, fog ------------------------------------------------------

function drawAir(ctx, f, dt) {
  const stage = Math.max(0, Math.min(AIR.length - 1, f[24] | 0));
  const spec = AIR[stage];
  if (stage !== airStage) {
    airStage = stage;
    const r = seeded(0xA12D0F + stage);
    air = Array.from({ length: spec.count }, () => ({
      x: r() * REF.w, y: r() * REF.h, phase: r() * 6.283, scale: 0.6 + r() * 0.8,
    }));
  }
  ctx.fillStyle = hex(spec.colour);
  for (const s of air) {
    s.phase += dt * 1.4;
    s.y += spec.fall * s.scale * dt;
    s.x += Math.sin(s.phase) * spec.drift * dt;
    if (s.y < -20) { s.y = REF.h + 16; s.x = Math.random() * REF.w; }
    if (s.y > REF.h + 20) { s.y = -16; s.x = Math.random() * REF.w; }
    ctx.globalAlpha = 0.26 + 0.34 * (0.5 + 0.5 * Math.sin(s.phase));
    ctx.beginPath(); ctx.arc(s.x, s.y, spec.size * s.scale, 0, 7); ctx.fill();
  }
  ctx.globalAlpha = 1;
}

/// Carrion birds. They scroll slower, so the walls read as deep.
function drawSky(ctx, f, time) {
  const y = REF.h - (birds.terrainY - f[37] * 0.34);
  if (y > REF.h + 160) {
    birds.terrainY += 900 + birds.rng() * 1300;
    birds.x = 60 + birds.rng() * (REF.w - 120);
    birds.bank = birds.rng() - 0.5;
    return;
  }
  // A bird above the lantern is a silhouette, never a pale shape.
  const beat = Math.abs(Math.sin(time * 4.6));
  const w = 130 * (1 + 0.06 * beat), h = 130 * (1 - 0.24 * beat);
  stamp(ctx, tinted('carrion-birds', '#14100C', 0.80),
        birds.x + Math.sin(time * 0.11) * 46, y, w, h,
        -(birds.bank + Math.sin(time * 0.31) * 0.12), 0.5);
}

function drawFog(ctx, f, at, n) {
  if (n.fog < 2) return;
  ctx.beginPath();
  ctx.moveTo(0, REF.h);
  for (let i = 0; i < n.fog; i++) {
    ctx.lineTo(i / (n.fog - 1) * REF.w, f[4] - f[at.fog + i]);
  }
  ctx.lineTo(REF.w, REF.h);
  ctx.closePath();
  ctx.fillStyle = 'rgba(27,20,39,0.90)';
  ctx.fill();
  ctx.strokeStyle = 'rgba(51,41,71,0.90)';
  ctx.lineWidth = 1.5;
  ctx.stroke();
}

function drawRope(ctx, f, at, n) {
  if (n.rope < 2) return;
  ctx.strokeStyle = 'rgba(140,97,66,0.95)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(f[at.rope], f[at.rope + 1]);
  for (let i = 1; i < n.rope; i++) ctx.lineTo(f[at.rope + i * 2], f[at.rope + i * 2 + 1]);
  ctx.stroke();
  // The head reads the whip speed, so a fast crack visibly brightens.
  const heat = Math.min(1, f[42] / 1200);
  ctx.globalAlpha = 0.55 + 0.45 * heat;
  stamp(ctx, tinted('foe-base', '#B23A2E', 0.62), f[40], f[41],
        18 * (0.7 + 0.5 * heat), 18 * (0.7 + 0.5 * heat), 0, 1);
  ctx.globalAlpha = 1;
}

// ---- what a blow looks like (StrikeLayer) -------------------------------

function takeEvents(f, at, n, time, t) {
  for (let i = 0; i < n.events; i++) {
    const o = at.events + i * 6;
    const kind = f[o], x = f[o + 1], y = f[o + 2];
    if (kind === 0) attack(x, y, f[o + 3], f[o + 4], f[o + 5]);
    else if (kind === 1) flash(x, y, 'rgba(230,230,230,0.9)', 20);
    else if (kind === 2) {
      const elite = f[o + 3] === 1;
      const heading = Math.atan2(y - f[6], x - f[5]);
      flash(x, y, INK.gold, elite ? 12 : 7);
      burst(x, y, heading, elite);
      corpses.push({
        x, y, vx: Math.cos(heading) * (elite ? 150 : 110),
        vy: Math.sin(heading) * (elite ? 150 : 110) - 210,
        rot: 0, spin: (Math.random() - 0.5) * 8, scale: elite ? 1.6 : 1,
      });
      if (corpses.length > 40) corpses.shift();
    } else if (kind === 3) flash(x, y, '#8A6FB3', 6);
    else if (kind === 5) banner = { text: t.stage || '', at: time };
    else if (kind === 6) flash(x, y, '#8C7A57', 18);
  }
}

function push(e) { effects.push(e); if (effects.length > 260) effects.shift(); }
function flash(x, y, colour, radius) { push({ t: 0, life: 0.18, kind: 'flash', x, y, colour, radius }); }

/// Seven ink shards along the shot axis, and one ring opening behind them.
function burst(x, y, angle, elite) {
  const scale = elite ? 1.5 : 1;
  for (let i = 0; i < 7; i++) {
    const heading = angle + (i - 3) * 0.30;
    push({ t: 0, life: 0.26, kind: 'shard', x: x + Math.cos(heading) * 6,
           y: y + Math.sin(heading) * 6, heading, scale,
           travel: (26 + Math.random() * 18) * scale });
  }
  push({ t: 0, life: 0.30, kind: 'ring', x, y, colour: INK.gold, from: 6, to: 42 * scale, width: 2.4 });
}

/// The shot itself. Each weapon's form is already in the sim; only the
/// drawing was shared.
function attack(ax, ay, bx, by, form) {
  if (form === 0) {
    const heading = Math.atan2(by - ay, bx - ax);
    const reach = Math.hypot(bx - ax, by - ay);
    for (let i = 0; i < 4; i++) {
      push({ t: -i * 0.03, life: 0.22, kind: 'band', x: ax, y: ay, reach,
             from: heading - 0.85 + i * 0.14, to: heading - 0.45 + i * 0.14,
             width: 7 - i, alpha: 0.55 - i * 0.11 });
    }
  } else if (form === 1) {
    const reach = Math.hypot(bx - ax, by - ay);
    push({ t: 0, life: 0.34, kind: 'ring', x: ax, y: ay, colour: '#8A6FB3',
           from: 8, to: Math.max(16, reach), width: 4 });
    push({ t: -0.05, life: 0.34, kind: 'ring', x: ax, y: ay, colour: '#8A6FB3',
           from: 8, to: Math.max(16, reach), width: 1.2 });
  } else if (form === 2) {
    push({ t: 0, life: 0.18, kind: 'seed', x: ax, y: ay, bx, by });
    push({ t: -0.18, life: 1.2, kind: 'pool', x: bx, y: by });
  } else {
    push({ t: 0, life: 0.16, kind: 'shaft', x: ax, y: ay, bx, by });
  }
}

function drawEffects(ctx, dt) {
  effects = effects.filter((e) => {
    e.t += dt;
    if (e.t < 0) return true;
    const k = Math.min(1, e.t / e.life);
    if (k >= 1) return false;
    ctx.save();
    ctx.globalAlpha = 1 - k;
    if (e.kind === 'flash') {
      ctx.strokeStyle = e.colour; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(e.x, e.y, e.radius * (1 + 1.4 * k), 0, 7); ctx.stroke();
    } else if (e.kind === 'shard') {
      const d = e.travel * k;
      ctx.translate(e.x + Math.cos(e.heading) * d, e.y + Math.sin(e.heading) * d);
      ctx.rotate(e.heading);
      ctx.globalAlpha = 0.75 * (1 - k);
      ctx.fillStyle = INK.parchment;
      ctx.fillRect(-5.5 * e.scale, -0.7, 11 * e.scale, 1.4);
    } else if (e.kind === 'ring') {
      ctx.strokeStyle = e.colour; ctx.lineWidth = e.width;
      ctx.beginPath(); ctx.arc(e.x, e.y, e.from + (e.to - e.from) * k, 0, 7); ctx.stroke();
    } else if (e.kind === 'band') {
      ctx.globalAlpha = e.alpha * (1 - k);
      ctx.strokeStyle = INK.gold; ctx.lineWidth = e.width; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.arc(e.x, e.y, e.reach, e.from, e.to); ctx.stroke();
    } else if (e.kind === 'shaft') {
      ctx.strokeStyle = INK.parchment; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.bx, e.by); ctx.stroke();
      ctx.fillStyle = '#FFF6DE';
      const hx = e.x + (e.bx - e.x) * Math.min(1, k / 0.45);
      const hy = e.y + (e.by - e.y) * Math.min(1, k / 0.45);
      ctx.beginPath(); ctx.arc(hx, hy, 3, 0, 7); ctx.fill();
    } else if (e.kind === 'seed') {
      ctx.fillStyle = '#8FA03A';
      ctx.beginPath();
      ctx.arc(e.x + (e.bx - e.x) * k, e.y + (e.by - e.y) * k, 5.5, 0, 7);
      ctx.fill();
    } else if (e.kind === 'pool') {
      const grow = Math.min(1, k / 0.2) * (1 + 0.05 * Math.sin(e.t * 10));
      ctx.translate(e.x, e.y); ctx.scale(grow, grow * 0.79);
      ctx.fillStyle = 'rgba(143,160,58,0.30)';
      ctx.strokeStyle = 'rgba(143,160,58,0.50)'; ctx.lineWidth = 1.2;
      ctx.beginPath(); ctx.arc(0, 0, 29, 0, 7); ctx.fill(); ctx.stroke();
    }
    ctx.restore();
    return true;
  });
}

// ---- the HUD, the rail, the card ---------------------------------------

function serif(ctx, px, bold) {
  ctx.font = `${bold ? '700 ' : ''}${px}px Georgia, 'Times New Roman', serif`;
}

/// Three readings, the modifiers, and the deck as pips, on a torn page.
function drawHud(ctx, f, t) {
  const pipsY = SAFE_TOP + 62, bottom = pipsY + 30;
  const r = seeded(0x7EA21000);
  ctx.beginPath();
  ctx.moveTo(0, 0); ctx.lineTo(REF.w, 0); ctx.lineTo(REF.w, bottom);
  for (let x = REF.w; x > 0; x -= 11) ctx.lineTo(Math.max(0, x - 11), bottom + (r() - 0.5) * 10);
  ctx.lineTo(0, bottom);
  ctx.closePath();
  ctx.fillStyle = 'rgba(233,220,188,0.90)';
  ctx.fill();
  ctx.strokeStyle = 'rgba(23,18,14,0.45)'; ctx.lineWidth = 1; ctx.stroke();

  ctx.fillStyle = INK.muted;
  ctx.textBaseline = 'middle';
  serif(ctx, 16, true);
  ctx.textAlign = 'left';
  ctx.fillText('\u2727 ' + Math.floor(f[2]), 18, SAFE_TOP + 24);
  ctx.textAlign = 'center';
  ctx.fillText(Math.floor(f[1]) + ' FATHOMS', REF.w / 2, SAFE_TOP + 24);
  ctx.textAlign = 'right';
  ctx.fillText(Math.floor(f[3]) + ' felled', REF.w - 18, pipsY);

  serif(ctx, 12, false);
  ctx.fillStyle = INK.dim;
  ctx.textAlign = 'left';
  ctx.fillText(modsSummary(f), 18, SAFE_TOP + 44);
  ctx.fillStyle = INK.muted;
  ctx.textAlign = 'center';
  ctx.fillText(t.stage || '', REF.w / 2, pipsY + 16);
  pips(ctx, f, pipsY);
}

/// Your remaining deck, the gate, then Death's cards.
function pips(ctx, f, y) {
  let x = 18;
  const box = (fill, stroke) => {
    ctx.beginPath();
    ctx.roundRect(x - 4.5, y - 7, 9, 14, 2);
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
    x += 12;
  };
  for (let i = 0; i < f[33]; i++) {
    if (i >= f[34]) box(null, 'rgba(59,44,28,0.30)');
    else box('rgba(59,44,28,0.85)', null);
  }
  if (f[35] > 0) {
    ctx.fillStyle = f[36] ? '#7A2E1E' : INK.dim;
    ctx.fillRect(x, y - 9, 1, 18);
    x += 12;
    for (let i = 0; i < f[35]; i++) box('#050303', 'rgba(59,44,28,0.45)');
  }
}

/// Only what a card has changed. A run with no cards taken shows nothing.
function modsSummary(f) {
  const pct = (x) => `${x >= 1 ? '+' : ''}${Math.round((x - 1) * 100)}%`;
  const out = [];
  if (f[44] !== 1) out.push(`${f[44]} bolts`);
  if (f[45] !== 0.38) out.push(`atk ${pct(0.38 / f[45])}`);
  if (f[46] !== 1) out.push(`footing ${pct(f[46])}`);
  if (f[47] !== 34) out.push(`magnet ${pct(f[47] / 34)}`);
  if (f[48] !== 1) out.push(`stride ${pct(f[48])}`);
  if (f[50] !== 1) out.push(`essence ${pct(f[50])}`);
  if (f[49] !== 1) out.push(`scroll ${pct(f[49])}`);
  if (f[51] !== 1) out.push(`sink ${pct(f[51])}`);
  if (f[52] !== 1) out.push(`spawns ${pct(f[52])}`);
  if (f[53] !== 0) out.push(`fog ${f[53] >= 0 ? '+' : ''}${Math.round(f[53])}`);
  return out.join(' \u00b7 ');
}

/// Essence charging the next Fate Card, on a rail with a visible empty state.
function drawChargeTrack(ctx, f) {
  const w = 10, h = 120;
  const x = REF.w - 18 - w / 2, base = REF.h - 26;
  if (f[9] && f[19] <= 0) return;
  ctx.beginPath(); ctx.roundRect(x - w / 2, base - h, w, h, w / 2);
  ctx.fillStyle = 'rgba(176,161,125,0.13)'; ctx.fill();
  ctx.strokeStyle = 'rgba(176,161,125,0.30)'; ctx.lineWidth = 1; ctx.stroke();
  const k = Math.min(1, Math.max(0, f[19]));
  ctx.beginPath(); ctx.roundRect(x - w / 2, base - h * k, w, h * k, w / 2);
  ctx.globalAlpha = k >= 1 ? 1 : 0.85;
  ctx.fillStyle = INK.gold; ctx.fill();
  ctx.globalAlpha = 1;
  if (f[9]) {
    stamp(ctx, tinted('card-back', null, 0), x, base - h - 20, 24, 34, 0.12, 1);
  }
}

const CARD = { w: 290, h: 196, r: 12 };

/// The dealt Fate Card. The drag fills toward the commit threshold, so the
/// card cannot disagree with what commits.
function drawCard(ctx, f, t) {
  const risen = 0.4 * REF.h - (1 - f[11]) * 240;
  const cx = REF.w / 2 + f[10], cy = REF.h - risen;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(-f[12]);

  ctx.beginPath();
  ctx.roundRect(-CARD.w / 2, -CARD.h / 2, CARD.w, CARD.h, CARD.r);
  ctx.fillStyle = INK.parchment; ctx.fill();
  ctx.strokeStyle = 'rgba(36,36,36,0.45)'; ctx.lineWidth = 1; ctx.stroke();

  // The fill tracks the thumb to the threshold, then locks.
  const travel = Math.min(1, Math.abs(f[10]) / (REF.w * 0.3));
  const locked = travel >= 1, toLeft = f[10] < 0;
  if (Math.abs(f[10]) >= 0.5) {
    ctx.save();
    ctx.clip();
    ctx.globalAlpha = locked ? 0.30 : 0.16;
    ctx.fillStyle = INK.gold;
    const fw = CARD.w * travel;
    ctx.fillRect(toLeft ? CARD.w / 2 - fw : -CARD.w / 2, -CARD.h / 2, fw, CARD.h);
    ctx.restore();
  }

  ctx.fillStyle = SPINE[Math.max(0, Math.min(4, f[32] | 0))];
  ctx.fillRect(-129, -92, 258, 4);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = INK.ink;
  serif(ctx, 20, true);
  ctx.fillText(t.title || '', 0, -54);
  if (f[29]) {
    serif(ctx, 12, false);
    ctx.fillStyle = INK.dormant;
    ctx.fillText('your deck is spent \u2014 Death deals', 0, -34);
  }
  if (locked && !f[28]) {
    serif(ctx, 11, true);
    ctx.fillStyle = INK.priceLit;
    ctx.fillText('RELEASE TO TAKE', 0, -74);
  }

  serif(ctx, 16, false);
  ctx.textAlign = 'left';
  ctx.fillStyle = locked && toLeft ? INK.ink : INK.dormant;
  ctx.fillText('\u2190 ' + (t.leftLabel || ''), -127, 38);
  ctx.textAlign = 'right';
  ctx.fillStyle = locked && !toLeft ? INK.ink : INK.dormant;
  ctx.fillText((t.rightLabel || '') + ' \u2192', 127, 38);

  serif(ctx, 14, false);
  ctx.textAlign = 'left';
  ctx.fillStyle = locked && toLeft ? INK.priceLit : INK.priceIdle;
  wrap(ctx, t.leftSub || '', -127, 60, 118);
  ctx.textAlign = 'right';
  ctx.fillStyle = locked && !toLeft ? INK.priceLit : INK.priceIdle;
  wrap(ctx, t.rightSub || '', 127, 60, 118);

  if (f[31] >= 0) {
    const armed = f[31] === 1;
    serif(ctx, 12, false);
    ctx.textAlign = 'center';
    ctx.fillStyle = armed ? INK.gold : INK.dormant;
    ctx.fillText(armed ? '\u27e1 armed \u2014 release to swing'
                       : '\u27e1 hold \u2014 ' + (t.signature || ''), 0, 74);
    ctx.fillStyle = 'rgba(36,36,36,0.2)';
    ctx.fillRect(-60, 87, 120, 2);
    ctx.fillStyle = INK.gold;
    ctx.fillRect(-60, 87, 120 * Math.min(1, f[30] / 0.4), 2);
  }
  ctx.restore();
}

/// A long subtitle used to run past the centre and collide with its pair.
function wrap(ctx, s, x, y, max) {
  const words = s.split(' ');
  let line = '', row = 0;
  for (const w of words) {
    const next = line ? line + ' ' + w : w;
    if (ctx.measureText(next).width > max && line) {
      ctx.fillText(line, x, y + row * 15);
      line = w; row++;
    } else line = next;
  }
  if (line) ctx.fillText(line, x, y + row * 15);
}

function drawBanner(ctx, time) {
  const age = time - banner.at;
  if (age < 0 || age > 2.25) return;
  const alpha = age < 0.15 ? age / 0.15 : age > 1.85 ? Math.max(0, (2.25 - age) / 0.4) : 1;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = '#C99A2E';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  serif(ctx, 22, true);
  ctx.fillText(banner.text, REF.w / 2, REF.h * 0.4);
  ctx.restore();
}

function drawEnd(ctx, f) {
  ctx.fillStyle = 'rgba(10,6,14,0.82)';
  ctx.fillRect(0, 0, REF.w, REF.h);
  ctx.fillStyle = INK.gold;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  serif(ctx, 34, true);
  ctx.fillText('THE FOG TOOK YOU', REF.w / 2, REF.h / 2 - 20);
  serif(ctx, 16, false);
  ctx.fillText(`${Math.floor(f[1])} fathoms \u00b7 ${Math.floor(f[3])} felled`,
               REF.w / 2, REF.h / 2 + 14);
  ctx.globalAlpha = 0.6;
  serif(ctx, 13, false);
  ctx.fillText('tap to climb again', REF.w / 2, REF.h / 2 + 52);
  ctx.globalAlpha = 1;
}

export { REF };
