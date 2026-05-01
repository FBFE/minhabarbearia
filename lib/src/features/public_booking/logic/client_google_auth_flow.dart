import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pwa_install/pwa_install.dart';

import '../../../core/models/staff.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';

/// Login/cadastro do cliente na página pública: apenas Google (web).
///
/// [referralRef] opcional (?ref=...) — vai para completar perfil quando for novo cliente.
Future<void> runClientGoogleAuthAndRoute({
  required WidgetRef ref,
  required BuildContext context,
  required String slug,
  String? referralRef,
}) async {
  if (!kIsWeb) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O acesso com Google para clientes está disponível na versão web do link do estabelecimento.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  final auth = ref.read(firebaseAuthProvider);
  try {
    final cred = await auth.signInWithPopup(GoogleAuthProvider());
    final user = cred.user;
    if (user == null || !context.mounted) return;

    final uid = user.uid;
    final email = (user.email ?? '').trim().toLowerCase();

    final staffList = await ref.read(staffProvider(slug).future);
    if (!context.mounted) return;

    Staff? staff;
    for (final s in staffList) {
      if (s.email.trim().toLowerCase() == email) {
        staff = s;
        break;
      }
    }
    if (staff != null) {
      ref.read(currentStaffProvider.notifier).state = (slug: slug, staff: staff);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrou como funcionário. Veja os horários marcados com você.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/b/$slug/funcionario/agenda');
      }
      return;
    }

    final client = await ref.read(clientByAuthUidProvider((slug: slug, authUid: uid)).future);
    if (!context.mounted) return;

    if (client != null) {
      ref.read(currentPublicClientProvider.notifier).state = (slug: slug, client: client);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso salvo.'), backgroundColor: Colors.green),
        );
      }
      if (context.mounted && PWAInstall().installPromptEnabled) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Salvar como app'),
            content: const Text(
              'Deseja salvar esta página como app no seu celular ou computador?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Agora não')),
              FilledButton.icon(
                onPressed: () {
                  PWAInstall().promptInstall_();
                  Navigator.of(ctx).pop(true);
                },
                icon: const Icon(Icons.get_app, size: 20),
                label: const Text('Salvar como app'),
              ),
            ],
          ),
        );
      }
      if (context.mounted) context.go('/b/$slug/perfil');
    } else {
      if (!context.mounted) return;
      final refTrimmed = referralRef?.trim();
      context.go(
        '/b/$slug/complete-profile',
        extra: {
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'uid': uid,
          'photoUrl': user.photoURL,
          'authMethod': 'google',
          if (refTrimmed != null && refTrimmed.isNotEmpty) 'referralRef': refTrimmed,
        },
      );
    }
  } on FirebaseAuthException catch (e) {
    if (context.mounted) {
      if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao entrar com Google: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
