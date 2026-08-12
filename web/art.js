// The drawn art, and the tables that say what a stage is made of. Ported from
// SpriteAtlas, ZoneLook and AirNode so both builds read the same look.

const images = new Map();
const tints = new Map();

export function hex(n) {
  return '#' + n.toString(16).padStart(6, '0');
}

/// Decode every inlined sprite once, before the first frame.
export async function load(sources) {
  await Promise.all(Object.entries(sources).map(async ([name, uri]) => {
    const img = new Image();
    img.src = uri;
    await img.decode();
    images.set(name, img);
  }));
}

export function sprite(name) {
  return images.get(name) || null;
}

/// A drawing under a partial colour wash, so the cross-hatching survives.
/// SpriteAtlas uses 0.62 fitted, 0.80 baked.
export function tinted(name, colour, alpha) {
  const key = `${name}|${colour}|${alpha}`;
  const hit = tints.get(key);
  if (hit) return hit;
  const img = images.get(name);
  if (!img) return null;
  const c = document.createElement('canvas');
  c.width = img.naturalWidth;
  c.height = img.naturalHeight;
  const x = c.getContext('2d');
  x.drawImage(img, 0, 0);
  if (colour !== null) {
    x.globalCompositeOperation = 'source-atop';
    x.globalAlpha = alpha;
    x.fillStyle = colour;
    x.fillRect(0, 0, c.width, c.height);
  }
  tints.set(key, c);
  return c;
}

/// Draw a sprite centred on (x, y), rotated, fitted to a box.
export function stamp(ctx, img, x, y, w, h, rot, alpha) {
  if (!img) return;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.translate(x, y);
  if (rot) ctx.rotate(rot);
  ctx.drawImage(img, -w / 2, -h / 2, w, h);
  ctx.restore();
}

/// Height-fitted size, keeping the drawing's aspect — SpriteAtlas.art.
export function fit(name, height) {
  const img = images.get(name);
  if (!img || !img.naturalHeight) return { w: height, h: height };
  return { w: (height * img.naturalWidth / img.naturalHeight), h: height };
}

// ---- what a stage is made of (ZoneLook) ---------------------------------

const MATERIAL = {
  rubble: ['boulder', 'wall-rubble-b'],
  slab: ['ground-slab'],
  briar: ['briar-bed'],
  bone: ['bone-pile'],
  masonry: ['ashlar'],
  tile: ['ashlar'],
  fog: ['wall-fog'],
  root: ['floor-roots'],
  ash: ['floor-ash'],
};

export const ZONES = [
  { id: 'low_road', wall: 'rubble', floor: 'slab', rock: 0x3A2A1C, depth: 2 },
  { id: 'orchard', wall: 'briar', floor: 'root', rock: 0x2C3018, depth: 2 },
  { id: 'ossuary', wall: 'bone', floor: 'bone', rock: 0x2E2838, depth: 2 },
  { id: 'spire', wall: 'masonry', floor: 'tile', rock: 0x3E301A, depth: 3 },
  { id: 'reckoning', wall: 'fog', floor: 'ash', rock: 0x1A1614, depth: 2 },
];

export function variants(material) {
  return MATERIAL[material] || MATERIAL.rubble;
}

// ---- the air each zone carries (AirNode) --------------------------------

export const AIR = [
  { count: 34, colour: 0x8C7A57, fall: 34, drift: 10, size: 2.2 },
  { count: 46, colour: 0xA8BA48, fall: -22, drift: 26, size: 2.4 },
  { count: 24, colour: 0xA98CD4, fall: -8, drift: 6, size: 3.0 },
  { count: 38, colour: 0xE0B84A, fall: -40, drift: 8, size: 1.8 },
  { count: 56, colour: 0xB6AAC4, fall: 52, drift: 18, size: 2.0 },
];

export const SPINE = ['#C06430', '#C99A2E', '#8A6FB3', '#8FA03A', '#050303'];

/// The graybox's own generator, so scatter that must be stable across frames
/// lands where the iOS build puts it.
export function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
