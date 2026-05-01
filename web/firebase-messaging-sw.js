// Service worker para FCM (notificações push na PWA). Deve bater com lib/firebase_options.dart (flow-studio-10).
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCurfC_iBx3NvV171_L6B7eW622v7MJT1M',
  authDomain: 'flow-studio-10.firebaseapp.com',
  projectId: 'flow-studio-10',
  storageBucket: 'flow-studio-10.firebasestorage.app',
  messagingSenderId: '230015480544',
  appId: '1:230015480544:web:c3446aa8d6906e6b155685',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || payload.data?.title || 'Studio 10';
  const options = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/favicon.png',
    badge: '/favicon.png',
    tag: payload.data?.tag || 'minhabarbearia',
    data: payload.data || {},
  };
  return self.registration.showNotification(title, options);
});
