import 'package:cloud_firestore/cloud_firestore.dart';

/// Funcionário/profissional do negócio (subcoleção barbershops/{slug}/staff).
class Staff {
  final String id;
  final String name;
  final String email;
  /// IDs dos serviços que este funcionário realiza (vazio = todos).
  final List<String> serviceIds;
  /// UID do Firebase Auth quando o funcionário acessa o sistema (opcional).
  final String? authUid;
  final DateTime? createdAt;

  const Staff({
    required this.id,
    required this.name,
    required this.email,
    this.serviceIds = const [],
    this.authUid,
    this.createdAt,
  });

  factory Staff.fromFirestore(String id, Map<String, dynamic> data) {
    final list = data['serviceIds'] as List<dynamic>?;
    return Staff(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      serviceIds: list?.map((e) => e.toString()).toList() ?? const [],
      authUid: data['authUid'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'serviceIds': serviceIds,
        if (authUid != null) 'authUid': authUid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
      };

  /// Retorna true se este funcionário realiza o serviço [serviceId]. Lista vazia = todos.
  bool performsService(String serviceId) {
    if (serviceIds.isEmpty) return true;
    return serviceIds.contains(serviceId);
  }
}
