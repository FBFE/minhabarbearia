import 'package:cloud_firestore/cloud_firestore.dart';

/// Produto do estoque (subcoleção barbershops/{slug}/products).
class Product {
  final String id;
  final String name;
  final String category;
  final double costPrice;
  final double salePrice;
  final double currentStock;
  /// Estoque mínimo para alerta de "está acabando".
  final double minStock;
  final String unit; // "un", "ml", "g"
  final DateTime? lastUpdated;
  /// Percentual restante do produto em uso no studio (0-100). null = nenhuma unidade em uso no studio.
  final double? studioRemainingPercent;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.salePrice,
    required this.currentStock,
    required this.minStock,
    required this.unit,
    this.lastUpdated,
    this.studioRemainingPercent,
  });

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    final studio = data['studioRemainingPercent'];
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Outros',
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
      salePrice: (data['salePrice'] as num?)?.toDouble() ?? 0,
      currentStock: (data['currentStock'] as num?)?.toDouble() ?? 0,
      minStock: (data['minStock'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? 'un',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      studioRemainingPercent: studio != null ? (studio as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'category': category,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'currentStock': currentStock,
        'minStock': minStock,
        'unit': unit,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (studioRemainingPercent != null) 'studioRemainingPercent': studioRemainingPercent,
      };

  bool get isLowStock => minStock > 0 && currentStock <= minStock;

  /// Alerta quando a “última garrafa” do pool está com ≤15% (permite acoplar outra unidade).
  static const double studioAlertThresholdPercent = 15;

  /// [studioRemainingPercent] pode passar de 100 (ex.: 200% = 2 un. retiradas para o studio).
  bool get isStudioLow {
    final s = studioRemainingPercent;
    if (s == null || s <= 0) return false;
    final rem = s % 100;
    if (rem == 0) return s < 100 && s <= studioAlertThresholdPercent;
    return rem <= studioAlertThresholdPercent;
  }

  bool get hasStudioUse => studioRemainingPercent != null && studioRemainingPercent! > 0;

  String get unitLabel {
    switch (unit) {
      case 'ml':
        return 'ml';
      case 'g':
        return 'g';
      default:
        return 'un';
    }
  }
}
