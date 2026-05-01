import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// MIME para [FirebaseStorage.putData] quando enviamos bytes crus (sem JPEG da app).
String storageContentTypeForBytes(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    if (String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'image/webp';
  }
  return 'image/jpeg';
}

/// Redimensiona e comprime imagem para exibição leve em celular.
/// - Largura máxima 480px (suficiente para tela de celular).
/// - JPEG qualidade 82 (~80–150 KB típico).
/// Retorna null se falhar ao decodificar.
Uint8List? resizeAndCompressForMobile(Uint8List bytes, {int maxWidth = 480, int jpegQuality = 82}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    img.Image resized = decoded;
    if (decoded.width > maxWidth) {
      resized = img.copyResize(decoded, width: maxWidth);
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  } catch (_) {
    return null;
  }
}
