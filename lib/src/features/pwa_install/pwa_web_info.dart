// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Deteção PWA / browser (só [kIsWeb]).
bool get pwaIsWeb => kIsWeb;

bool get pwaIsStandalonePwa {
  if (!kIsWeb) {
    return false;
  }
  try {
    if (html.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
  } catch (_) {}
  return false;
}

/// Rota pública com slug `/b/...` (usePathUrlStrategy).
bool get pwaPathIsClientArea {
  if (!kIsWeb) {
    return false;
  }
  final p = html.window.location.pathname ?? '';
  return p == '/b' || p.startsWith('/b/');
}

/// Cliente final (agenda, login cliente, etc.) — **não** inclui área de funcionário `/funcionario`.
bool get pwaPathIsBookingClientArea {
  if (!kIsWeb) {
    return false;
  }
  final p = html.window.location.pathname ?? '';
  if (p == '/b' || p == '/b/') {
    return false;
  }
  if (!p.startsWith('/b/')) {
    return false;
  }
  if (p.contains('/funcionario')) {
    return false;
  }
  return true;
}

bool get pwaIsLikelyIOS {
  if (!kIsWeb) {
    return false;
  }
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
}

bool get pwaIsAndroidPhone {
  if (!kIsWeb) {
    return false;
  }
  final ua = html.window.navigator.userAgent;
  if (!ua.toLowerCase().contains('android')) {
    return false;
  }
  return ua.contains('Mobile') || !ua.toLowerCase().contains('windows');
}

String get pwaWebNotificationPermission {
  if (!kIsWeb) {
    return 'denied';
  }
  try {
    if (html.Notification.supported) {
      return html.Notification.permission ?? 'default';
    }
  } catch (_) {}
  return 'denied';
}

bool get pwaWebNotificationsGranted =>
    kIsWeb && pwaWebNotificationPermission == 'granted';
