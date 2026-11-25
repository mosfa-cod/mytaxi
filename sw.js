// Service Worker بسيط لخطّي — يدعم التثبيت والعمل بدون إنترنت للهيكل الأساسي
const CACHE = 'khatti-v2';
const SHELL = ['./', './index.html', './manifest.json', './icon.svg', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // لا نتدخل في Supabase (API + Realtime) ولا في الخرائط/التحديد الجغرافي
  if (/supabase\.(co|in)$/.test(url.hostname) || url.hostname.includes('nominatim') || url.hostname.endsWith('tile.openstreetmap.org')) return;

  // التنقل بين الصفحات: الشبكة أولاً ثم النسخة المخزنة (يدعم ?driver=CODE)
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put('./index.html', copy));
        return res;
      }).catch(() => caches.match('./index.html', { ignoreSearch: true }))
    );
    return;
  }

  // باقي الموارد (ملفات الموقع + CDN): من الكاش مع تحديث في الخلفية
  e.respondWith(
    caches.match(req).then(cached => {
      const net = fetch(req).then(res => {
        if (res && (res.ok || res.type === 'opaque')) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy));
        }
        return res;
      }).catch(() => cached);
      return cached || net;
    })
  );
});
