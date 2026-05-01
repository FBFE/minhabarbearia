import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/subscription_access.dart';
import '../../../core/subscription_remorse.dart';
const _kFunctionsRegion = 'us-central1';
FirebaseFunctions _ff() => FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: _kFunctionsRegion,
    );

/// Assinatura: período, cancelar fim de período, reembolso, histórico.
class DashboardBillingPage extends ConsumerStatefulWidget {
  const DashboardBillingPage({super.key});

  @override
  ConsumerState<DashboardBillingPage> createState() => _DashboardBillingPageState();
}

class _DashboardBillingPageState extends ConsumerState<DashboardBillingPage> {
  bool _loading = false;

  Future<void> _callAction(String name, String slug) async {
    setState(() => _loading = true);
    try {
      final c = _ff().httpsCallable(name);
      await c.call(<String, dynamic>{'slug': slug});
      ref.invalidate(barberShopProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concluído.'), backgroundColor: Colors.green),
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
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _centsFrom(dynamic amount) {
    if (amount is int) return amount;
    if (amount is num) return amount.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    const designGray50 = Color(0xFFF9FAFB);
    const designGray200 = Color(0xFFE5E7EB);
    const designGray900 = Color(0xFF1A1D21);
    const designMuted = Color(0xFF5C636A);
    final primary = Theme.of(context).colorScheme.primary;
    final shopAsync = ref.watch(barberShopProvider);
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

    return Scaffold(
      backgroundColor: designGray50,
      appBar: AppBar(
        title: Text(
          'Assinatura e faturas',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: designGray200),
        ),
      ),
      body: shopAsync.when(
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('Crie o negócio no dashboard.'));
          }
          final hasAccess = barberShopHasProAccess(shop);
          final end = shop.subscriptionCurrentPeriodEnd;
          final endStr = end != null
              ? DateFormat('dd/MM/yyyy, HH:mm').format(end)
              : '—';
          final paidAt = shop.subscriptionLastInvoicePaidAt;
          final paidAtStr = paidAt != null
              ? DateFormat('dd/MM/yyyy, HH:mm').format(paidAt)
              : '—';
          final remorseEnds = shop.remorseRefundPeriodEnd;
          final remorseEndsStr = remorseEnds != null
              ? DateFormat('dd/MM/yyyy, HH:mm').format(remorseEnds)
              : '—';
          final showRefundBtn = shop.mayShowAutomaticRefundButton(hasProAccess: hasAccess);
          final showCancelRenewBtn = shop.mayCancelRenewalInsteadOfRefund(hasProAccess: hasAccess);
          final eventsAsync = ref.watch(billingEventsProvider(shop.slug));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Plano: ${shop.plan == 'pro' ? 'Pro' : 'Básico'} · ${shop.subscriptionStatus}',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: designGray900,
                ),
              ),
              const SizedBox(height: 8),
              if (end != null)
                Text(
                  hasAccess
                      ? (shop.cancelAtPeriodEnd
                            ? 'Renovação desativada. Acesso pago até $endStr.'
                            : 'Próxima renovação em torno de $endStr (ciclo ~30 dias, conforme Stripe).')
                      : 'Período pago encerrado ($endStr).',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: designMuted,
                    height: 1.35,
                  ),
                ),
              if (paidAt != null && shop.subscriptionStatus == 'active' && shop.stripeSubscriptionId != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Último pagamento registado neste período: $paidAtStr. '
                  'Estorno por arrependimento disponível até: $remorseEndsStr.',
                  style: GoogleFonts.poppins(fontSize: 12, color: designMuted, height: 1.35),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel_outlined, color: Colors.indigo.shade700, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Corte por arrependimento e trial de cadastro',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: designGray900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Trial de cadastro (7 dias): ao criares o negócio, ganhas período gratuito para '
                      'testar o sistema — sem cobrança. Isso não é pagamento Stripe.\n\n'
                      '• Após pagares no Stripe — durante 7 dias corridos desde essa cobrança: aparece '
                      '«solicitar reembolso»; ao confirmares, o estorno é feito na Stripe e o acesso Pro '
                      'é bloqueado de imediato (não ficas no restante do período já pago).\n\n'
                      '• Depois desses 7 dias e até ao fim do ciclo atual (cerca de ~30 dias desde o Stripe): '
                      'só aparece «cancelar renovação» — o Pro continua ativo até ${end != null ? endStr : 'a data de fim do período pago'}, '
                      'sem cobrança do mês seguinte.\n\n'
                      '• Trava de reincidência: se este negócio já usou reembolso automático antes, mesmo '
                      'voltando a assinar, não há segundo reembolso automático no app — apenas cancelamento da renovação.',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: designMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (shop.stripeSubscriptionId != null && shop.subscriptionStatus == 'refunded') ...[
                Text(
                  'Acesso Pro encerrado (reembolso).',
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (shop.explainsWhyRefundHiddenOnlyCancel) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Os 7 dias contados desde o pagamento atual já passaram neste ciclo — '
                    'o estorno pela app não está disponível. Usa cancelar renovação para '
                    'não ser cobrado no período seguinte e manter Pro até ao fim do ciclo atual.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (shop.isBlockedFromAutomaticRefund &&
                  showCancelRenewBtn &&
                  shop.subscriptionStatus == 'active') ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Este negócio já utilizou reembolso automático no passado. '
                    'Podes apenas cancelar a renovação; não há novo reembolso automático por novas assinaturas.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: const Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (showCancelRenewBtn) ...[
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancelar renovação?'),
                                content: Text(
                                  'A assinatura deixa de renovar após o fim do período pago. '
                                  'Continuas com acesso Pro até ${end != null ? endStr : 'o fim do período indicado no Stripe'}.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Voltar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Confirmar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await _callAction('cancelSubscriptionAtPeriodEnd', shop.slug);
                            }
                          },
                  style: FilledButton.styleFrom(
                    backgroundColor: designGray900,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  ),
                  icon: const Icon(Icons.event_busy),
                  label: Text(
                    shop.explainsWhyRefundHiddenOnlyCancel
                        ? 'Cancelar renovação (sem reembolso — após 7 dias do pagamento)'
                        : 'Cancelar renovação (até fim do período)',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (showRefundBtn)
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Reembolso por arrependimento'),
                                content: Text(
                                  'Dentro dos 7 dias corridos desde o pagamento atual. Ao confirmares, '
                                  'o valor desta fatura será estornado na Stripe, a assinatura será '
                                  'cancelada e o acesso Pro será bloqueado de imediato (não ficas com o resto do período). '
                                  'Confirma?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Não'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Reembolsar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await _callAction('refundCurrentPeriodSubscription', shop.slug);
                            }
                          },
                  icon: const Icon(Icons.money_off),
                  label: const Text('Solicitar reembolso (arrependimento — perde Pro na hora)'),
                ),
              if (showRefundBtn) const SizedBox(height: 20),
              if ((shop.stripeCustomerId == null && shop.stripeSubscriptionId == null) ||
                  shop.subscriptionStatus == 'none')
                FilledButton(
                  onPressed: () => context.go('/dashboard/assinar'),
                  child: const Text('Assinar plano Pro'),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.savings_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pagamentos da assinatura entram no Relatórios em “Investimento app (assinatura paga no mês)” para acompanhar o custo do software.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: designMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Extrato (pagamentos, cupons e reembolsos)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              eventsAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return Text(
                      'Ainda sem lançamentos. Após a primeira cobrança do Stripe, os pagamentos aparecem aqui.',
                      style: GoogleFonts.poppins(
                        color: designMuted,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    );
                  }
                  int paidC = 0;
                  int refC = 0;
                  for (final m in rows) {
                    final t = m['type'] as String? ?? '';
                    if (t == 'refund') {
                      refC += _centsFrom(m['amount']).abs();
                    } else {
                      paidC += _centsFrom(m['amount']);
                    }
                  }
                  final payList = <Map<String, dynamic>>[];
                  final refList = <Map<String, dynamic>>[];
                  for (final m in rows) {
                    final t = m['type'] as String? ?? '';
                    if (t == 'refund') {
                      refList.add(m);
                    } else {
                      payList.add(m);
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (payList.isNotEmpty || refList.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: _BillingMiniKpi(
                                label: 'Total pago',
                                value: money.format(paidC / 100.0),
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _BillingMiniKpi(
                                label: 'Reembolsos',
                                value: money.format(-refC / 100.0),
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      if (payList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Cobranças',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: designGray900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...payList.map((m) => _BillingEventTile(
                              m: m,
                              money: money,
                              isRefund: false,
                            )),
                      ],
                      if (refList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Reembolsos',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: designGray900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...refList.map((m) => _BillingEventTile(
                              m: m,
                              money: money,
                              isRefund: true,
                            )),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Erro: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _BillingMiniKpi extends StatelessWidget {
  const _BillingMiniKpi({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF5C636A)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingEventTile extends StatelessWidget {
  const _BillingEventTile({
    required this.m,
    required this.money,
    required this.isRefund,
  });
  final Map<String, dynamic> m;
  final NumberFormat money;
  final bool isRefund;

  @override
  Widget build(BuildContext context) {
    int cents = 0;
    final amount = m['amount'];
    if (amount is int) {
      cents = amount;
    } else if (amount is num) {
      cents = amount.toInt();
    }
    final at = m['createdAt'];
    var when = '—';
    if (at is Timestamp) {
      when = DateFormat('dd/MM/yyyy HH:mm').format(at.toDate());
    }
    final desc = m['description'] as String? ?? '';
    final discountCents = m['discountCents'];
    int disc = 0;
    if (discountCents is int) {
      disc = discountCents;
    } else if (discountCents is num) {
      disc = discountCents.toInt();
    }
    final hasPromo = m['hasPromotion'] == true || disc > 0;
    final inv = m['invoiceNumber'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isRefund ? Icons.undo : Icons.payments_outlined,
              color: isRefund ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRefund ? 'Reembolso' : 'Pagamento — assinatura',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (inv != null && inv.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Fatura: $inv',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF5C636A),
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (!isRefund && hasPromo) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        disc > 0
                            ? 'Cupom / desconto aplicado: − ${money.format(disc / 100.0)}'
                            : 'Cupom ou promoção aplicada (Stripe)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              isRefund
                  ? '− ${money.format(cents.abs() / 100.0)}'
                  : money.format(cents / 100.0),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isRefund ? const Color(0xFFEA580C) : const Color(0xFF1A1D21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
