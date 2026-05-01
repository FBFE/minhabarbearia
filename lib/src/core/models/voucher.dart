import 'package:cloud_firestore/cloud_firestore.dart';

/// Voucher/promocional do negócio (subcoleção barbershops/{slug}/vouchers).
class Voucher {
  final String id;
  final String code;
  final String description;
  final String discountType; // 'percent' ou 'fixed'
  final double discountValue; // 10 = 10% ou R$ 10
  final DateTime? expiresAt;
  final List<String> usedBy; // clientIds ou whatsapps que já usaram
  final DateTime? createdAt;
  final bool active;
  final String? clientWhatsapp; // quando gerado por pontos
  final bool generatedFromPoints;

  const Voucher({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.expiresAt,
    this.usedBy = const [],
    this.createdAt,
    this.active = true,
    this.clientWhatsapp,
    this.generatedFromPoints = false,
  });

  factory Voucher.fromFirestore(String id, Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'] is Timestamp
        ? (data['expiresAt'] as Timestamp).toDate()
        : null;
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final usedByList = data['usedBy'];
    final usedBy = usedByList is List
        ? (usedByList).map((e) => e.toString()).toList()
        : <String>[];

    return Voucher(
      id: id,
      code: data['code'] as String? ?? '',
      description: data['description'] as String? ?? '',
      discountType: data['discountType'] as String? ?? 'percent',
      discountValue: (data['discountValue'] as num?)?.toDouble() ?? 0,
      expiresAt: expiresAt,
      usedBy: usedBy,
      createdAt: createdAt,
      active: data['active'] as bool? ?? true,
      clientWhatsapp: data['clientWhatsapp'] as String?,
      generatedFromPoints: data['generatedFromPoints'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'usedBy': usedBy,
      'active': active,
      if (clientWhatsapp != null) 'clientWhatsapp': clientWhatsapp,
      if (generatedFromPoints) 'generatedFromPoints': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isValid => active && !isExpired;

  /// Disponível para uso por este cliente (não usado ainda por esse whatsapp).
  bool isAvailableFor(String clientWhatsapp) =>
      isValid && !usedBy.contains(clientWhatsapp);

  /// Desconto aplicado sobre [originalPrice].
  double discountAmount(double originalPrice) {
    if (discountType == 'percent') {
      return originalPrice * (discountValue / 100);
    }
    return discountValue.clamp(0.0, originalPrice);
  }

  double priceWithDiscount(double originalPrice) {
    return (originalPrice - discountAmount(originalPrice)).clamp(0.0, double.infinity);
  }

  String get discountLabel {
    if (discountType == 'percent') {
      return '${discountValue.toStringAsFixed(0)}% off';
    }
    return 'R\$ ${discountValue.toStringAsFixed(2).replaceAll('.', ',')} off';
  }
}
