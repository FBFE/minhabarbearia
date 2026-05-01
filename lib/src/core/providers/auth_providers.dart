import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Stream do estado de autenticação (login/logout em tempo real).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Usuário atual logado ou null se deslogado.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull;
});

/// true se o usuário está logado, false caso contrário.
/// Use em ConsumerWidget: ref.watch(isLoggedInProvider)
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Alias para isLoggedInProvider.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(isLoggedInProvider);
});
