const CACHE_NAME = 'marsa-receptionist-v1';
const ASSETS = [
  '/receptionist/',
  '/receptionist/index.html',
  '/receptionist/styles.css',
  '/receptionist/app.js',
  '/receptionist/manifest.json'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.url.includes('/api/') || e.request.url.includes('/auth/')) {
    // API calls should always go to network
    return;
  }
  e.respondWith(
    caches.match(e.request).then((res) => res || fetch(e.request))
  );
});
