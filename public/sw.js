// FamilyToStudy Service Worker (iOS 16.4+ Web Push & Multi-Device Notification Engine)
const CACHE_NAME = 'family-to-study-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
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

  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: '/icon.svg',
      badge: '/icon.svg',
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
      return self.clients.openWindow('/');
    })
  );
});
