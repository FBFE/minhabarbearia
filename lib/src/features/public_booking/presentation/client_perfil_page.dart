import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/barber_shop_providers.dart';
import 'public_shop_hero_header.dart';

/// Perfil do cliente: dados, pontos, histórico de atendimentos e botão Agendar.
class ClientPerfilPage extends ConsumerWidget {
  const ClientPerfilPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(currentPublicClientProvider);
    final barberShopAsync = ref.watch(barberShopBySlugProvider(slug));
    if (clientState == null || clientState.slug != slug) {
      return _VerifyFirstView(slug: slug);
    }
    final client = clientState.client;
    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) return const Scaffold(body: Center(child: Text('Negócio não encontrado')));
        final primary = shop.primaryColorAsColor;
        final phone = client.whatsapp.length >= 10
            ? '(${client.whatsapp.substring(0, 2)}) ${client.whatsapp.length == 11 ? client.whatsapp.substring(2, 7) : client.whatsapp.substring(2, 6)}-${client.whatsapp.length == 11 ? client.whatsapp.substring(7) : client.whatsapp.substring(6)}'
            : client.whatsapp;

        Future<void> onRefresh() async {
          ref.invalidate(
            clientInShopByIdStreamProvider((slug: slug, clientId: client.id)),
          );
          ref.invalidate(barberShopBySlugProvider(slug));
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              SliverToBoxAdapter(
                child: PublicShopHeroHeader(shop: shop, primary: primary, height: 200, overlayOnly: true),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seu Perfil',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1D21),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        shadowColor: Colors.black12,
                        child: IconButton(
                          tooltip: 'Configurações',
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF5C636A)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Configurações em breve.')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _ProfileSummaryCard(
                    clientName: client.name,
                    phone: phone,
                    stamps: client.stamps,
                    visits: client.totalAppointments,
                    primary: primary,
                    photoUrl: client.photoUrl,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProfileMenuCard(
                    slug: slug,
                    onLogout: () => _confirmLogout(context, ref, slug),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/b/$slug/agendar'),
                      icon: const Icon(Icons.calendar_today_rounded, size: 22),
                      label: Text(
                        'Agendar horário',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(child: CircularProgressIndicator(color: const Color(0xFFFF4081))),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref, String slug) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair da conta?'),
      content: const Text('Você precisará informar seu WhatsApp novamente para acessar a agenda.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sair')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    ref.read(currentPublicClientProvider.notifier).state = null;
    context.go('/b/$slug/agendar');
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.clientName,
    required this.phone,
    required this.stamps,
    required this.visits,
    required this.primary,
    this.photoUrl,
  });

  final String clientName;
  final String phone;
  final int stamps;
  final int visits;
  final Color primary;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: primary.withValues(alpha: 0.2),
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              clientName,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D21),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              phone,
              style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF5C636A)),
              textAlign: TextAlign.center,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, color: Color(0xFFE5E5E5)),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$stamps',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SELOS',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: const Color(0xFF8E9399),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 44, color: const Color(0xFFE5E5E5)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$visits',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VISITAS',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: const Color(0xFF8E9399),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.slug,
    required this.onLogout,
  });

  final String slug;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Column(
        children: [
          _ProfileMenuRow(
            icon: Icons.card_giftcard_rounded,
            iconBg: const Color(0xFFFFF8E1),
            iconColor: const Color(0xFFFFA000),
            title: 'Meu Cartão Fidelidade',
            onTap: () => context.go('/b/$slug/fidelidade'),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _ProfileMenuRow(
            icon: Icons.history_rounded,
            iconBg: const Color(0xFFF0F0F0),
            iconColor: const Color(0xFF5C636A),
            title: 'Histórico de Agendamentos',
            onTap: () => context.go('/b/$slug/agenda'),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _ProfileMenuRow(
            icon: Icons.logout_rounded,
            iconBg: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            title: 'Sair da conta',
            titleColor: const Color(0xFFE53935),
            showChevron: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor = const Color(0xFF1A1D21),
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              if (showChevron)
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B0B0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifyFirstView extends StatelessWidget {
  const _VerifyFirstView({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: 64, color: const Color(0xFF5C636A)),
              const SizedBox(height: 16),
              Text(
                'Verifique seu cadastro',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1D21)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Na página de agendamento use Entrar ou Cadastrar e faça login com sua conta Google (versão web do link).',
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/b/$slug/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Entrar com Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/b/$slug/agendar'),
                child: Text('Ir para página inicial', style: GoogleFonts.poppins(color: const Color(0xFF5C636A))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
