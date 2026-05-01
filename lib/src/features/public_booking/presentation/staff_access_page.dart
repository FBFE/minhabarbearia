import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/staff.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';

/// Página de acesso do funcionário: entra com o e-mail cadastrado pelo dono.
/// Não redireciona para "Completar perfil" (cliente); apenas confirma e vai para a página do negócio.
class StaffAccessPage extends ConsumerStatefulWidget {
  const StaffAccessPage({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<StaffAccessPage> createState() => _StaffAccessPageState();
}

class _StaffAccessPageState extends ConsumerState<StaffAccessPage> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      final provider = GoogleAuthProvider();
      final cred = await auth.signInWithPopup(provider);
      final user = cred.user;
      if (user == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      final email = (user.email ?? '').trim().toLowerCase();
      final staffList = await ref.read(staffProvider(widget.slug).future);
      Staff? staff;
      for (final s in staffList) {
        if ((s.email).trim().toLowerCase() == email) {
          staff = s;
          break;
        }
      }

      if (!mounted) {
        setState(() => _loading = false);
        return;
      }

      if (staff != null) {
        ref.read(currentStaffProvider.notifier).state = (slug: widget.slug, staff: staff);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você entrou como funcionário. Veja os horários marcados com você.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/b/${widget.slug}/funcionario/agenda');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este e-mail não está cadastrado como funcionário. Peça ao dono para adicionar seu e-mail ou use o link da página para agendar como cliente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        // Opção de ir para a página de cliente
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Não é funcionário'),
              content: const Text(
                'Seu e-mail não está na lista de funcionários deste estabelecimento. '
                'Deseja ir para a página de agendamento como cliente?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Ficar aqui'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/b/${widget.slug}/funcionario');
                  },
                  child: const Text('Ir para agendamento'),
                ),
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barberShopAsync = ref.watch(barberShopBySlugProvider(widget.slug));
    final primary = Theme.of(context).colorScheme.primary;

    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso funcionário')),
            body: const Center(child: Text('Estabelecimento não encontrado.')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            title: const Text('Acesso do funcionário'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/b/${widget.slug}/funcionario'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Icon(Icons.badge_outlined, size: 64, color: primary),
                  const SizedBox(height: 16),
                  Text(
                    'Acesso do funcionário',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D21),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entre com o e-mail que o dono cadastrou para você em ${shop.name}. '
                    'Assim você não será redirecionado para o cadastro de cliente.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF5C636A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 26),
                    label: Text(_loading ? 'Entrando...' : 'Entrar com Google'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/b/${widget.slug}/funcionario'),
                      child: Text(
                        'Sou cliente, quero agendar',
                        style: GoogleFonts.poppins(color: primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Acesso funcionário')),
        body: Center(child: Text('Erro: $e')),
      ),
    );
  }
}
