// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barber_shop.dart';

BarberShop _$BarberShopFromJson(Map<String, dynamic> json) => BarberShop(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      ownerUid: json['ownerUid'] as String?,
      logoUrl: json['logoUrl'] as String?,
      primaryColor: BarberShop._colorFromJson(json['primaryColor']),
      secondaryColor: BarberShop._colorFromJson(json['secondaryColor']),
      plan: json['plan'] as String? ?? 'basic',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$BarberShopToJson(BarberShop instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'ownerUid': instance.ownerUid,
      'logoUrl': instance.logoUrl,
      'primaryColor': BarberShop._colorToJson(instance.primaryColor),
      'secondaryColor': BarberShop._colorToJson(instance.secondaryColor),
      'plan': instance.plan,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
