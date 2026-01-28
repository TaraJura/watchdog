// Service Worker for Push Notifications
// Handles incoming push notifications and user interactions

const DEFAULT_NOTIFICATION = {
  title: 'Watchdog - Nový inzerát',
  body: 'Byl přidán nový inzerát na Bazos nebo Sauto',
  icon: '/icon.svg',
  url: '/'
};

const NOTIFICATION_OPTIONS = {
  requireInteraction: true,
  vibrate: [200, 100, 200]
};

// Handle push notification reception
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push notification received');

  const notificationData = parsePushData(event.data);
  const notification = buildNotification(notificationData);

  event.waitUntil(
    self.registration.showNotification(notification.title, notification.options)
  );
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notification clicked');

  event.notification.close();

  const targetUrl = event.notification.data?.url || DEFAULT_NOTIFICATION.url;

  event.waitUntil(
    focusOrOpenWindow(targetUrl)
  );
});

// Service Worker lifecycle events
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(clients.claim());
});

// Helper Functions

function parsePushData(data) {
  if (!data) {
    return {};
  }

  try {
    return data.json();
  } catch (error) {
    console.warn('[Service Worker] Failed to parse push data as JSON:', error);
    return { body: data.text() };
  }
}

function buildNotification(data) {
  return {
    title: data.title || DEFAULT_NOTIFICATION.title,
    options: {
      body: data.body || DEFAULT_NOTIFICATION.body,
      icon: data.icon || DEFAULT_NOTIFICATION.icon,
      image: data.image,
      data: {
        url: data.url || DEFAULT_NOTIFICATION.url,
        timestamp: Date.now()
      },
      ...NOTIFICATION_OPTIONS
    }
  };
}

async function focusOrOpenWindow(url) {
  const clientList = await clients.matchAll({
    type: 'window',
    includeUncontrolled: true
  });

  // Try to focus existing window with the same URL
  for (const client of clientList) {
    if (client.url === url && 'focus' in client) {
      return client.focus();
    }
  }

  // Open new window if no matching client found
  if (clients.openWindow) {
    return clients.openWindow(url);
  }
}
