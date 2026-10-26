// FamilyToStudy Service Worker (iOS 16.4+ Web Push & Multi-Device Notification Engine)
const CACHE_NAME = 'family-to-study-v2';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      )
    ).then(() => self.clients.claim())
  );
});

// Handle Web Push Notifications (Wake-Up Alarms, Shield Violations, Flash Quests)
self.addEventListener('push', (event) => {
  let payload = {
    title: 'FamilyToStudy Bildirimi',
    body: 'Yeni bir aile etkinliği var!',
    tag: 'family-sync',
    requireInteraction: true,
  };

  if (event.data) {
    try {
      payload = { ...payload, ...event.data.json() };
    } catch (e) {
      payload.body = event.data.text();
    }
  }

  const scopeUrl = self.registration.scope || '/';
  const iconUrl = new URL('./icon.svg', scopeUrl).href;

  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: iconUrl,
      badge: iconUrl,
      tag: payload.tag,
      vibrate: [200, 100, 200, 100, 400],
      requireInteraction: payload.requireInteraction,
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      if (clientList.length > 0) {
        return clientList[0].focus();
      }
      return self.clients.openWindow(self.registration.scope || '/');
    })
  );
});
