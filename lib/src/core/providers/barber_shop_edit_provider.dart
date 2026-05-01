import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/barber_shop.dart';

/// Cor de fundo padrão quando não definida (quase preto).
const _defaultBackgroundColor = Color(0xFF0D0D0F);

/// Estado da edição do negócio (cores, preview da logo, uploading).
class BarberShopEditState {
  final Color selectedColor;
  final Color selectedSecondaryColor;
  final Color selectedBackgroundColor;
  final Uint8List? selectedLogoFile;
  final Uint8List? selectedBackgroundFile;
  final bool uploading;

  const BarberShopEditState({
    required this.selectedColor,
    required this.selectedSecondaryColor,
    this.selectedBackgroundColor = _defaultBackgroundColor,
    this.selectedLogoFile,
    this.selectedBackgroundFile,
    this.uploading = false,
  });

  BarberShopEditState copyWith({
    Color? selectedColor,
    Color? selectedSecondaryColor,
    Color? selectedBackgroundColor,
    Uint8List? selectedLogoFile,
    Uint8List? selectedBackgroundFile,
    bool? uploading,
    bool clearLogoFile = false,
    bool clearBackgroundFile = false,
  }) {
    return BarberShopEditState(
      selectedColor: selectedColor ?? this.selectedColor,
      selectedSecondaryColor: selectedSecondaryColor ?? this.selectedSecondaryColor,
      selectedBackgroundColor: selectedBackgroundColor ?? this.selectedBackgroundColor,
      selectedLogoFile: clearLogoFile ? null : (selectedLogoFile ?? this.selectedLogoFile),
      selectedBackgroundFile: clearBackgroundFile ? null : (selectedBackgroundFile ?? this.selectedBackgroundFile),
      uploading: uploading ?? this.uploading,
    );
  }
}

class BarberShopEditNotifier extends StateNotifier<BarberShopEditState> {
  BarberShopEditNotifier()
      : super(const BarberShopEditState(
          selectedColor: Color(0xFF212121),
          selectedSecondaryColor: Color(0xFF424242),
        ));

  /// Inicializa a partir do negócio atual (ao abrir o sheet).
  void initFrom(BarberShop? initial) {
    state = BarberShopEditState(
      selectedColor: initial != null
          ? Color(initial.primaryColor)
          : const Color(0xFF673AB7),
      selectedSecondaryColor: initial != null
          ? Color(initial.secondaryColor)
          : const Color(0xFF1A1A2E),
      selectedBackgroundColor: initial?.backgroundColorAsColor ?? _defaultBackgroundColor,
      selectedLogoFile: null,
      selectedBackgroundFile: null,
      uploading: false,
    );
  }

  void setSelectedColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  void setSelectedSecondaryColor(Color color) {
    state = state.copyWith(selectedSecondaryColor: color);
  }

  void setSelectedBackgroundColor(Color color) {
    state = state.copyWith(selectedBackgroundColor: color);
  }

  void setSelectedLogoFile(Uint8List? bytes) {
    state = bytes == null
        ? state.copyWith(clearLogoFile: true)
        : state.copyWith(selectedLogoFile: bytes);
  }

  void setSelectedBackgroundFile(Uint8List? bytes) {
    state = bytes == null
        ? state.copyWith(clearBackgroundFile: true)
        : state.copyWith(selectedBackgroundFile: bytes);
  }

  void setUploading(bool value) {
    state = state.copyWith(uploading: value);
  }
}

final barberShopEditProvider =
    StateNotifierProvider<BarberShopEditNotifier, BarberShopEditState>(
  (ref) => BarberShopEditNotifier(),
);
