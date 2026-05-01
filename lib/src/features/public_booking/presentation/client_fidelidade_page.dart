import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/barber_shop.dart';
import '../../../core/models/client.dart';
import '../../../core/providers/barber_shop_providers.dart';
import 'public_shop_hero_header.dart';

/// Cartão Fidelidade: selos circulares, texto dinâmico, QR do cupom, botão Agendar.
class ClientFidelidadePage extends ConsumerWidget {
  const ClientFidelidadePage({super.key, required this.slug});
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
        // [PublicShellPage] aplica o fundo do negócio; conteúdo transparente.
        return _FidelidadeContent(barberShop: shop, client: client);
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFFFF4081)),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
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
              Icon(Icons.card_giftcard_rounded, size: 64, color: const Color(0xFF5C636A)),
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

class _FidelidadeContent extends ConsumerWidget {
  const _FidelidadeContent({required this.barberShop, required this.client});
  final BarberShop barberShop;
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(vouchersForClientProvider((
      slug: barberShop.slug,
      clientWhatsapp: client.whatsapp,
    )));
    final primary = barberShop.primaryColorAsColor;
    const gold = Color(0xFFFFB300);
    const selosTotal = 10;
    final remainder = client.totalAppointments % selosTotal;
    final filledCount = (remainder == 0 && client.totalAppointments > 0) ? selosTotal : remainder;
    final faltam = filledCount == selosTotal ? 0 : (selosTotal - filledCount);
    final canShowQr = client.loyaltyPoints >= (barberShop.loyaltyPointsRequired);

    Future<void> onRefresh() async {
      final s = barberShop.slug;
      ref.invalidate(
        vouchersForClientProvider((
          slug: s,
          clientWhatsapp: client.whatsapp,
        )),
      );
      ref.invalidate(
        clientInShopByIdStreamProvider((slug: s, clientId: client.id)),
      );
      ref.invalidate(barberShopBySlugProvider(s));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        SliverToBoxAdapter(
          child: PublicShopHeroHeader(shop: barberShop, primary: primary, height: 180, overlayOnly: true),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEU PROGRESSO',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFA726),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$filledCount / $selosTotal',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFA726)),
                            ),
                            child: Text(
                              '$faltam RESTANTES',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFA726),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(selosTotal, (i) {
                          if (i < filledCount) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFB300),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, size: 22, color: Color(0xFF121212)),
                            );
                          }
                          if (i < selosTotal - 1) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF4A4A4A),
                                  style: BorderStyle.solid,
                                ),
                                color: const Color(0xFF2A2A2A),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF7A7A7A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4A4A4A)),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF7A7A7A), size: 20),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.card_giftcard_rounded, color: gold, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Como funciona?',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1D21),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _rule(
                        'Cada serviço realizado garante 1 selo no seu cartão.',
                        primary,
                      ),
                      _rule(
                        'Ao completar 10 selos, você ganha benefício (voucher) conforme a regra do negócio.',
                        primary,
                      ),
                      _rule(
                        'O benefício é pessoal. Validade: conforme o negócio (ex.: 6 meses).',
                        primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (filledCount == selosTotal)
                  Text(
                    'Parabéns! Use seu benefício na próxima visita.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  )
                else
                  Text(
                    filledCount == 0
                        ? 'Faltam $selosTotal serviços para o próximo benefício.'
                        : 'Faltam $faltam ${faltam == 1 ? 'selo' : 'selos'}.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5C636A),
                    ),
                  ),
                const SizedBox(height: 20),
                vouchersAsync.when(
                  data: (vouchers) {
                    if (vouchers.isEmpty && !canShowQr) return const SizedBox.shrink();
                    final voucher = vouchers.isNotEmpty ? vouchers.first : null;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Meu cupom',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1D21),
                              ),
                            ),
                            if (voucher != null) ...[
                              const SizedBox(height: 16),
                              QrImageView(
                                data: voucher.code,
                                version: QrVersions.auto,
                                size: 160,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF121212),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF121212),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                voucher.code,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                              Text(
                                voucher.discountLabel,
                                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                              ),
                            ] else if (canShowQr)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Você tem pontos para gerar cupom. Conclua um agendamento ou peça no negócio.',
                                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 20),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/b/${barberShop.slug}/agendar'),
                    icon: const Icon(Icons.calendar_today_rounded, size: 22),
                    label: Text(
                      'Agendar',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF1A1D21),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  static Widget _rule(String t, Color bullet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.poppins(color: bullet, fontSize: 16)),
          Expanded(
            child: Text(
              t,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF5C636A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

