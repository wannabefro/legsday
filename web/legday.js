// The browser half of LEGDAY. It owns pixels and touches; it owns no rules.
// Every number it draws came out of the Swift sim across the wasm boundary.

const REF = { w: 393, h: 852 };      // the sim's reference space, in points
const HEADER = 20;                    // frame buffer header length

// A reactor module still expects WASI. Nothing here touches a real file.
function wasiShim() {
  const ok = () => 0;
  const bad = () => 8;                // EBADF: there is no filesystem
  return {
    args_get: ok, args_sizes_get: (c, s) => { view().setUint32(c, 0, true); view().setUint32(s, 0, true); return 0; },
    environ_get: ok, environ_sizes_get: (c, s) => { view().setUint32(c, 0, true); view().setUint32(s, 0, true); return 0; },
    fd_close: bad, fd_fdstat_get: bad, fd_prestat_get: bad, fd_prestat_dir_name: bad,
    fd_read: bad, fd_seek: bad, path_open: bad,
    fd_write: (fd, iovs, n, out) => {
      // Swift prints diagnostics on stderr; forward them and claim success.
      const v = view(); let written = 0, text = '';
      for (let i = 0; i < n; i++) {
        const p = v.getUint32(iovs + i * 8, true), len = v.getUint32(iovs + i * 8 + 4, true);
        text += new TextDecoder().decode(new Uint8Array(memory.buffer, p, len));
        written += len;
      }
      if (text.trim()) console.log('[sim]', text.trim());
      v.setUint32(out, written, true);
      return 0;
    },
    proc_exit: (code) => { throw new Error('sim exited: ' + code); },
    random_get: (p, n) => { crypto.getRandomValues(new Uint8Array(memory.buffer, p, n)); return 0; },
  };
}

let memory, wasm;
const view = () => new DataView(memory.buffer);

export async function boot(wasmBytes, tunables, seed) {
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wasiShim(),
  });
  memory = instance.exports.memory;
  wasm = instance.exports;
  wasm._initialize();
  wasm.legday_boot();
  // Tunables cross as raw doubles, in tunables.json order.
  const inbox = new Float64Array(memory.buffer, wasm.legday_inbox(), 32);
  tunables.forEach((v, i) => { inbox[i] = v; });
  wasm.legday_start(BigInt(seed), REF.w, REF.h);
}

/// Matches `Layout.capacity` in Bridge.swift.
const FRAME = 20 + 200 * 4 + 300 * 3 + 80 * 5 + 60 * 4;

export function tick(dt, phase, x, y) {
  wasm.legday_tick(dt, phase, x, y);
  // Growing the sim's memory detaches the old buffer, so re-read it each frame.
  return new Float64Array(memory.buffer, wasm.legday_frame(), FRAME);
}

export function text() {
  const bytes = new Uint8Array(memory.buffer, wasm.legday_text(), 4096);
  const end = bytes.indexOf(0);
  try { return JSON.parse(new TextDecoder().decode(bytes.subarray(0, end))); }
  catch { return {}; }
}

// ---- rendering ----------------------------------------------------------

const IN = {                          // the storybook's ink
  rock: '#151119', wall: '#241d2c', lip: '#3b3047', spine: '#2c2436',
  fog: '#6b4f8f', mote: '#ffd98a', foe: '#0d0a10', elite: '#7a1f2b',
  hero: '#ffe29e', gold: '#d8a53c', paper: '#efe6d2', ink: '#1a1520',
};

