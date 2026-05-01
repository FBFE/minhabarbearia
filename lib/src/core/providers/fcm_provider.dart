import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'barber_shop_providers.dart';
import 'firebase_providers.dart';

/// Chave pública VAPID (Web Push) do Firebase — Console → Engrenagem do projeto → Cloud Messaging
/// → *Certificados push da Web* (par de chaves). A chave é uma string base64 contínua, **sem ponto** no meio.
/// Build com override: `flutter build web --dart-define=FIREBASE_VAPID_KEY=sua_chave`
const String kFcmVapidKey = String.fromEnvironment(
  'FIREBASE_VAPID_KEY',
  defaultValue:
      'BF1jTkpJ06t0p_zByV0dZSjadwLDyUpuBD5y6FcxFEB82tFaJO0y6EdWvDvSMi7Pdd73OSj-D0PTTkpFb2R_khQ',
);

/// Solicita permissão de notificação e retorna o token FCM (só web).
/// Retorna null se não for web, permissão negada ou erro.
Future<String?> requestFcmTokenAndPermission() async {
  if (!kIsWeb) return null;
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      if (kDebugMode) {
        debugPrint('FCM: permissão de notificação recusada (${settings.authorizationStatus})');
      }
      return null;
    }
    if (kFcmVapidKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('FCM: FIREBASE_VAPID_KEY / kFcmVapidKey vazia.');
      }
      return null;
    }
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kFcmVapidKey,
    );
    return token;
  } on PlatformException catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM getToken PlatformException: ${e.message} $st');
    }
    return null;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('FCM getToken erro: $e $st');
    }
    return null;
  }
}

/// Solicita permissão, grava o token FCM: dono (todos [barbershops] com `ownerUid` = user atual) e, se houver, cliente.
/// [clientSlug] + [clientId] quando a sessão pública tiver id do cliente (subcoleção `clients`).
Future<WebNotificationRegisterResult> requestAndRegisterWebNotifications({
  String? clientSlug,
  String? clientId,
}) async {
  if (!kIsWeb) {
    return const WebNotificationRegisterResult(
      success: false,
      ownerShopsUpdated: 0,
      clientSaved: false,
    );
  }
  final token = await requestFcmTokenAndPermission();
  if (token == null) {
    return const WebNotificationRegisterResult(
      success: false,
      ownerShopsUpdated: 0,
      clientSaved: false,
    );
  }

  final fs = FirebaseFirestore.instance;
  var ownerCount = 0;
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final q = await fs
        .collection(barbershopsCollection)
        .where('ownerUid', isEqualTo: user.uid)
        .get();
    for (final d in q.docs) {
      await d.reference.update({
        'ownerFcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ownerCount++;
    }
  }

  var clientSaved = false;
  if (clientSlug != null && clientId != null && clientId.isNotEmpty) {
    try {
      await fs
          .collection(barbershopsCollection)
          .doc(clientSlug)
          .collection('clients')
          .doc(clientId)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      clientSaved = true;
    } catch (_) {
      // doc inexistente ou regras
    }
  }

  return WebNotificationRegisterResult(
    success: true,
    ownerShopsUpdated: ownerCount,
    clientSaved: clientSaved,
  );
}

class WebNotificationRegisterResult {
  const WebNotificationRegisterResult({
    required this.success,
    required this.ownerShopsUpdated,
    required this.clientSaved,
  });
  final bool success;
  final int ownerShopsUpdated;
  final bool clientSaved;
}

/// Salva o token FCM do dono em Firestore (barbershops/{slug}.ownerFcmTokens — array, múltiplos dispositivos).
Future<void> saveOwnerFcmToken(WidgetRef ref, String slug, String token) async {
  final firestore = ref.read(firestoreProvider);
  await firestore.collection(barbershopsCollection).doc(slug).update({
    'ownerFcmTokens': FieldValue.arrayUnion([token]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// Salva o token FCM do cliente em Firestore (barbershops/{slug}/clients/{clientId}.fcmTokens — array).
Future<void> saveClientFcmToken(
  WidgetRef ref,
  String slug,
  String clientId,
  String token,
) async {
  final firestore = ref.read(firestoreProvider);
  await firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('clients')
      .doc(clientId)
      .update({
    'fcmTokens': FieldValue.arrayUnion([token]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
