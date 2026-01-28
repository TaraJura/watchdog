// Push Notifications Handler
// Automatically subscribes users to push notifications when they visit the site

class PushNotificationManager {
  static VAPID_KEY_ENDPOINT = '/vapid_public_key';
  static SUBSCRIPTION_ENDPOINT = '/push_subscriptions';
  static SERVICE_WORKER_PATH = '/service-worker.js';

  constructor() {
    this.registration = null;
    this.vapidPublicKey = null;
    this.init();
  }

  async init() {
    if (!this.isPushSupported()) {
      console.log('Push notifications not supported');
      return;
    }

    try {
      await this.registerServiceWorker();
      await this.loadVapidKey();
      await this.handlePermissionState();
    } catch (error) {
      console.error('Push notification initialization failed:', error);
    }
  }

  isPushSupported() {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  }

  async registerServiceWorker() {
    this.registration = await navigator.serviceWorker.register(
      PushNotificationManager.SERVICE_WORKER_PATH
    );
    console.log('Service Worker registered successfully');
  }

  async loadVapidKey() {
    const response = await fetch(PushNotificationManager.VAPID_KEY_ENDPOINT);

    if (!response.ok) {
      throw new Error('Failed to fetch VAPID public key');
    }

    const data = await response.json();
    this.vapidPublicKey = data.publicKey;

    if (!this.vapidPublicKey) {
      throw new Error('VAPID public key not available');
    }
  }

  async handlePermissionState() {
    const permission = Notification.permission;

    switch (permission) {
      case 'default':
        await this.requestPermission();
        break;
      case 'granted':
        await this.subscribeToPush();
        break;
      case 'denied':
        console.log('Push notification permission denied');
        break;
    }
  }

  async requestPermission() {
    const permission = await Notification.requestPermission();

    if (permission === 'granted') {
      await this.subscribeToPush();
    }
  }

  async subscribeToPush() {
    try {
      await this.unsubscribeExisting();
      const subscription = await this.createSubscription();
      await this.sendSubscriptionToServer(subscription);

      console.log('Push subscription successful');
    } catch (error) {
      console.error('Failed to subscribe to push notifications:', error);
      throw error;
    }
  }

  async unsubscribeExisting() {
    const existingSubscription = await this.registration.pushManager.getSubscription();

    if (existingSubscription) {
      console.log('Unsubscribing from existing subscription');
      await existingSubscription.unsubscribe();
    }
  }

  async createSubscription() {
    return await this.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKey)
    });
  }

  async sendSubscriptionToServer(subscription) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

    const response = await fetch(PushNotificationManager.SUBSCRIPTION_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({
        subscription: {
          endpoint: subscription.endpoint,
          keys: {
            p256dh: this.arrayBufferToBase64(subscription.getKey('p256dh')),
            auth: this.arrayBufferToBase64(subscription.getKey('auth'))
          }
        }
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.errors?.join(', ') || 'Failed to save subscription');
    }
  }

  // Utility: Convert URL-safe base64 to Uint8Array
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i);
    }

    return outputArray;
  }

  // Utility: Convert ArrayBuffer to base64
  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';

    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }

    return window.btoa(binary);
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.pushNotificationManager = new PushNotificationManager();
});
