import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import '../utils/color_utils.dart';

part 'barber_shop.g.dart';

/// Antigo valor 'lgbt' deixou de ser opção de público; normaliza para 'both'.
String _normalizeThemeStyle(String v) => v == 'lgbt' ? 'both' : v;

@JsonSerializable()
class BarberShop {
  final String id;
  final String name;
  final String slug;
  final String? ownerUid;
  final String? logoUrl;
  final String? backgroundImageUrl;
  final double watermarkOpacity;
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  final int primaryColor;
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  final int secondaryColor;
  /// Cor de fundo da tela (dashboard/login). Se null, usa fundo escuro padrão.
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  final int? backgroundColor;
  final String plan; // "basic" | "pro"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Fim do período de trial (novos cadastros: 7 dias).
  final DateTime? trialEndsAt;
  /// Status da assinatura: trial | active | past_due | canceled | none | refunded
  final String subscriptionStatus;
  /// Fim do período de cobrança atual (renovação ~mensal, vem do Stripe `current_period_end`).
  final DateTime? subscriptionCurrentPeriodEnd;
  /// `true` se o utilizador cancelou a renovação mas o período pago ainda corresponde a [subscriptionCurrentPeriodEnd].
  final bool cancelAtPeriodEnd;
  /// ID do cliente no Stripe (para cobrança).
  final String? stripeCustomerId;
  /// ID da assinatura no Stripe (se assinatura recorrente).
  final String? stripeSubscriptionId;
  /// Data/hora do último pagamento com valor > 0 (fatura paga; usado na janela de 7 dias para reembolso).
  final DateTime? subscriptionLastInvoicePaidAt;
  /// `true` após o dono usar reembolso pela assinatura — próximas compras só permitem cancelar renovação, sem reembolso automático.
  final bool subscriptionRefundEverUsed;
  /// Pontos necessários para gerar 1 voucher de fidelidade (padrão 100).
  final int loyaltyPointsRequired;
  /// Tipo do desconto do voucher: 'percent' ou 'fixed'.
  final String voucherDiscountType;
  /// Valor: percentual (ex: 15) ou valor fixo em R\$ (ex: 10).
  final double voucherDiscountValue;
  /// Tipos de estabelecimento: barbershop, beauty_salon, manicure, pedicure, eyebrows, lash_design (pode vários).
  final List<String> businessTypes;
  /// Tema do público: masculine, feminine, both.
  final String themeStyle;
  /// Estilo do cartão fidelidade: masculine, feminine.
  final String loyaltyCardStyle;
  /// true = só o dono atende; false = tem funcionários (lista em barbershops/{slug}/staff).
  final bool singleAttendant;
  /// Horário de abertura "HH:mm" (ex: "09:00").
  final String openTime;
  /// Horário de fechamento "HH:mm" (ex: "19:00").
  final String closeTime;
  /// Pontos que o indicador ganha quando um indicado se cadastra ou agenda (padrão 30).
  final int referralPoints;
  /// Tela ativa do assistente (0–2) ou 3 quando concluído. Ausente no Firestore = 3.
  final int onboardingScreen;
  /// Horários semanais: chaves "1"–"7" (DateTime.weekday, seg=1..dom=7), valor `{ "open": bool, "start": "HH:mm", "end": "HH:mm" }`.
  final Map<String, dynamic>? weeklyHours;
  /// Dias sem atendimento (feriados, folgas): chaves yyyy-MM-dd (data civil local).
  final List<String> closedDates;

  const BarberShop({
    required this.id,
    required this.name,
    required this.slug,
    this.ownerUid,
    this.logoUrl,
    this.backgroundImageUrl,
    this.watermarkOpacity = 0.15,
    this.primaryColor = 0xFF673AB7,
    this.secondaryColor = 0xFF1A1A2E,
    this.backgroundColor,
    this.plan = 'basic',
    this.createdAt,
    this.updatedAt,
    this.trialEndsAt,
    this.subscriptionStatus = 'trial',
    this.subscriptionCurrentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.subscriptionLastInvoicePaidAt,
    this.subscriptionRefundEverUsed = false,
    this.loyaltyPointsRequired = 100,
    this.voucherDiscountType = 'fixed',
    this.voucherDiscountValue = 10,
    this.businessTypes = const ['barbershop'],
    this.themeStyle = 'both',
    this.loyaltyCardStyle = 'masculine',
    this.singleAttendant = true,
    this.openTime = '09:00',
    this.closeTime = '19:00',
    this.referralPoints = 30,
    this.onboardingScreen = 3,
    this.weeklyHours,
    this.closedDates = const [],
  });

