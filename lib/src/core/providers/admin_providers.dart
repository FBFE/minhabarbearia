import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Uma linha de atividade de reembolso por negócio (contagem na subcoleção billingEvents).
class AdminRefundRow {
  const AdminRefundRow({
    required this.slug,
    required this.name,
    required this.refundCount,
    this.lastRefundAt,
  });
  final String slug;
  final String name;
  final int refundCount;
  final String? lastRefundAt;

  static AdminRefundRow fromMap(Map<String, dynamic> map) {
    return AdminRefundRow(
      slug: map['slug'] as String? ?? '',
      name: map['name'] as String? ?? '',
      refundCount: _parseIntSafe(map['refundCount']),
      lastRefundAt: map['lastRefundAt'] as String?,
    );
  }
}

/// Métricas agregadas vindas da Cloud Function (Firestore + Auth).
class AdminSummary {
  const AdminSummary({
    required this.totalBusinesses,
    required this.businessesWithProAccess,
    required this.subscriptionActiveCount,
    required this.activeStripeBackedCount,
    required this.onTrialCount,
    required this.refundedCount,
    required this.pastDueCount,
    required this.registeredEndClientsTotal,
    required this.firebaseAuthUserCount,
    required this.firebaseAuthUserCountProduction,
    required this.totalSubscriptionRevenueCents,
    this.currency = 'brl',
    this.refundActivity = const [],
  });
  final int totalBusinesses;
  final int businessesWithProAccess;
  final int subscriptionActiveCount;
  final int activeStripeBackedCount;
  final int onTrialCount;
  final int refundedCount;
  final int pastDueCount;
  final int registeredEndClientsTotal;
  final int firebaseAuthUserCount;
  final int firebaseAuthUserCountProduction;
  final int totalSubscriptionRevenueCents;
  final String currency;
  final List<AdminRefundRow> refundActivity;

  static AdminSummary? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final refundList = map['refundActivity'] as List<dynamic>?;
    final subscriptionActive = _parseIntSafe(map['subscriptionActiveCount']);
    return AdminSummary(
      totalBusinesses: _parseIntSafe(map['totalBusinesses']),
      businessesWithProAccess: _parseIntSafe(map['businessesWithProAccess']),
      subscriptionActiveCount: subscriptionActive,
      activeStripeBackedCount: map.containsKey('activeStripeBackedCount')
          ? _parseIntSafe(map['activeStripeBackedCount'])
          : subscriptionActive,
      onTrialCount: _parseIntSafe(map['onTrialCount']),
      refundedCount: _parseIntSafe(map['refundedCount']),
      pastDueCount: _parseIntSafe(map['pastDueCount']),
      registeredEndClientsTotal: _parseIntSafe(map['registeredEndClientsTotal']),
      firebaseAuthUserCount: _parseIntSafe(map['firebaseAuthUserCount']),
      firebaseAuthUserCountProduction: map.containsKey('firebaseAuthUserCountProduction')
          ? _parseIntSafe(map['firebaseAuthUserCountProduction'])
          : _parseIntSafe(map['firebaseAuthUserCount']),
      totalSubscriptionRevenueCents: _parseIntSafe(map['totalSubscriptionRevenueCents']),
      currency: map['currency'] as String? ?? 'brl',
      refundActivity: refundList
              ?.map(
                (e) => AdminRefundRow.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }
}

int _parseIntSafe(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? fallback;
}

/// Dados do painel de administração: isAdmin e lista de barbearias (só preenchido se isAdmin).
class AdminDashboardData {
  const AdminDashboardData({
    required this.isAdmin,
    this.barberShops = const [],
    this.summary,
    this.error,
  });
  final bool isAdmin;
  final List<AdminBarberShopItem> barberShops;
  final AdminSummary? summary;
  final String? error;
}

class AdminBarberShopItem {
  const AdminBarberShopItem({
    required this.id,
    required this.name,
    required this.slug,
    this.ownerUid,
    this.plan = 'basic',
    this.subscriptionStatus = 'trial',
    this.createdAt,
    this.trialEndsAt,
  });
  final String id;
  final String name;
  final String slug;
  final String? ownerUid;
  final String plan;
  final String subscriptionStatus;
  final String? createdAt;
  final String? trialEndsAt;

  static AdminBarberShopItem fromMap(Map<String, dynamic> map) {
    return AdminBarberShopItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      ownerUid: map['ownerUid'] as String?,
      plan: map['plan'] as String? ?? 'basic',
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'trial',
      createdAt: map['createdAt'] as String?,
      trialEndsAt: map['trialEndsAt'] as String?,
    );
  }
}

const _projectId = 'flow-studio-10';
const _region = 'us-central1';

/// Chama a Cloud Function getAdminDashboard. Só usuário autenticado; resultado depende de app_config/config.adminUids.
/// Na web usa HTTP para evitar erro Int64 do dart2js e garantir que a lista de negócios apareça.
final adminDashboardProvider =
    FutureProvider<AdminDashboardData>((ref) async {
  try {
    if (kIsWeb) {
      return _fetchAdminDashboardViaHttp();
    }
    final callable = FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: _region,
    ).httpsCallable('getAdminDashboard');
    final result = await callable.call();
    final raw = result.data;
    if (raw == null) {
      return const AdminDashboardData(isAdmin: false, error: 'Resposta vazia');
    }
    final data = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    return _parseAdminDashboardData(data);
  } on FirebaseFunctionsException catch (e) {
    return AdminDashboardData(
      isAdmin: false,
      error: e.message ?? e.code,
    );
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('Int64')) {
      return const AdminDashboardData(isAdmin: true, barberShops: []);
    }
    return AdminDashboardData(isAdmin: false, error: msg);
  }
});

/// Na web: chama a callable via HTTP para receber JSON puro (evita Int64).
Future<AdminDashboardData> _fetchAdminDashboardViaHttp() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const AdminDashboardData(isAdmin: false, error: 'Faça login para acessar.');
  }
  final token = await user.getIdToken();
  if (token == null) {
    return const AdminDashboardData(isAdmin: false, error: 'Token não disponível.');
  }
  final url = Uri.parse(
    'https://$_region-$_projectId.cloudfunctions.net/getAdminDashboard',
  );
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'data': {}}),
  );
  if (response.statusCode != 200) {
    final body = response.body;
    if (body.isNotEmpty) {
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final err = json['error'] as Map<String, dynamic>?;
        final message = err?['message'] as String?;
        if (message != null) {
          return AdminDashboardData(isAdmin: false, error: message);
        }
      } catch (_) {}
    }
    return AdminDashboardData(
      isAdmin: false,
      error: 'Erro ${response.statusCode}: ${response.reasonPhrase ?? response.body}',
    );
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final result = json['result'];
  if (result == null) {
    return const AdminDashboardData(isAdmin: false, error: 'Resposta inválida.');
  }
  final data = result as Map<String, dynamic>;
  return _parseAdminDashboardData(data);
}

AdminDashboardData _parseAdminDashboardData(Map<String, dynamic> data) {
  final isAdmin = data['isAdmin'] as bool? ?? false;
  final list = data['barberShops'] as List<dynamic>?;
  final barberShops = list
          ?.map((e) => AdminBarberShopItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      [];
  final summaryRaw = data['summary'];
  final summary = summaryRaw is Map<String, dynamic>
      ? AdminSummary.fromMap(summaryRaw)
      : null;
  return AdminDashboardData(
    isAdmin: isAdmin,
    barberShops: barberShops,
    summary: summary,
  );
}
