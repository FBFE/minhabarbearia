import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/barber_shop.dart';
import 'barber_shop_providers.dart';

final currentSlugProvider = StateProvider<String?>((ref) => null);

/// Fundo fixo branco em todo o app (não editável).
const _scaffoldWhite = Color(0xFFFFFFFF);
const _cardBg = Color(0xFFF5F6F8);
const _onSurface = Color(0xFF1A1D21);
const _onSurfaceSecondary = Color(0xFF5C636A);

/// Design reference: tokens (Responsive design)
const _designPurple = Color(0xFF9333EA);   // purple-600 (auth, accent)
const _designPurple50 = Color(0xFFFAF5FF);
const _designPink50 = Color(0xFFFDF2F8);
const _designGray50 = Color(0xFFF9FAFB);
const _designGray200 = Color(0xFFE5E7EB);
const _designInputBg = Color(0xFFF3F3F5);
const _designRadius = 10.0;  // 0.625rem
const _designRadiusLg = 12.0;

/// Cor primária padrão do app (tela inicial, login) = roxo do design.
const defaultPrimaryBlack = 0xFF9333EA;
const defaultSecondaryBlack = 0xFF7C3AED;

/// Combinações de cores pré-definidas (primária + secundária) para bom contraste no fundo branco.
enum ColorPreset {
  preto('Preto', 0xFF212121, 0xFF424242),
  rosa('Rosa', 0xFFFF4081, 0xFFE91E63),
  azul('Azul', 0xFF2196F3, 0xFF1976D2),
  verde('Verde', 0xFF4CAF50, 0xFF388E3C),
  marrom('Marrom', 0xFF795548, 0xFF5D4037),
  roxo('Roxo', 0xFF673AB7, 0xFF512DA8),
  /// Tema em cores arco-íris (primária e secundária inspiradas na bandeira).
  arcoiris('Arco-íris', 0xFF750787, 0xFFE40303);

  const ColorPreset(this.label, this.primary, this.secondary);
  final String label;
  final int primary;
  final int secondary;
  Color get primaryColor => Color(primary);
  Color get secondaryColor => Color(secondary);
}

/// Retorna o preset cujo primary mais se aproxima do valor do negócio (para compatibilidade).
ColorPreset presetFromBarberShop(BarberShop shop) {
  final p = shop.primaryColor & 0x00FFFFFF;
  int best = 0;
  int bestDiff = 0xFFFFFF;
  for (var i = 0; i < ColorPreset.values.length; i++) {
    final diff = (p - (ColorPreset.values[i].primary & 0x00FFFFFF)).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return ColorPreset.values[best];
}

final dynamicThemeProvider = Provider<ThemeData>((ref) {
  final ownerShopAsync = ref.watch(barberShopProvider);
  final ownerShop = ownerShopAsync.valueOrNull;
  if (ownerShop != null) return _buildLightTheme(ownerShop);

  final slug = ref.watch(currentSlugProvider);
  if (slug == null || slug.isEmpty) return _defaultLightTheme;

  final barberShopAsync = ref.watch(barberShopBySlugProvider(slug));
  return barberShopAsync.when(
    data: (shop) => _buildLightTheme(shop),
    loading: () => _defaultLightTheme,
    error: (_, __) => _defaultLightTheme,
  );
});

ThemeData _buildLightTheme(BarberShop? shop) {
  if (shop == null) return _defaultLightTheme;

  final preset = presetFromBarberShop(shop);
  final primary = preset.primaryColor;
  final secondary = preset.secondaryColor;

  return ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme.apply(
        bodyColor: _onSurface,
        displayColor: _onSurface,
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: _scaffoldWhite,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceSecondary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: _scaffoldWhite,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(color: _onSurfaceSecondary, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: _onSurfaceSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: _cardBg,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

final _defaultLightTheme = ThemeData(
  useMaterial3: true,
  textTheme: GoogleFonts.poppinsTextTheme(
    ThemeData.light().textTheme.apply(
      bodyColor: _onSurface,
      displayColor: _onSurface,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: _designPurple,
    secondary: const Color(defaultSecondaryBlack),
    surface: _scaffoldWhite,
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceSecondary,
  ),
  scaffoldBackgroundColor: _scaffoldWhite,
  appBarTheme: AppBarTheme(
    backgroundColor: _scaffoldWhite,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: _onSurface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: _onSurface,
    ),
    iconTheme: const IconThemeData(color: _onSurface),
  ),
  cardTheme: CardThemeData(
    color: _cardBg,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_designRadiusLg),
      side: const BorderSide(color: _designGray200, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _designInputBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(_designRadius)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_designRadius),
      borderSide: const BorderSide(color: _designGray200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_designRadius),
      borderSide: const BorderSide(color: _designPurple, width: 2),
    ),
    labelStyle: GoogleFonts.poppins(color: _onSurfaceSecondary, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _designPurple,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_designRadius),
      ),
      elevation: 0,
    ),
  ),
);

/// Cores do design para uso em telas de auth (gradiente, etc.)
const designAuthPurple = _designPurple;
const designAuthPurple50 = _designPurple50;
const designAuthPink50 = _designPink50;
const designScaffoldGray50 = _designGray50;
const designBorderGray200 = _designGray200;
