import 'package:cloud_firestore/cloud_firestore.dart';

/// Movimentação de estoque: purchase, service_use, sale, adjustment.
class StockMovement {
  final String id;
  final String type; // "purchase", "service_use", "sale", "adjustment", "transfer_to_studio"
  final String productId;
  final double quantity; // positivo = entrada, negativo = saída (para adjustment)
  final double value; // receita (venda) ou custo de compra/uso conforme tipo
  /// Custo (CMV) na venda: quantidade × custo unitário — para lucro da venda no DRE.
  final double? costValue;
  final DateTime date;
  final String? reason;
  final String? linkedAppointmentId;
  final String? linkedServiceId;

  const StockMovement({
    required this.id,
    required this.type,
    required this.productId,
    required this.quantity,
    required this.value,
    this.costValue,
    required this.date,
    this.reason,
    this.linkedAppointmentId,
    this.linkedServiceId,
  });

  factory StockMovement.fromFirestore(String id, Map<String, dynamic> data) {
    final dt = data['date'];
    final date = dt is Timestamp
        ? dt.toDate()
        : (dt is DateTime ? dt : DateTime.now());
    return StockMovement(
      id: id,
      type: data['type'] as String? ?? 'adjustment',
      productId: data['productId'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      value: (data['value'] as num?)?.toDouble() ?? 0,
      costValue: (data['costValue'] as num?)?.toDouble(),
      date: date,
      reason: data['reason'] as String?,
      linkedAppointmentId: data['linkedAppointmentId'] as String?,
      linkedServiceId: data['linkedServiceId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'productId': productId,
        'quantity': quantity,
        'value': value,
        if (costValue != null) 'costValue': costValue,
        'date': Timestamp.fromDate(date),
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        if (linkedAppointmentId != null) 'linkedAppointmentId': linkedAppointmentId,
        if (linkedServiceId != null) 'linkedServiceId': linkedServiceId,
      };
}
