// ═══════════════════════════════════════════════════════════════
//  TreasureWorld — service worker (application installable + hors ligne)
//  Changer VERSION à chaque mise à jour du site pour renouveler le cache.
// ═══════════════════════════════════════════════════════════════
const VERSION = 'tw-v9';
const APP_CACHE = `${VERSION}-app`;      // l'application elle-même
const LIB_CACHE = 'tw-libs-v1';          // bibliothèques externes (adresses versionnées)
const TILE_CACHE = 'tw-tiles-v1';        // tuiles de carte satellite déjà vues
const MAX_TILES = 400;

const APP_FILES = [
  './', './index.html', './i18n.js', './manifest.webmanifest',
  './icons/icon-192.png', './icons/icon-512.png', './icons/favicon-32.png', './icons/apple-touch-icon.png',
];
const LIB_HOSTS = ['cdnjs.cloudflare.com', 'cdn.jsdelivr.net'];
const TILE_HOST = 'server.arcgisonline.com';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(APP_CACHE).then((c) => c.addAll(APP_FILES)));
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const keep = [APP_CACHE, LIB_CACHE, TILE_CACHE];
    for (const k of await caches.keys()) if (!keep.includes(k)) await caches.delete(k);
    await self.clients.claim();
  })());
});

// La page demande d'activer tout de suite la nouvelle version
self.addEventListener('message', (e) => { if (e.data === 'skipWaiting') self.skipWaiting(); });

async function trimTiles() {
  const c = await caches.open(TILE_CACHE);
  const keys = await c.keys();
  for (let i = 0; i < keys.length - MAX_TILES; i++) await c.delete(keys[i]);
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Données et connexion Supabase : jamais en cache (scores, réponses, comptes toujours à jour)
  if (url.hostname.endsWith('supabase.co')) return;

  // Tuiles satellite : depuis le cache si déjà vues (cartes disponibles avec peu de réseau)
  if (url.hostname === TILE_HOST) {
    e.respondWith((async () => {
      const c = await caches.open(TILE_CACHE);
      const hit = await c.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok || res.type === 'opaque') { c.put(req, res.clone()); trimTiles(); }
      return res;
    })());
    return;
  }

  // Bibliothèques (Leaflet, Supabase, QR…) : adresses à version fixe → cache d'abord
  if (LIB_HOSTS.includes(url.hostname)) {
    e.respondWith((async () => {
      const c = await caches.open(LIB_CACHE);
      const hit = await c.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok || res.type === 'opaque') c.put(req, res.clone());
      return res;
    })());
    return;
  }

  // Fichiers du site : réseau d'abord (toujours la dernière version), cache si hors ligne
  if (url.origin === self.location.origin) {
    e.respondWith((async () => {
      const c = await caches.open(APP_CACHE);
      try {
        const res = await fetch(req);
        if (res.ok) c.put(req, res.clone());
        return res;
      } catch {
        return (await c.match(req, { ignoreSearch: true }))
          || (req.mode === 'navigate' ? await c.match('./index.html') : Response.error());
      }
    })());
  }
});
