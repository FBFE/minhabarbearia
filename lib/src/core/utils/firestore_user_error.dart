import 'package:firebase_core/firebase_core.dart';

/// Mensagem legível para erros do Firestore (especialmente na web,
/// onde falhas vindas do JS aparecem como "Dart exception thrown from converted Future").
String firestoreUserVisibleError(Object error) {
  if (error is FirebaseException) {
    final msg = error.message ?? '';
    if (error.code == 'permission-denied') {
      return 'Sem permissão nesta operação. Use a conta de dono do negócio.';
    }
    if (msg.isNotEmpty) {
      return '${error.code}: $msg';
    }
    return error.code;
  }

  final raw = error.toString();
  if (raw.contains('Dart exception thrown from converted Future')) {
    try {
      final dynamic boxed = error;
      final inner = boxed.error;
      if (inner != null) {
        final innerStr = inner.toString();
        if (innerStr.isNotEmpty && !innerStr.contains('Dart exception thrown from converted Future')) {
          return innerStr;
        }
      }
    } catch (_) {}
    return 'Falha ao falar com o Firestore na web (rede ou sessão). '
        'Atualize a página ou tente de novo.';
  }

  return raw.length > 280 ? '${raw.substring(0, 277)}…' : raw;
}