  Color get primaryColorAsColor => Color(primaryColor);
  Color get secondaryColorAsColor => Color(secondaryColor);
  Color? get backgroundColorAsColor => backgroundColor != null ? Color(backgroundColor!) : null;

  /// yyyy-MM-dd para a data civil local [day].
  static String closedDateKeyForDay(DateTime day) {
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  bool isClosedCalendarDay(DateTime day) =>
      closedDates.contains(BarberShop.closedDateKeyForDay(day));

  /// Horário efetivo de abertura/fechamento (HH:mm) no dia, ou `null` se fechado.
  (String, String)? effectiveHoursForDate(DateTime d) {
    if (isClosedCalendarDay(d)) return null;
    if (weeklyHours != null && weeklyHours!.isNotEmpty) {
      final raw = weeklyHours!['${d.weekday}'];
      if (raw is Map) {
        if (raw['open'] == false) return null;
        final s = (raw['start'] as String?)?.trim();
        final e = (raw['end'] as String?)?.trim();
        return (s ?? openTime, e ?? closeTime);
      }
    }
    return (openTime, closeTime);
  }

  String get scheduleSummaryLine {
    if (weeklyHours == null || weeklyHours!.isEmpty) {
      return '$openTime às $closeTime';
    }
    return 'Varia por dia — veja o calendário abaixo';
  }

  factory BarberShop.fromJson(Map<String, dynamic> json) =>
      _$BarberShopFromJson(json);
  Map<String, dynamic> toJson() => _$BarberShopToJson(this);

  factory BarberShop.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return BarberShop(
      id: snapshot.id,
      name: data['name'] as String? ?? '',
      slug: data['slug'] as String? ?? snapshot.id,
      ownerUid: data['ownerUid'] as String?,
      logoUrl: data['logoUrl'] as String?,
      backgroundImageUrl: data['backgroundImageUrl'] as String?,
      watermarkOpacity: (data['watermarkOpacity'] as num?)?.toDouble() ?? 0.15,
      primaryColor: _colorFromJson(data['primaryColor']),
      secondaryColor: _colorFromJson(data['secondaryColor']),
      backgroundColor: data['backgroundColor'] != null ? _colorFromJson(data['backgroundColor']) : null,
      plan: data['plan'] as String? ?? 'basic',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      trialEndsAt: (data['trialEndsAt'] as Timestamp?)?.toDate(),
      subscriptionStatus: data['subscriptionStatus'] as String? ?? 'trial',
      subscriptionCurrentPeriodEnd:
          (data['subscriptionCurrentPeriodEnd'] as Timestamp?)?.toDate(),
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
      stripeCustomerId: data['stripeCustomerId'] as String?,
      stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
      subscriptionLastInvoicePaidAt:
          (data['subscriptionLastInvoicePaidAt'] as Timestamp?)?.toDate(),
      subscriptionRefundEverUsed: data['subscriptionRefundEverUsed'] as bool? ?? false,
      loyaltyPointsRequired: data['loyaltyPointsRequired'] as int? ?? 100,
      voucherDiscountType: data['voucherDiscountType'] as String? ?? 'fixed',
      voucherDiscountValue: (data['voucherDiscountValue'] as num?)?.toDouble() ?? 10,
      businessTypes: (data['businessTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['barbershop'],
      themeStyle: _normalizeThemeStyle(data['themeStyle'] as String? ?? 'both'),
      loyaltyCardStyle: data['loyaltyCardStyle'] as String? ?? 'masculine',
      singleAttendant: data['singleAttendant'] as bool? ?? true,
      openTime: data['openTime'] as String? ?? '09:00',
      closeTime: data['closeTime'] as String? ?? '19:00',
      referralPoints: data['referralPoints'] as int? ?? 30,
      onboardingScreen: (data['onboardingScreen'] as int?) ?? 3,
      weeklyHours: data['weeklyHours'] is Map
          ? Map<String, dynamic>.from(
              (data['weeklyHours'] as Map).map((k, v) => MapEntry(k.toString(), v)),
            )
          : null,
      closedDates: (data['closedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'ownerUid': ownerUid,
      'logoUrl': logoUrl,
      if (backgroundImageUrl != null) 'backgroundImageUrl': backgroundImageUrl,
      'watermarkOpacity': watermarkOpacity,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      'plan': plan,
      if (trialEndsAt != null) 'trialEndsAt': trialEndsAt,
      'subscriptionStatus': subscriptionStatus,
      if (subscriptionCurrentPeriodEnd != null)
        'subscriptionCurrentPeriodEnd': Timestamp.fromDate(subscriptionCurrentPeriodEnd!),
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      if (stripeSubscriptionId != null) 'stripeSubscriptionId': stripeSubscriptionId,
      'loyaltyPointsRequired': loyaltyPointsRequired,
      'voucherDiscountType': voucherDiscountType,
      'voucherDiscountValue': voucherDiscountValue,
      'businessTypes': businessTypes,
      'themeStyle': themeStyle,
      'loyaltyCardStyle': loyaltyCardStyle,
      'singleAttendant': singleAttendant,
      'openTime': openTime,
      'closeTime': closeTime,
      'referralPoints': referralPoints,
      'onboardingScreen': onboardingScreen,
      if (weeklyHours != null && weeklyHours!.isNotEmpty) 'weeklyHours': weeklyHours,
      'closedDates': closedDates,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static int _colorFromJson(dynamic value) {
    if (value == null) return 0xFF673AB7;
    if (value is int) return value;
    if (value is String) return hexToInt(value);
    return 0xFF673AB7;
  }

  static int _colorToJson(int color) => color;

  BarberShop copyWith({
    String? id,
    String? name,
    String? slug,
    String? ownerUid,
    String? logoUrl,
    String? backgroundImageUrl,
    double? watermarkOpacity,
    int? primaryColor,
    int? secondaryColor,
    int? backgroundColor,
    String? plan,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? trialEndsAt,
    String? subscriptionStatus,
    DateTime? subscriptionCurrentPeriodEnd,
    bool? cancelAtPeriodEnd,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    DateTime? subscriptionLastInvoicePaidAt,
    bool? subscriptionRefundEverUsed,
    int? loyaltyPointsRequired,
    String? voucherDiscountType,
    double? voucherDiscountValue,
    List<String>? businessTypes,
    String? themeStyle,
    String? loyaltyCardStyle,
    bool? singleAttendant,
    String? openTime,
    String? closeTime,
    int? referralPoints,
    int? onboardingScreen,
    Map<String, dynamic>? weeklyHours,
    List<String>? closedDates,
  }) {
    return BarberShop(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      ownerUid: ownerUid ?? this.ownerUid,
      logoUrl: logoUrl ?? this.logoUrl,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      plan: plan ?? this.plan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionCurrentPeriodEnd:
          subscriptionCurrentPeriodEnd ?? this.subscriptionCurrentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      subscriptionLastInvoicePaidAt: subscriptionLastInvoicePaidAt ?? this.subscriptionLastInvoicePaidAt,
      subscriptionRefundEverUsed: subscriptionRefundEverUsed ?? this.subscriptionRefundEverUsed,
      loyaltyPointsRequired: loyaltyPointsRequired ?? this.loyaltyPointsRequired,
      voucherDiscountType: voucherDiscountType ?? this.voucherDiscountType,
      voucherDiscountValue: voucherDiscountValue ?? this.voucherDiscountValue,
      businessTypes: businessTypes ?? this.businessTypes,
      themeStyle: themeStyle ?? this.themeStyle,
      loyaltyCardStyle: loyaltyCardStyle ?? this.loyaltyCardStyle,
      singleAttendant: singleAttendant ?? this.singleAttendant,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      referralPoints: referralPoints ?? this.referralPoints,
      onboardingScreen: onboardingScreen ?? this.onboardingScreen,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      closedDates: closedDates ?? this.closedDates,
    );
  }

  String get voucherDiscountLabel {
    if (voucherDiscountType == 'percent') {
      return '${voucherDiscountValue.toStringAsFixed(0)}% off';
    }
    return 'R\$ ${voucherDiscountValue.toStringAsFixed(2).replaceAll('.', ',')} off';
  }

  /// Rótulo amigável do(s) tipo(s) de estabelecimento.
  String get businessTypeLabel {
    if (businessTypes.isEmpty) return 'Negócio';
    const labels = {
      'barbershop': 'Barbearia',
      'beauty_salon': 'Salão de Beleza',
      'manicure': 'Manicure',
      'pedicure': 'Pedicure',
      'manicure_pedicure': 'Manicure e Pedicure', // legado; opção removida do seletor
      'eyebrows': 'Sobrancelhas',
      'lash_design': 'Lash Design',
    };
    return businessTypes.map((e) => labels[e] ?? e).join(', ');
  }
}
