import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logic/client_google_auth_flow.dart';

class ClientLoginPage extends ConsumerStatefulWidget {
  final String slug;
  final String? refInvite;

  const ClientLoginPage({super.key, required this.slug, this.refInvite});

  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  bool _busy = false;

  Future<void> _onGoogle() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await runClientGoogleAuthAndRoute(
        ref: ref,
        context: context,
        slug: widget.slug,
        referralRef: widget.refInvite,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _inviteQuery() =>
      widget.refInvite != null && widget.refInvite!.trim().isNotEmpty
          ? '?ref=${Uri.encodeComponent(widget.refInvite!.trim())}'
          : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
        actions: [
          TextButton(
            onPressed: () => context.go('/b/${widget.slug}/cadastro${_inviteQuery()}'),
            child: const Text('Cadastro'),
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
                  'Área do cliente',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWeb
                      ? 'Primeira vez? O mesmo botão cria sua conta. Depois você completa seus dados.'
                      : 'Use a página web deste estabelecimento para entrar com Google.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: Icon(kIsWeb ? Icons.login : Icons.info_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      kIsWeb
                          ? (_busy ? 'Abrindo Google…' : 'Continuar com Google')
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