export function draw(ctx, f, t, size) {
  const s = Math.min(size.w / REF.w, size.h / REF.h);
  ctx.setTransform(s, 0, 0, s, (size.w - REF.w * s) / 2, (size.h - REF.h * s) / 2);
  ctx.clearRect(0, 0, REF.w, REF.h);

  const nFoe = f[15], nMote = f[16], nBand = f[17], nFeat = f[18];
  let p = HEADER + nFoe * 4;
  const motesAt = p; p += nMote * 3;
  const bandsAt = p; p += nBand * 5;
  const featAt = p;

  ctx.fillStyle = IN.rock;
  ctx.fillRect(0, 0, REF.w, REF.h);
  drawGorge(ctx, f, bandsAt, nBand);
  drawFeatures(ctx, f, featAt, nFeat);

  for (let i = 0; i < nMote; i++) {
    const x = f[motesAt + i * 3], y = f[motesAt + i * 3 + 1], r = f[motesAt + i * 3 + 2];
    ctx.fillStyle = IN.mote;
    ctx.globalAlpha = 0.9;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill();
    ctx.globalAlpha = 1;
  }
  for (let i = 0; i < nFoe; i++) {
    const x = f[HEADER + i * 4], y = f[HEADER + i * 4 + 1];
    const r = f[HEADER + i * 4 + 2], elite = f[HEADER + i * 4 + 3];
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    ctx.beginPath(); ctx.arc(x, y, r * 1.9, 0, 7); ctx.fill();
    ctx.fillStyle = elite ? IN.elite : IN.foe;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill();
    // Ink on near-black ink is invisible, so the lantern catches a rim.
    ctx.strokeStyle = elite ? '#e08a94' : 'rgba(255,226,158,0.55)';
    ctx.lineWidth = elite ? 2 : 1.5;
    ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.stroke();
  }
  drawHero(ctx, f);
  drawFog(ctx, f[4]);
  drawHud(ctx, f, t);
  if (f[9]) drawCard(ctx, f, t);
  if (f[8]) drawEnd(ctx, f);
}

function drawGorge(ctx, f, at, n) {
  if (n < 2) return;
  const band = (i) => ({
    y: f[at + i * 5], l: f[at + i * 5 + 1], r: f[at + i * 5 + 2],
    sl: f[at + i * 5 + 3], sr: f[at + i * 5 + 4],
  });
  // The wall is everything outside the channel, drawn as one filled band each.
  ctx.fillStyle = IN.wall;
  ctx.beginPath(); ctx.moveTo(0, band(0).y);
  for (let i = 0; i < n; i++) ctx.lineTo(band(i).l, band(i).y);
  ctx.lineTo(0, band(n - 1).y); ctx.closePath(); ctx.fill();
  ctx.beginPath(); ctx.moveTo(REF.w, band(0).y);
  for (let i = 0; i < n; i++) ctx.lineTo(band(i).r, band(i).y);
  ctx.lineTo(REF.w, band(n - 1).y); ctx.closePath(); ctx.fill();

  // The lip is the line you must not cross, so it reads brighter than the mass.
  ctx.strokeStyle = IN.lip; ctx.lineWidth = 2;
  for (const side of ['l', 'r']) {
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const b = band(i);
      i ? ctx.lineTo(b[side], b.y) : ctx.moveTo(b[side], b.y);
    }
    ctx.stroke();
  }
  // A fork's island, where the channel carries one.
  ctx.fillStyle = IN.spine;
  let open = false;
  ctx.beginPath();
  for (let i = 0; i < n; i++) {
    const b = band(i);
    if (b.sl < 0) { if (open) { ctx.closePath(); ctx.fill(); open = false; ctx.beginPath(); } continue; }
    if (!open) { ctx.moveTo(b.sl, b.y); open = true; } else ctx.lineTo(b.sl, b.y);
  }
  for (let i = n - 1; i >= 0; i--) { const b = band(i); if (b.sr >= 0) ctx.lineTo(b.sr, b.y); }
  if (open) { ctx.closePath(); ctx.fill(); }
}

function drawFeatures(ctx, f, at, n) {
  for (let i = 0; i < n; i++) {
    const x = f[at + i * 4], y = f[at + i * 4 + 1];
    const e = f[at + i * 4 + 2], cairn = f[at + i * 4 + 3];
    if (cairn) {
      ctx.fillStyle = IN.spine;
      ctx.fillRect(x - e, y - e, e * 2, e * 2);
      ctx.strokeStyle = IN.lip; ctx.lineWidth = 1;
      ctx.strokeRect(x - e, y - e, e * 2, e * 2);
    } else {
      ctx.strokeStyle = '#4a3f2a'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(x, y, e, 0, 7); ctx.stroke();
    }
  }
}

function drawHero(ctx, f) {
  const x = f[5], y = f[6];
  const glow = ctx.createRadialGradient(x, y, 2, x, y, 120);
  glow.addColorStop(0, 'rgba(255,226,158,0.30)');
  glow.addColorStop(1, 'rgba(255,226,158,0)');
  ctx.fillStyle = glow;
  ctx.beginPath(); ctx.arc(x, y, 120, 0, 7); ctx.fill();
  ctx.globalAlpha = f[14] > 0 ? 0.55 : 1;   // i-frames blink
  ctx.fillStyle = IN.hero;
  ctx.beginPath(); ctx.arc(x, y, 9, 0, 7); ctx.fill();
  ctx.globalAlpha = 1;
}

