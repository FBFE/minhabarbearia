import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/admin_providers.dart';

/// Painel do dono do app: lista todas as barbearias/salões que usam o sistema.
/// Acesso só para UIDs em app_config/config.adminUids (configurado no Firestore).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    const designGray50 = Color(0xFFF9FAFB);
    const designGray200 = Color(0xFFE5E7EB);
    const designGray900 = Color(0xFF1A1D21);

    return Scaffold(
      backgroundColor: designGray50,
      appBar: AppBar(
        title: Text(
          'Painel do app',
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
                      onPressed: () => context.go('/dashboard'),
                      child: const Text('Voltar ao dashboard'),
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
                      onPressed: () => context.go('/dashboard'),
                      child: const Text('Voltar ao dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }
          final list = data.barberShops;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Clientes do app (${list.length} negócio${list.length == 1 ? '' : 's'})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Barbearias e salões que estão usando o sistema.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF5C636A),
                  ),
                ),
                const SizedBox(height: 20),
                if (list.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nenhum negócio cadastrado ainda.',
                        style: GoogleFonts.poppins(color: const Color(0xFF5C636A)),
                      ),
                    ),
                  )
                else
                  ...list.map((shop) => _ShopTile(shop: shop)),
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
