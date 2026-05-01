import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/barber_shop.dart';
import '../../../core/utils/firestore_user_error.dart';
import '../../../core/models/product.dart';
import '../../../core/models/service.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/models/voucher.dart';
import '../../../core/providers/barber_shop_providers.dart';

Future<bool> appointmentHasRecordedServiceConsumption(
  FirebaseFirestore firestore,
  String slug,
  String appointmentId,
) async {
  if (appointmentId.isEmpty) return false;
  final snap = await firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('stock_movements')
      .where('linkedAppointmentId', isEqualTo: appointmentId)
      .limit(50)
      .get();
  for (final d in snap.docs) {
    final t = d.data()['type'] as String? ?? '';
    if (t == 'service_use') return true;
  }
  return false;
}

/// Resultado da sincronização de consumos: [appliedCount] novas baixas; [skippedErrors]
/// documentos onde algo falhou (rede/permissão/dados inválidos) sem bloquear o restante.
Future<({int appliedCount, int skippedErrors, String? firstErrorHint})>
    syncMissingConsumptionForCompletedAppointments({
  required WidgetRef ref,
  required FirebaseFirestore firestore,
  required String slug,
}) async {
  final qs =
      await firestore.collection('appointments').where('barberShopId', isEqualTo: slug).limit(500).get();
  var n = 0;
  var skipped = 0;
  String? firstHint;
  for (final doc in qs.docs) {
    final status = doc.data()['status'] as String? ?? '';
    if (status != 'completed') continue;
    try {
      final applied = await applyServiceConsumptionsFromAppointmentDoc(
        ref: ref,
        firestore: firestore,
        slug: slug,
        appointmentId: doc.id,
      );
      if (applied) n++;
    } catch (e) {
      skipped++;
      firstHint ??= firestoreUserVisibleError(e);
    }
  }
  ref.invalidate(productsProvider(slug));
  ref.invalidate(stockMovementsProvider(slug));
  return (appliedCount: n, skippedErrors: skipped, firstErrorHint: firstHint);
}

/// Gera código alfanumérico para voucher de fidelidade.
String generateVoucherCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = DateTime.now().millisecondsSinceEpoch % 0x7FFFFFFF;
  final random = r.isNegative ? -r : r;
  final len = 6 + (random % 3);
  final buffer = StringBuffer();
  var v = random;
  for (var i = 0; i < len; i++) {
    v = (v * 1103515245 + 12345) & 0x7FFFFFFF;
    buffer.write(chars[v % chars.length]);
  }
  return buffer.toString();
}