function drawFog(ctx, line) {
  const g = ctx.createLinearGradient(0, line - 40, 0, REF.h);
  g.addColorStop(0, 'rgba(107,79,143,0)');
  g.addColorStop(0.35, 'rgba(107,79,143,0.75)');
  g.addColorStop(1, 'rgba(30,18,44,0.98)');
  ctx.fillStyle = g;
  ctx.fillRect(0, line - 40, REF.w, REF.h - line + 40);
  ctx.strokeStyle = 'rgba(190,160,230,0.5)'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(0, line); ctx.lineTo(REF.w, line); ctx.stroke();
}

function drawHud(ctx, f, t) {
  ctx.fillStyle = IN.gold;
  ctx.font = '600 15px ui-serif, Georgia, serif';
  ctx.textAlign = 'left';
  ctx.fillText(`${Math.floor(f[1])} fathoms`, 14, 30);
  ctx.textAlign = 'right';
  ctx.fillText(`${Math.floor(f[2])} essence`, REF.w - 14, 30);
  ctx.textAlign = 'center';
  ctx.globalAlpha = 0.55;
  ctx.font = '400 11px ui-serif, Georgia, serif';
  // Escaped, not literal: the page has no charset declaration to rely on.
  ctx.fillText(`${t.stage || ''} \u00b7 ${Math.floor(f[3])} felled`, REF.w / 2, 30);
  ctx.globalAlpha = 1;
  // The charge bar is the promise of the next card.
  ctx.fillStyle = 'rgba(216,165,60,0.25)';
  ctx.fillRect(14, 38, REF.w - 28, 3);
  ctx.fillStyle = IN.gold;
  ctx.fillRect(14, 38, (REF.w - 28) * Math.min(1, f[19]), 3);
}

function drawCard(ctx, f, t) {
  const rise = f[11], off = f[10], tilt = f[12];
  const w = 300, h = 380;
  const cx = REF.w / 2 + off, cy = REF.h / 2 + (1 - rise) * 260;
  ctx.save();
  ctx.globalAlpha = Math.min(1, rise * 1.4);
  ctx.translate(cx, cy); ctx.rotate(tilt);
  ctx.fillStyle = IN.paper;
  ctx.fillRect(-w / 2, -h / 2, w, h);
  ctx.fillStyle = t.death ? '#1a1520' : IN.gold;
  ctx.fillRect(-w / 2, -h / 2, 8, h);
  ctx.fillStyle = IN.ink;
  ctx.textAlign = 'center';
  ctx.font = '600 20px ui-serif, Georgia, serif';
  ctx.fillText(t.title || '', 0, -h / 2 + 48);
  // The side the thumb is choosing lights up; the other stays quiet.
  const pick = Math.abs(off) > REF.w * 0.3 ? Math.sign(off) : 0;
  const side = (label, sub, dx, lit) => {
    ctx.globalAlpha = lit ? 1 : 0.35;
    ctx.font = '600 15px ui-serif, Georgia, serif';
    ctx.fillText(label || '', dx, 40);
    ctx.font = '400 11px ui-serif, Georgia, serif';
    ctx.fillText(sub || '', dx, 60);
    ctx.globalAlpha = 1;
  };
  side(t.leftLabel, t.leftSub, -w / 4, pick <= 0);
  side(t.rightLabel, t.rightSub, w / 4, pick >= 0);
  ctx.globalAlpha = 0.4;
  ctx.font = '400 10px ui-serif, Georgia, serif';
  ctx.fillText('drag the card', 0, h / 2 - 26);
  ctx.restore();
}

function drawEnd(ctx, f) {
  ctx.fillStyle = 'rgba(10,6,14,0.82)';
  ctx.fillRect(0, 0, REF.w, REF.h);
  ctx.fillStyle = IN.gold;
  ctx.textAlign = 'center';
  ctx.font = '600 34px ui-serif, Georgia, serif';
  ctx.fillText('THE FOG TOOK YOU', REF.w / 2, REF.h / 2 - 20);
  ctx.font = '400 16px ui-serif, Georgia, serif';
  ctx.fillText(`${Math.floor(f[1])} fathoms \u00b7 ${Math.floor(f[3])} felled`, REF.w / 2, REF.h / 2 + 14);
  ctx.globalAlpha = 0.6;
  ctx.font = '400 13px ui-serif, Georgia, serif';
  ctx.fillText('tap to climb again', REF.w / 2, REF.h / 2 + 52);
  ctx.globalAlpha = 1;
}

export { REF };
