import 'package:cloud_firestore/cloud_firestore.dart';

/// Cliente do negócio (subcoleção barbershops/{slug}/clients).
class Client {
  final String id;
  final String name;
  final String whatsapp;
  final String dateOfBirth; // dd/MM/yyyy
  final String? address;
  final String? photoUrl;
  final String? email;
  /// CPF (apenas dígitos ou formatado).
  final String? cpf;
  /// UID do Firebase Auth quando o cliente se cadastra com email/senha ou Google.
  final String? authUid;
  /// Data em que o cliente aceitou os termos de uso e LGPD (consentimento).
  final DateTime? lgpdConsentAt;
  /// Estilo do cartão fidelidade preferido pelo cliente: masculine, feminine.
  final String? preferredLoyaltyCardStyle;
  final int loyaltyPoints;
  final int totalAppointments;
  final String? referralCode;
  final String? referredByWhatsapp;
  final DateTime? createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.whatsapp,
    required this.dateOfBirth,
    this.address,
    this.photoUrl,
    this.email,
    this.cpf,
    this.authUid,
    this.lgpdConsentAt,
    this.preferredLoyaltyCardStyle,
    this.loyaltyPoints = 0,
    this.totalAppointments = 0,
    this.referralCode,
    this.referredByWhatsapp,
    this.createdAt,
  });

  factory Client.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;

    final rawLgpd = data['lgpdConsentAt'];
    DateTime? lgpdConsentAt;
    if (rawLgpd is Timestamp) {
      lgpdConsentAt = rawLgpd.toDate();
    } else if (rawLgpd is DateTime) {
      lgpdConsentAt = rawLgpd;
    }

    return Client(
      id: id,
      name: data['name'] as String? ?? '',
      whatsapp: data['whatsapp'] as String? ?? '',
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      address: data['address'] as String?,
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String?,
      cpf: data['cpf'] as String?,
      authUid: data['authUid'] as String?,
      lgpdConsentAt: lgpdConsentAt,
      preferredLoyaltyCardStyle: data['preferredLoyaltyCardStyle'] as String?,
      loyaltyPoints: (data['loyaltyPoints'] as int?) ?? 0,
      totalAppointments: (data['totalAppointments'] as int?) ?? 0,
      referralCode: data['referralCode'] as String?,
      referredByWhatsapp: data['referredByWhatsapp'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'whatsapp': whatsapp,
      'dateOfBirth': dateOfBirth,
      if (address != null) 'address': address,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null) 'email': email,
      if (cpf != null) 'cpf': cpf,
      if (authUid != null) 'authUid': authUid,
      if (lgpdConsentAt != null) 'lgpdConsentAt': Timestamp.fromDate(lgpdConsentAt!),
      if (preferredLoyaltyCardStyle != null) 'preferredLoyaltyCardStyle': preferredLoyaltyCardStyle,
      'loyaltyPoints': loyaltyPoints,
      'totalAppointments': totalAppointments,
      if (referralCode != null) 'referralCode': referralCode,
      if (referredByWhatsapp != null) 'referredByWhatsapp': referredByWhatsapp,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Selos (1 selo = 10 pontos).
  int get stamps => loyaltyPoints ~/ 10;

  Client copyWith({
    String? name,
    String? address,
    String? photoUrl,
    String? email,
    String? cpf,
    String? authUid,
    DateTime? lgpdConsentAt,
    String? preferredLoyaltyCardStyle,
    int? loyaltyPoints,
    int? totalAppointments,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      whatsapp: whatsapp,
      dateOfBirth: dateOfBirth,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      cpf: cpf ?? this.cpf,
      authUid: authUid ?? this.authUid,
      lgpdConsentAt: lgpdConsentAt ?? this.lgpdConsentAt,
      preferredLoyaltyCardStyle: preferredLoyaltyCardStyle ?? this.preferredLoyaltyCardStyle,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      totalAppointments: totalAppointments ?? this.totalAppointments,
      referralCode: referralCode,
      referredByWhatsapp: referredByWhatsapp,
      createdAt: createdAt,
    );
  }
}
