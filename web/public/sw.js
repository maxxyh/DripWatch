const VERSION = "dripwatch-v2";
const STATIC = `${VERSION}-static`;
const LEASE_CACHE = `${VERSION}-lease`;
const SHELL = `${VERSION}-shell`;
const LEASE_KEY = "/__dripwatch_session_lease__";

const immutable = (request) => {
  const path = new URL(request.url).pathname;
  return path.startsWith("/_next/static/") || path.startsWith("/icons/");
};
const protectedRequest = (request) => {
  const path = new URL(request.url).pathname;
  return path === "/api/notebook" || path.startsWith("/api/photos/");
};
const protectedCache = (scope) => `dripwatch-protected-${VERSION}-${scope}`;
const MAX_PROTECTED_PHOTOS = 120;
const MAX_PROTECTED_PHOTO_BYTES = 100 * 1024 * 1024;

async function setLease(lease) {
  if (!lease?.cacheScope || !Number.isFinite(lease.expiresAt)) return;
  const cache = await caches.open(LEASE_CACHE);
  const keys = await caches.keys();
  await Promise.all(
    keys
      .filter(
        (key) =>
          key.startsWith(`dripwatch-protected-${VERSION}-`) &&
          key !== protectedCache(lease.cacheScope),
      )
      .map((key) => caches.delete(key)),
  );
  await cache.put(
    LEASE_KEY,
    new Response(JSON.stringify(lease), {
      headers: { "Content-Type": "application/json" },
    }),
  );
}
async function pruneProtectedPhotos(cache) {
  const requests = (await cache.keys()).filter((request) =>
    new URL(request.url).pathname.startsWith("/api/photos/"),
  );
  const entries = await Promise.all(
    requests.map(async (request) => {
      const response = await cache.match(request);
      return {
        request,
        bytes: Number(response?.headers.get("x-dripwatch-bytes")) || 0,
        cachedAt: Number(response?.headers.get("x-dripwatch-cached-at")) || 0,
      };
    }),
  );
  entries.sort((a, b) => a.cachedAt - b.cachedAt);
  let bytes = entries.reduce((sum, entry) => sum + entry.bytes, 0);
  while (
    entries.length > MAX_PROTECTED_PHOTOS ||
    bytes > MAX_PROTECTED_PHOTO_BYTES
  ) {
    const oldest = entries.shift();
    if (!oldest) break;
    bytes -= oldest.bytes;
    await cache.delete(oldest.request);
  }
}
async function getLease() {
  const response = await (await caches.open(LEASE_CACHE)).match(LEASE_KEY);
  if (!response) return null;
  const lease = await response.json();
  return lease.expiresAt > Date.now() ? lease : null;
}
async function clearProtected() {
  const keys = await caches.keys();
  await Promise.all(
    keys
      .filter(
        (key) => key.startsWith("dripwatch-protected-") || key === LEASE_CACHE,
      )
      .map((key) => caches.delete(key)),
  );
}

self.addEventListener("install", (event) =>
  event.waitUntil(
    caches
      .open(STATIC)
      .then((cache) =>
        cache.addAll([
          "/login",
          "/manifest.webmanifest",
          "/icons/icon-192.png",
          "/icons/icon-512.png",
        ]),
      ),
  ),
);
self.addEventListener("activate", (event) =>
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) =>
                key.startsWith("dripwatch-") &&
                key !== STATIC &&
                key !== LEASE_CACHE &&
                !key.startsWith(`dripwatch-protected-${VERSION}-`),
            )
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  ),
);
self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (
    request.method !== "GET" ||
    url.origin !== self.location.origin ||
    url.pathname.startsWith("/api/auth/") ||
    url.searchParams.has("_rsc") ||
    request.headers.get("accept")?.includes("text/x-component")
  )
    return;
  if (immutable(request)) {
    event.respondWith(
      caches.open(STATIC).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        const response = await fetch(request);
        if (response.ok) await cache.put(request, response.clone());
        return response;
      }),
    );
    return;
  }
  if (protectedRequest(request)) {
    event.respondWith(
      (async () => {
        const lease = await getLease();
        try {
          const response = await fetch(request);
          if (response.status === 401 || response.status === 403) {
            await clearProtected();
            return response;
          }
          if (response.ok && lease && !response.headers.has("set-cookie")) {
            try {
              const cache = await caches.open(protectedCache(lease.cacheScope));
              let cached = response.clone();
              if (url.pathname.startsWith("/api/photos/")) {
                const bytes = await cached.arrayBuffer();
                const headers = new Headers(cached.headers);
                headers.set("X-DripWatch-Cached-At", String(Date.now()));
                headers.set("X-DripWatch-Bytes", String(bytes.byteLength));
                cached = new Response(bytes, {
                  status: cached.status,
                  statusText: cached.statusText,
                  headers,
                });
              }
              await cache.put(request, cached);
              if (url.pathname.startsWith("/api/photos/"))
                await pruneProtectedPhotos(cache);
            } catch {
              // Offline caching is best-effort; never mask a valid network response.
            }
          }
          return response;
        } catch {
          if (lease) {
            const cached = await (
              await caches.open(protectedCache(lease.cacheScope))
            ).match(request);
            if (cached) {
              const headers = new Headers(cached.headers);
              headers.set("X-DripWatch-Offline-Fallback", "true");
              return new Response(await cached.arrayBuffer(), {
                status: cached.status,
                statusText: cached.statusText,
                headers,
              });
            }
          }
          return new Response("Offline session unavailable", { status: 503 });
        }
      })(),
    );
    return;
  }
  if (request.mode === "navigate" && url.pathname !== "/login") {
    event.respondWith(
      fetch(request)
        .then(async (response) => {
          if (response.ok && !response.headers.has("set-cookie"))
            await (await caches.open(SHELL)).put(request, response.clone());
          return response;
        })
        .catch(async () => {
          const lease = await getLease();
          if (!lease) return (await caches.match("/login")) ?? Response.error();
          return (
            (await (await caches.open(SHELL)).match(request)) ??
            (await caches.match("/login")) ??
            Response.error()
          );
        }),
    );
  }
});
self.addEventListener("message", (event) => {
  if (event.data?.type === "SET_SESSION_LEASE")
    event.waitUntil(setLease(event.data.lease));
  if (event.data?.type === "CLEAR_PROTECTED_DATA")
    event.waitUntil(clearProtected());
});
