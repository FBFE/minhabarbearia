/// Uso de produto por um serviço.
/// - Se [consumptionPercent] for definido: consumo no studio (percentual por atendimento, ex: 5 = 5%).
/// - Caso contrário: [quantity] é deduzida do estoque de vendas ao concluir.
class ServiceProductUse {
  final String productId;
  /// Quantidade consumida (usada quando não é uso no studio).
  final double quantity;
  /// Percentual consumido por atendimento no studio (0-100). Ex: 5 = 5% por corte.
  final double? consumptionPercent;

  const ServiceProductUse({
    required this.productId,
    this.quantity = 0,
    this.consumptionPercent,
  });

  bool get useStudio => consumptionPercent != null && consumptionPercent! > 0;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'quantity': quantity,
        if (consumptionPercent != null) 'consumptionPercent': consumptionPercent,
      };

  static ServiceProductUse? fromMap(dynamic e) {
    if (e is! Map<String, dynamic>) return null;
    final id = e['productId'] as String?;
    if (id == null || id.isEmpty) return null;
    final percent = (e['consumptionPercent'] as num?)?.toDouble();
    final q = (e['quantity'] as num?)?.toDouble() ?? 0;
    if (percent != null && percent > 0) {
      return ServiceProductUse(productId: id, consumptionPercent: percent);
    }
    if (q > 0) return ServiceProductUse(productId: id, quantity: q);
    return null;
  }
}

/// Categorias sugeridas para serviços (cortes, barba, manicure, etc.).
const List<String> serviceCategoryOptions = [
  'Cortes',
  'Barba',
  'Manicure',
  'Pedicure',
  'Sobrancelhas',
  'Cílios',
  'Outros',
];

/// Serviço oferecido pelo negócio (subcoleção barbershops/{slug}/services).
class Service {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  /// URL da imagem do serviço (ex.: foto do corte) – otimizada para mobile.
  final String? imageUrl;
  /// Se false, não aparece no link de agendamento (dono continua a gerir no painel).
  final bool active;
  /// Detalhes do serviço (procedimentos estéticos, etc.).
  final String? description;
  /// Categoria: Cortes, Barba, Manicure, Pedicure, Sobrancelhas, Cílios, Outros.
  final String? category;
  /// Produtos consumidos ao realizar este serviço (para baixa automática de estoque).
  final List<ServiceProductUse> productConsumptions;

  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
    this.active = true,
    this.description,
    this.category,
    this.productConsumptions = const [],
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final list = json['productConsumptions'] as List<dynamic>?;
    final consumptions = list != null
        ? list.map((e) => ServiceProductUse.fromMap(e)).whereType<ServiceProductUse>().toList()
        : <ServiceProductUse>[];
    return Service(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['durationMinutes'] as int?) ?? 30,
      imageUrl: json['imageUrl'] as String?,
      active: json['active'] as bool? ?? true,
      description: json['description'] as String?,
      category: json['category'] as String?,
      productConsumptions: consumptions,
    );
  }

  factory Service.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final list = data['productConsumptions'] as List<dynamic>?;
    final consumptions = list != null
        ? list.map((e) => ServiceProductUse.fromMap(e)).whereType<ServiceProductUse>().toList()
        : <ServiceProductUse>[];
    String? imageUrl;
    for (final key in const [
      'imageUrl',
      'imageURL',
      'photoUrl',
      'photoURL',
      'photo',
      'coverImageUrl',
      'coverUrl',
      'pictureUrl',
      'thumbnailUrl',
    ]) {
      final raw = data[key];
      if (raw is String) {
        final t = raw.trim();
        if (t.isNotEmpty) {
          imageUrl = t;
          break;
        }
      } else if (raw != null) {
        final t = raw.toString().trim();
        if (t.isNotEmpty) {
          imageUrl = t;
          break;
        }
      }
    }
    final durRaw = data['durationMinutes'];
    final durationMinutes = durRaw is int
        ? durRaw
        : (durRaw is num ? durRaw.toInt() : 30);
    final active = data['active'] != false;
    return Service(
      id: id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: durationMinutes,
      imageUrl: imageUrl,
      active: active,
      description: data['description'] as String?,
      category: data['category'] as String?,
      productConsumptions: consumptions,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
        'active': active,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (productConsumptions.isNotEmpty)
          'productConsumptions': productConsumptions.map((e) => e.toMap()).toList(),
      };

  String get priceFormatted =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  Map<String, dynamic> toFirestore() => toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Service &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          imageUrl == other.imageUrl &&
          active == other.active;

  @override
  int get hashCode => Object.hash(id, name, imageUrl, active);
}
