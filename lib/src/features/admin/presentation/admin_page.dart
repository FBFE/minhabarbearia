import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/admin_providers.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/dashboard_tab_provider.dart';
import '../../../core/providers/firebase_providers.dart';

/// Painel do dono do app: lista negócios. Acesso por e-mail/API (Cloud Function).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    const designGray50 = Color(0xFFF9FAFB);
    const designGray200 = Color(0xFFE5E7EB);
    const designGray900 = Color(0xFF1A1D21);

    final shop = ref.watch(barberShopProvider).valueOrNull;

    return Scaffold(
      backgroundColor: designGray50,
      appBar: AppBar(
        title: Text(
          'Dashboard administrativo',
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
          icon: Icon(shop != null ? Icons.arrow_back : Icons.logout_rounded),
          tooltip: shop != null ? 'Meu negócio' : 'Sair',
          onPressed: () async {
            if (shop != null) {
              context.go('/dashboard');
            } else {
              await ref.read(firebaseAuthProvider).signOut();
              if (context.mounted) context.go('/login');
            }
          },
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: designGray200),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(adminDashboardProvider),
          ),
        ],
      ),
      body: async.when(
        data: (data) {
          if (data.error != null && !data.isAdmin) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Acesso negado',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.error!,
                      style: GoogleFonts.poppins(color: const Color(0xFF5C636A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final s = ref.read(barberShopProvider).valueOrNull;
                        if (s != null) {
                          if (context.mounted) context.go('/dashboard');
                        } else {
                          await ref.read(firebaseAuthProvider).signOut();
                          if (context.mounted) context.go('/login');
                        }
                      },
                      child: const Text('Voltar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!data.isAdmin) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Você não tem acesso ao painel admin.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFF5C636A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final s = ref.read(barberShopProvider).valueOrNull;
                        if (s != null) {
                          if (context.mounted) context.go('/dashboard');
                        } else {
                          await ref.read(firebaseAuthProvider).signOut();
                          if (context.mounted) context.go('/login');
                        }
                      },
                      child: const Text('Voltar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final list = data.barberShops;
          final s = data.summary;
          final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (s == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.amber.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Faça deploy da função getAdminDashboard (última versão) para carregar métricas agregadas.',
                                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (s != null) ...[
                  Text(
                    'Visão geral',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Métricas consolidadas das barbearias e da base de usuários.',
                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final cross = maxW >= 880
                          ? 4
                          : maxW >= 640
                              ? 3
                              : 2;
                      final spacing = 10.0;
                      final tileW = (maxW - spacing * (cross - 1)) / cross;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.verified_rounded,
                              label: 'Com Pro ativo',
                              value: '${s.businessesWithProAccess}',
                              subtitle: 'Acesso conforme trial/assinatura',
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Assinatura Stripe (active)',
                              value: '${s.activeStripeBackedCount}',
                              subtitle: () {
                                final gap = s.subscriptionActiveCount - s.activeStripeBackedCount;
                                if (gap <= 0) {
                                  return 'Todos os «active» têm subscriptionId sub_*';
                                }
                                return '$gap com «active» sem subscriptionId sub_*';
                              }(),
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.people_outline_rounded,
                              label: 'Clientes finais (app)',
                              value: '${s.registeredEndClientsTotal}',
                              subtitle: 'Somatório nas lojas',
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.person_search_rounded,
                              label: 'Contas Firebase Auth',
                              value: '${s.firebaseAuthUserCountProduction}',
                              subtitle:
                                  'Excl.: e-mails @example.*, provedores óbvios de teste '
                                  '(total brutto ${s.firebaseAuthUserCount})',
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.payments_outlined,
                              label: 'Receita (Stripe)',
                              value: money.format(s.totalSubscriptionRevenueCents / 100),
                              subtitle: 'Soma dos eventos type=payment',
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.store_mall_directory_outlined,
                              label: 'Negócios',
                              value: '${s.totalBusinesses}',
                              subtitle:
                                  '${s.activeStripeBackedCount} Stripe • ${s.subscriptionActiveCount} marcados active • '
                                  '${s.onTrialCount} trial • ${s.refundedCount} reimbursed',
                            ),
                          ),
                          SizedBox(
                            width: tileW,
                            child: _KpiCard(
                              icon: Icons.hourglass_bottom_rounded,
                              label: 'Em atraso (past_due)',
                              value: '${s.pastDueCount}',
                              subtitle: 'Ainda com acesso configurado',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Reembolsos registrados',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantidade de eventos tipo reembolso por negócio (billingEvents).',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: s.refundActivity.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Nenhum reembolso registrado.',
                              style: GoogleFonts.poppins(color: const Color(0xFF5C636A)),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor:
                                  WidgetStateProperty.all(const Color(0xFFF3F4F6)),
                              columns: const [
                                DataColumn(label: Text('Negócio')),
                                DataColumn(label: Text('Slug')),
                                DataColumn(label: Text('Pedidos')),
                                DataColumn(label: Text('Último')),
                              ],
                              rows: [
                                for (final r in s.refundActivity)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(r.name)),
                                      DataCell(Text(r.slug)),
                                      DataCell(Text('${r.refundCount}')),
                                      DataCell(
                                        Text(_formatRefundDatePt(r.lastRefundAt)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                ],
                Text(
                  'Todos os negócios (${list.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Barbearias cadastradas no sistema.',
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: Text(
                        'Nenhum negócio cadastrado.',
                        style: GoogleFonts.poppins(color: const Color(0xFF5C636A)),
                      ),
                    ),
                  )
                else
                  ...list.map((shop) => _ShopTile(shop: shop)),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      ref.read(ownerOnboardingRequestProvider.notifier).state = true;
                      context.go('/dashboard');
                    },
                    child: Text(
                      'Sou dono e quero cadastrar um negócio (opcional)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Erro: $e', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(adminDashboardProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});
  final AdminBarberShopItem shop;

  @override
  Widget build(BuildContext context) {
    final createdAtStr = shop.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(shop.createdAt!) ?? DateTime.now())
        : '—';
    final trialStr = shop.trialEndsAt != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(shop.trialEndsAt!)!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
          child: const Icon(Icons.store_rounded, color: Color(0xFF2196F3)),
        ),
        title: Text(
          shop.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('/${shop.slug}', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A))),
            const SizedBox(height: 4),
            Text(
              'Cadastro: $createdAtStr • Trial até: $trialStr • ${shop.subscriptionStatus}',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF5C636A)),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Poderia abrir link do negócio ou detalhes
          // context.go('/b/${shop.slug}');
        },
      ),
    );
  }
}

String _formatRefundDatePt(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF6366F1)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D21),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: GoogleFonts.poppins(fontSize: 11, height: 1.35, color: const Color(0xFF8B939E)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
