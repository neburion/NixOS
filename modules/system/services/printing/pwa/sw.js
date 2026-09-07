// The service worker exists so the browser will treat this as an installable
// app rather than a bookmark. Chromium refuses to offer "Install" without one
// registered and holding a fetch handler; iOS does not need it, but honours
// the same manifest either way.
//
// It caches nothing, deliberately. Every page here is a form whose whole
// purpose is to reach a printer sitting on the LAN, and a cached shell would
// let someone fill one in and press Send with nothing on the other end. If
// the server is unreachable there is no printing to be done, so saying so is
// the honest answer.
//
// The one thing it adds is the failure case. A navigation that cannot reach
// the server would otherwise render the browser's own error page — which,
// inside a standalone window with no address bar, is a dead end with nothing
// to press. So navigations get a small page of our own instead, with a retry.

const OFFLINE = `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark"><title>Offline</title>
<style>
  html{background:#1a1a1a;color:#e5e5e5;font:16px/1.5 system-ui,sans-serif}
  body{display:grid;place-content:center;gap:20px;min-height:100vh;margin:0;
       padding:24px;text-align:center}
  h1{font-size:19px;font-weight:600;margin:0}
  p{margin:0;color:#999;max-width:32ch}
  button{background:#2563eb;color:#fff;border:0;border-radius:6px;
         padding:11px 22px;font:inherit;font-weight:600}
</style></head><body>
<h1>Can't reach the printer</h1>
<p>The print server is unreachable, so there is nothing to send a job to.</p>
<button onclick="location.reload()">Try again</button>
</body></html>`;

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (e) => {
  if (e.request.mode !== "navigate") return;   // everything else: straight through
  e.respondWith(
    fetch(e.request).catch(() => new Response(OFFLINE, {
      status: 503,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    })),
  );
});