/// Pontos e vouchers após um atendimento concluído com cliente vinculado.
/// Retorna quantos vouchers foram gerados no fluxo.
Future<int> awardLoyaltyAfterCompletedAppointment({
  required WidgetRef ref,
  required FirebaseFirestore firestore,
  required String slug,
  required String clientId,
}) async {
  final clientRef = firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('clients')
      .doc(clientId);
  final vouchersRef =
      firestore.collection(barbershopsCollection).doc(slug).collection('vouchers');

  final shop = await ref.read(barberShopBySlugProvider(slug).future);
  final pointsRequired = (shop?.loyaltyPointsRequired ?? 100).clamp(1, 10000);
  final discountType = shop?.voucherDiscountType ?? 'fixed';
  final discountValue = shop?.voucherDiscountValue ?? 10.0;

  var vouchersCreated = 0;
  await firestore.runTransaction((tx) async {
    final clientSnap = await tx.get(clientRef);
    final data = clientSnap.data();
    if (data == null) return;
    final currentPoints = (data['loyaltyPoints'] as int?) ?? 0;
    final clientWhatsapp = data['whatsapp'] as String? ?? '';
    final pts = currentPoints + 10;
    final n = pointsRequired > 0 ? pts ~/ pointsRequired : 0;
    final pointsAfter = pts - (n * pointsRequired);
    vouchersCreated = n;

    tx.update(clientRef, {
      'loyaltyPoints': pointsAfter,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final discountLabel = discountType == 'percent'
        ? '${discountValue.toStringAsFixed(0)}% off'
        : 'R\$ ${discountValue.toStringAsFixed(2).replaceAll('.', ',')} off';
    for (var i = 0; i < n; i++) {
      final code = 'FIDEL${generateVoucherCode()}';
      final voucher = Voucher(
        id: '',
        code: code,
        description: '$discountLabel por fidelidade ($pointsRequired pontos)',
        discountType: discountType,
        discountValue: discountValue,
        expiresAt: DateTime.now().add(const Duration(days: 60)),
        usedBy: const [],
        active: true,
        createdAt: null,
        clientWhatsapp: clientWhatsapp.isNotEmpty ? clientWhatsapp : null,
        generatedFromPoints: true,
      );
      tx.set(vouchersRef.doc(), voucher.toFirestore());
    }
  });

  ref.invalidate(clientsProvider(slug));
  ref.invalidate(vouchersProvider(slug));
  return vouchersCreated;
}

/// Exibe feedback de vouchers gerados (quando [mounted]).
void showLoyaltyVouchersSnackBar(
  BuildContext context, {
  required bool mounted,
  required BarberShop? shop,
  required int pointsRequired,
  required int vouchersGenerated,
}) {
  if (!mounted || vouchersGenerated <= 0) return;
  final msg = shop?.voucherDiscountLabel ?? 'R\$ 10,00 off';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        vouchersGenerated == 1
            ? 'Cliente atingiu $pointsRequired pontos! Voucher $msg gerado.'
            : 'Cliente gerou $vouchersGenerated vouchers ($msg)!',
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Baixa de estoque (consumo dos serviços) ao concluir agendamento ou atendimento avulso.
/// Retorna [true] se executou uma transação de baixa; [false] se não havia consumo ou já estava registado.
Future<bool> applyServiceConsumptionsForServices({
  required WidgetRef ref,
  required FirebaseFirestore firestore,
  required String slug,
  required String appointmentId,
  required List<Service> servicesToApply,
}) async {
  if (!servicesToApply.any((s) => s.productConsumptions.isNotEmpty)) return false;

  if (appointmentId.isNotEmpty) {
    final already = await appointmentHasRecordedServiceConsumption(
      firestore,
      slug,
      appointmentId,
    );
    if (already) {
      ref.invalidate(productsProvider(slug));
      ref.invalidate(stockMovementsProvider(slug));
      return false;
    }
  }

  final productsRef =
      firestore.collection(barbershopsCollection).doc(slug).collection('products');
  final movementsRef =
      firestore.collection(barbershopsCollection).doc(slug).collection('stock_movements');

  await firestore.runTransaction((tx) async {
    for (final service in servicesToApply) {
      for (final use in service.productConsumptions) {
        final productSnap = await tx.get(productsRef.doc(use.productId));
        if (!productSnap.exists || productSnap.data() == null) continue;
        final product = Product.fromFirestore(productSnap.id, productSnap.data()!);
        double costValue;
        if (use.useStudio && use.consumptionPercent != null) {
          final current = product.studioRemainingPercent ?? 0;
          final newStudio =
              (current - use.consumptionPercent!).clamp(0.0, double.infinity);
          costValue = (use.consumptionPercent! / 100) * product.costPrice;
          tx.update(productsRef.doc(product.id), {
            'studioRemainingPercent': newStudio,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          tx.set(
            movementsRef.doc(),
            StockMovement(
              id: '',
              type: 'service_use',
              productId: product.id,
              quantity: -use.consumptionPercent!,
              value: costValue,
              date: DateTime.now(),
              reason: 'Uso no studio: ${service.name} (${use.consumptionPercent}%)',
              linkedAppointmentId: appointmentId,
              linkedServiceId: service.id,
            ).toFirestore(),
          );
        } else {
          final newStock =
              (product.currentStock - use.quantity).clamp(0.0, double.infinity);
          costValue = use.quantity * product.costPrice;
          tx.update(productsRef.doc(product.id), {
            'currentStock': newStock,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          tx.set(
            movementsRef.doc(),
            StockMovement(
              id: '',
              type: 'service_use',
              productId: product.id,
              quantity: -use.quantity,
              value: costValue,
              date: DateTime.now(),
              reason: 'Uso no serviço: ${service.name}',
              linkedAppointmentId: appointmentId,
              linkedServiceId: service.id,
            ).toFirestore(),
          );
        }
      }
    }
  });
  ref.invalidate(productsProvider(slug));
  ref.invalidate(stockMovementsProvider(slug));
  return true;
}

/// Lê o documento do agendamento, resolve os [Service] e aplica consumo de produtos.
Future<bool> applyServiceConsumptionsFromAppointmentDoc({
  required WidgetRef ref,
  required FirebaseFirestore firestore,
  required String slug,
  required String appointmentId,
}) async {
  final appointmentSnap = await firestore.collection('appointments').doc(appointmentId).get();
  final appointmentData = appointmentSnap.data();
  if (appointmentData == null) return false;

  final rawServices = appointmentData['services'] as List<dynamic>?;
  final serviceIds = <String>{};
  if (rawServices != null) {
    for (final e in rawServices) {
      if (e is Map) {
        final row = Map<String, dynamic>.from(e);
        final sid = row['serviceId'] as String?;
        if (sid != null && sid.isNotEmpty) serviceIds.add(sid);
      }
    }
  }
  final fallback = appointmentData['serviceId'] as String?;
  if (fallback != null && fallback.isNotEmpty) {
    serviceIds.add(fallback);
  }

  final servicesCol =
      firestore.collection(barbershopsCollection).doc(slug).collection('services');

  final servicesToApply = <Service>[];
  for (final sid in serviceIds) {
    final serviceSnap = await servicesCol.doc(sid).get();
    if (serviceSnap.exists && serviceSnap.data() != null) {
      servicesToApply.add(Service.fromFirestore(serviceSnap.id, serviceSnap.data()!));
    }
  }

  if (servicesToApply.isEmpty) return false;

  return applyServiceConsumptionsForServices(
    ref: ref,
    firestore: firestore,
    slug: slug,
    appointmentId: appointmentId,
    servicesToApply: servicesToApply,
  );
}
