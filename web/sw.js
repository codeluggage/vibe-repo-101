// The service worker. The build stamps the version and the file list.
// One cache per build, named per site so two sites on one origin keep apart.
const PREFIX = `app ${self.registration.scope} `;
const CACHE = PREFIX + "__VERSION__";
const FILES = __FILES__;

self.addEventListener("install", (event) => {
  // Bypass the HTTP cache so a new build never caches an old file.
  const requests = FILES.map((file) => new Request(file, { cache: "reload" }));
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(requests)));
});

self.addEventListener("activate", (event) => {
  const old = (name) => name.startsWith(PREFIX) && name !== CACHE;
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.filter(old).map((name) => caches.delete(name))))
      .then(() => self.clients.claim()),
  );
});

// The page sends this when the reader presses Reload.
self.addEventListener("message", (event) => {
  if (event.data === "skip-waiting") self.skipWaiting();
});

// Cache first. Anything not cached (version.json) goes to the network.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.open(CACHE)
      .then((cache) => cache.match(event.request))
      .then((cached) => cached ?? fetch(event.request)),
  );
});
