import 'package:cloud_firestore/cloud_firestore.dart';

/// Item de serviço dentro de um agendamento (suporta múltiplos).
class AppointmentServiceItem {
  final String serviceId;
  final String serviceName;
  final double price;
  final int durationMinutes;

  const AppointmentServiceItem({
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() => {
    'serviceId': serviceId,
    'serviceName': serviceName,
    'price': price,
    'durationMinutes': durationMinutes,
  };

  static AppointmentServiceItem? fromMap(dynamic e) {
    if (e == null || e is! Map) return null;
    final row = Map<String, dynamic>.from(e);
    final id = row['serviceId'] as String?;
    final name = row['serviceName'] as String?;
    if (id == null || name == null) return null;
    final price = (row['price'] as num?)?.toDouble() ?? 0;
    final durRaw = row['durationMinutes'];
    final dur = durRaw is int
        ? durRaw
        : (durRaw is num ? durRaw.toInt() : 30);
    return AppointmentServiceItem(serviceId: id, serviceName: name, price: price, durationMinutes: dur);
  }
}

/// Agendamento (coleção appointments).
class Appointment {
  final String id;
  final String barberShopId;
  final String? clientId; // ID na subcoleção barbershops/{slug}/clients
  final String clientName;
  final String clientWhatsapp;
  final String serviceId; // primeiro serviço (retrocompat)
  final String serviceName; // nomes concatenados
  /// Preço total no momento do agendamento (para DRE).
  final double? servicePrice;
  final DateTime dateTime;
  /// Momento originalmente reservado (não altera na antecipação; cópia de [dateTime] na criação).
  final DateTime? originalDateTime;
  final int durationMinutes;
  final String status; // pending, confirmed, completed, canceled
  final DateTime? createdAt;
  /// Quando o atendimento foi marcado como concluído (painel).
  final DateTime? completedAt;
  /// Horário sugerido pelo dono; o cliente confirma para aplicar em [dateTime].
  final DateTime? proposedDateTime;
  /// ID do funcionário que atende (null = dono/único).
  final String? staffId;
  final String? staffName;
  /// Lista de serviços do agendamento (vários no mesmo horário).
  final List<AppointmentServiceItem> services;
  /// Atendimento avulso (sem reserva prévia), registrado pelo dono no painel.
  final bool walkIn;

  const Appointment({
    required this.id,
    required this.barberShopId,
    this.clientId,
    required this.clientName,
    required this.clientWhatsapp,
    required this.serviceId,
    required this.serviceName,
    this.servicePrice,
    required this.dateTime,
    this.originalDateTime,
    required this.durationMinutes,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.proposedDateTime,
    this.staffId,
    this.staffName,
    this.services = const [],
    this.walkIn = false,
  });

  /// Total de serviços (útil quando services está vazio por retrocompat).
  int get serviceCount => services.isEmpty ? 1 : services.length;

  /// Valor cobrado (finalPrice / soma dos serviços) para receita do dia e DRE.
  double get bookedRevenue {
    final p = servicePrice;
    if (p != null && p > 0) return p;
    if (services.isNotEmpty) {
      final sum = services.fold<double>(0, (s, i) => s + i.price);
      if (sum > 0) return sum;
    }
    return 0;
  }

  factory Appointment.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final dt = data['dateTime'];
    final dateTime = dt is Timestamp
        ? dt.toDate()
        : (dt is DateTime ? dt : DateTime.now());
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    DateTime? originalDateTime;
    final rawOrig = data['originalDateTime'];
    if (rawOrig is Timestamp) {
      originalDateTime = rawOrig.toDate();
    }
    DateTime? completedAt;
    final rawComp = data['completedAt'];
    if (rawComp is Timestamp) {
      completedAt = rawComp.toDate();
    }
    DateTime? proposedDateTime;
    final rawProp = data['proposedDateTime'];
    if (rawProp is Timestamp) {
      proposedDateTime = rawProp.toDate();
    }

    final rawServices = data['services'] as List<dynamic>?;
    var servicesList = rawServices != null
        ? rawServices.map((e) => AppointmentServiceItem.fromMap(e)).whereType<AppointmentServiceItem>().toList()
        : <AppointmentServiceItem>[];

    final sid = data['serviceId'] as String? ?? '';
    final sname = data['serviceName'] as String? ?? '';
    final dur = (data['durationMinutes'] as int?) ?? 30;
    final sprice = (data['finalPrice'] as num?)?.toDouble() ?? (data['originalPrice'] as num?)?.toDouble() ?? (data['servicePrice'] as num?)?.toDouble();

    if (servicesList.isEmpty && sid.isNotEmpty) {
      servicesList = [AppointmentServiceItem(serviceId: sid, serviceName: sname, price: sprice ?? 0, durationMinutes: dur)];
    }
    final walkIn = data['walkIn'] == true;

    if (servicesList.isEmpty) {
      return Appointment(
        id: id,
        barberShopId: data['barberShopId'] as String? ?? '',
        clientId: data['clientId'] as String?,
        clientName: data['clientName'] as String? ?? '',
        clientWhatsapp: data['clientWhatsapp'] as String? ?? '',
        serviceId: sid,
        serviceName: sname,
        servicePrice: sprice,
        dateTime: dateTime,
        originalDateTime: originalDateTime ?? dateTime,
        durationMinutes: dur,
        status: data['status'] as String? ?? 'pending',
        createdAt: createdAt,
        completedAt: completedAt,
        proposedDateTime: proposedDateTime,
        staffId: data['staffId'] as String?,
        staffName: data['staffName'] as String?,
        services: const [],
        walkIn: walkIn,
      );
    }

    final sumDur = servicesList.fold<int>(0, (s, i) => s + i.durationMinutes);
    return Appointment(
      id: id,
      barberShopId: data['barberShopId'] as String? ?? '',
      clientId: data['clientId'] as String?,
      clientName: data['clientName'] as String? ?? '',
      clientWhatsapp: data['clientWhatsapp'] as String? ?? '',
      serviceId: servicesList.first.serviceId,
      serviceName: servicesList.map((s) => s.serviceName).join(', '),
      servicePrice: sprice ?? (servicesList.isNotEmpty ? servicesList.fold<double>(0, (s, i) => s + i.price) : null),
      dateTime: dateTime,
      originalDateTime: originalDateTime ?? dateTime,
      durationMinutes: sumDur > 0 ? sumDur : dur,
      status: data['status'] as String? ?? 'pending',
      createdAt: createdAt,
      completedAt: completedAt,
      proposedDateTime: proposedDateTime,
      staffId: data['staffId'] as String?,
      staffName: data['staffName'] as String?,
      services: servicesList,
      walkIn: walkIn,
    );
  }

  Appointment copyWith({String? status, String? staffId, String? staffName, List<AppointmentServiceItem>? services}) {
    return Appointment(
      id: id,
      barberShopId: barberShopId,
      clientId: clientId,
      clientName: clientName,
      clientWhatsapp: clientWhatsapp,
      serviceId: serviceId,
      serviceName: serviceName,
      servicePrice: servicePrice,
      dateTime: dateTime,
      originalDateTime: originalDateTime,
      durationMinutes: durationMinutes,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt,
      proposedDateTime: proposedDateTime,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      services: services ?? this.services,
      walkIn: walkIn,
    );
  }
}
