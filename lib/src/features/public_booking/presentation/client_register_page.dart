import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/client_google_auth_flow.dart';

/// Cadastro público só com Google: novos usuários são levados a completar o perfil.
class ClientRegisterPage extends ConsumerStatefulWidget {
  const ClientRegisterPage({super.key, required this.slug, this.refParam});

  final String slug;
  final String? refParam;

  @override
  ConsumerState<ClientRegisterPage> createState() => _ClientRegisterPageState();
}

class _ClientRegisterPageState extends ConsumerState<ClientRegisterPage> {
  bool _busy = false;

  String _inviteQuery() =>
      widget.refParam != null && widget.refParam!.trim().isNotEmpty
          ? '?ref=${Uri.encodeComponent(widget.refParam!.trim())}'
          : '';

  Future<void> _onGoogle() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await runClientGoogleAuthAndRoute(
        ref: ref,
        context: context,
        slug: widget.slug,
        referralRef: widget.refParam,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        actions: [
          TextButton(
            onPressed: () => context.go('/b/${widget.slug}/login${_inviteQuery()}'),
            child: const Text('Já tenho conta'),
          ),
          TextButton(
            onPressed: () => context.go('/b/${widget.slug}/agendar${_inviteQuery()}'),
            child: const Text('Agendar sem conta'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nova conta',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWeb
                      ? 'Use sua conta Google. Na primeira vez você preenche nome, WhatsApp e data de nascimento.'
                      : 'Use a versão web do link para criar conta com Google.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: Icon(kIsWeb ? Icons.person_add_alt_1_rounded : Icons.info_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      kIsWeb
                          ? (_busy ? 'Abrindo Google…' : 'Cadastrar com Google')
                          : 'Disponível na versão web',
                    ),
                  ),
                  onPressed: (!kIsWeb || _busy) ? null : _onGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
