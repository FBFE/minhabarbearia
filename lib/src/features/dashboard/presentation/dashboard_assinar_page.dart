import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/stripe_config.dart';
import '../../../core/providers/barber_shop_providers.dart';

/// Página de assinatura: assinatura mensal (Stripe).
class DashboardAssinarPage extends ConsumerStatefulWidget {
  const DashboardAssinarPage({
    super.key,
    this.checkoutSessionId,
    this.checkoutSuccess = false,
  });
  final String? checkoutSessionId;
  final bool checkoutSuccess;

  @override
  ConsumerState<DashboardAssinarPage> createState() => _DashboardAssinarPageState();
}

class _DashboardAssinarPageState extends ConsumerState<DashboardAssinarPage> {
  static const _functionsRegion = 'us-central1';
  bool _loading = false;
  /// True depois de voltar do Checkout com [checkoutSessionId] até terminar a callable.
  bool _awaitingReturnConfirm = false;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: _functionsRegion,
      );

  Future<void> _startCheckout(String slug) async {
    if (!stripeMonthlyPriceId.startsWith('price_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure stripeMonthlyPriceId em lib/src/config/stripe_config.dart'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final origin = Uri.base.origin;
      final successUrl =
          '$origin/dashboard/assinar?session_id={CHECKOUT_SESSION_ID}&success=1';
      final cancelUrl = '$origin/dashboard/assinar';

      final callable = _functions.httpsCallable('createCheckoutSession');
      final result = await callable.call({
        'slug': slug,
        'priceId': stripeMonthlyPriceId,
        'mode': 'subscription',
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      });
      final raw = result.data;
      if (raw == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resposta vazia do servidor.'), backgroundColor: Colors.red),
        );
        return;
      }
      String? url;
      try {
        final data = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
        url = data['url'] as String?;
      } catch (_) {
        // Fallback: ler só o campo url (evita Int64 em outros campos no dart2js)
        if (raw is Map) url = raw['url'] as String?;
      }
      if (url != null && url.isNotEmpty && mounted) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Não foi possível abrir: $url'), backgroundColor: Colors.orange),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resposta inválida do servidor.'), backgroundColor: Colors.red),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? e.code),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final isInt64 = msg.contains('Int64');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInt64
                  ? 'Erro técnico no navegador. Tente em outro navegador ou no celular.'
                  : 'Erro: $msg',
            ),
            backgroundColor: Colors.red,
            duration: isInt64 ? const Duration(seconds: 5) : const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final id = widget.checkoutSessionId;
    if (widget.checkoutSuccess && id != null && id.isNotEmpty) {
      _awaitingReturnConfirm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAfterStripeReturn(id);
      });
    }
  }

  Future<void> _syncAfterStripeReturn(String sessionId) async {
    try {
      final callable = _functions.httpsCallable('syncSubscriptionFromCheckout');
      await callable.call(<String, dynamic>{'sessionId': sessionId});
      ref.invalidate(barberShopProvider);
      if (mounted) {
        context.go('/dashboard/assinar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assinatura ativada. Obrigado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? e.code),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível confirmar o pagamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _awaitingReturnConfirm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barberShopAsync = ref.watch(barberShopProvider);
    final primary = Theme.of(context).colorScheme.primary;

    const designGray50 = Color(0xFFF9FAFB);
    const designGray200 = Color(0xFFE5E7EB);
    const designGray900 = Color(0xFF1A1D21);

    return Scaffold(
      backgroundColor: designGray50,
      appBar: AppBar(
        title: Text(
          'Assinatura',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: designGray900,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: designGray900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: designGray900),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: designGray200),
        ),
      ),
      body: barberShopAsync.when(
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Carregue seu negócio no dashboard.'));
          }
          final slug = shop.slug;
          if (_awaitingReturnConfirm) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Confirmando pagamento com o servidor...'),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Continuar usando o app',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Assinatura mensal. Você será redirecionado ao Stripe para pagar com segurança.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF5C636A),
                  ),
                ),
                const SizedBox(height: 32),
                _OptionCard(
                  icon: Icons.autorenew_rounded,
                  title: 'Assinatura mensal',
                  subtitle: 'Cobrança automática no cartão todo mês. Cancele quando quiser.',
                  primary: primary,
                  loading: _loading,
                  onTap: () => _startCheckout(slug),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pagamento processado pelo Stripe. Seu trial ou assinatura atual segue válido até a confirmação.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.loading,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primary;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Icon(icon, color: primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
