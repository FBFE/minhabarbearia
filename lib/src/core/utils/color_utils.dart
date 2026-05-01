import 'package:flutter/material.dart';

/// Converte string hex (ex: "#673AB7" ou "673AB7") para Color.
Color hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF673AB7);
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse('0xFF$h');
  return Color(v ?? 0xFF673AB7);
}

/// Converte string hex para int (para Firestore/JSON).
int hexToInt(String? hex) {
  if (hex == null || hex.isEmpty) return 0xFF673AB7;
  final h = hex.replaceFirst('#', '');
  return int.tryParse('0xFF$h') ?? 0xFF673AB7;
}

/// Converte int para string hex.
String intToHex(int color) {
  return '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

/// Converte Color para string hex (6 dígitos RGB, sem alpha).
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
