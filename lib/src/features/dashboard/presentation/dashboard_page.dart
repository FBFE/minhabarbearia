import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/barber_shop.dart';
import '../../../core/models/service.dart';
import '../../../core/models/voucher.dart';
import '../../../core/providers/admin_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/barber_shop_edit_provider.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/dashboard_tab_provider.dart';
import '../../../core/subscription_access.dart';
import '../../../core/providers/theme_providers.dart';
import '../../../core/widgets/service_storage_image.dart';
import '../../../core/widgets/service_image_crop_dialog.dart';
import '../../../core/providers/fcm_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/image_utils.dart';
import 'dashboard_dre_tab.dart';
import 'dashboard_estoque_tab.dart';
import 'walk_in_checkout_sheet.dart';
import '../logic/appointment_completion_logic.dart';
import 'owner_onboarding_page.dart';
import '../../pwa_install/presentation/pwa_business_settings_section.dart';

/// Cores padrão quando o negócio ainda não está carregado.
const _defaultPrimary = Color(0xFF212121);

const _defaultSecondary = Color(0xFF1A1A2E);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final barberShopAsync = ref.watch(barberShopProvider);
    final adminData = ref.watch(adminDashboardProvider);
    final isAdminFromApi = adminData.valueOrNull?.isAdmin ?? false;
    // Fallback: mostrar botão admin para o e-mail do dono do app mesmo se a API ainda não respondeu
    const adminEmail = 'fabianoeugenio96@gmail.com';
    final isAdmin = isAdminFromApi || user?.email == adminEmail;

    final wantOwnerOnboarding = ref.watch(ownerOnboardingRequestProvider);
    final bypassAdminRedirect = wantOwnerOnboarding;

    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) {
          if (isAdmin && !bypassAdminRedirect) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/admin');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const OwnerOnboardingPage(initialShop: null);
        }
        if (shop.onboardingScreen < 3) {
          return OwnerOnboardingPage(initialShop: shop);
        }
        final primary = shop.primaryColorAsColor;
        final secondary = shop.secondaryColorAsColor;
        return _DashboardScaffold(
          userEmail: user?.email,
          barberShop: shop,
          primaryColor: primary,
          secondaryColor: secondary,
          isAdmin: isAdmin,
        );
      },
      loading: () {
        // Admin sem negócio: evita scaffold do dono até sabermos que não há loja vinculada
        if (isAdmin && !bypassAdminRedirect) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _DashboardScaffold(
          userEmail: user?.email,
          barberShop: null,
          primaryColor: _defaultPrimary,
          secondaryColor: _defaultSecondary,
          isAdmin: isAdmin,
        );
      },
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }
}

/// Página dedicada de configurações do negócio (nome, slug, cores, logo, fundo).
class DashboardSettingsPage extends ConsumerWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberShopAsync = ref.watch(barberShopProvider);

    return Scaffold(
      backgroundColor: _designGray50,
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _designGray900,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _designGray900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _designGray900),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _designGray200),
        ),
      ),
      body: barberShopAsync.when(
        data: (shop) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined, color: _designGray900),
                title: Text(
                  'Assinatura e histórico de pagamentos',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: _designGray900,
                  ),
                ),
                subtitle: Text(
                  'Renovação, cancelar, reembolso e faturas',
                  style: GoogleFonts.poppins(fontSize: 13, color: _designGray600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/dashboard/assinatura'),
              ),
              const SizedBox(height: 24),
              const PwaBusinessSettingsSection(),
              const Divider(height: 32),
              _BarberShopFormSheet(initial: shop),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

/// Títulos das abas do menu do dono.
const _tabTitles = ['Início', 'Agenda', 'Serviços', 'Clientes', 'Estoque', 'Relatórios'];

String _dashboardInitials(String? email) {
  if (email == null || email.isEmpty) return '?';
  final local = email.split('@').first.trim();
  if (local.length >= 2) {
    return local.substring(0, 2).toUpperCase();
  }
  return local.isEmpty ? '?' : local[0].toUpperCase();
}

class _DashboardScaffold extends ConsumerStatefulWidget {
  final String? userEmail;
  final BarberShop? barberShop;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isAdmin;

  const _DashboardScaffold({
    this.userEmail,
    this.barberShop,
    required this.primaryColor,
    required this.secondaryColor,
    this.isAdmin = false,
  });

  @override
  ConsumerState<_DashboardScaffold> createState() => _DashboardScaffoldState();
}

/// Design: gray-50 background, white header with border, white bottom nav
const _designGray50 = Color(0xFFF9FAFB);
const _designGray200 = Color(0xFFE5E7EB);
const _designGray600 = Color(0xFF5C636A);
const _designGray900 = Color(0xFF1A1D21);

/// Fundo do dashboard com foto do negócio (se configurada) e véu claro para leitura.
Widget _dashboardScaffoldBackground(BarberShop? shop) {
  final url = shop?.backgroundImageUrl?.trim();
  if (url == null || url.isEmpty) {
    return const ColoredBox(color: _designGray50);
  }
  return Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => const ColoredBox(color: _designGray50),
        ),
      ),
      Positioned.fill(
        child: ColoredBox(
          color: _designGray50.withValues(alpha: 0.78),
        ),
      ),
    ],
  );
}

class _DashboardScaffoldState extends ConsumerState<_DashboardScaffold> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;
    final currentIndex = ref.watch(dashboardTabIndexProvider);
    final email = widget.userEmail;
    final initials = _dashboardInitials(email);

    final shop = widget.barberShop;
    final proAccess = shop == null || barberShopHasProAccess(shop);

    ref.listen<int>(dashboardTabIndexProvider, (prev, next) {
      if (!_pageController.hasClients) {
        return;
      }
      final at = _pageController.page?.round() ?? 0;
      if (at != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });

    return Scaffold(
      backgroundColor: _designGray50,
      appBar: AppBar(
        title: Text(
          _tabTitles[currentIndex],
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _designGray900,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _designGray900,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _designGray900),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              tooltip: 'Painel do app (admin)',
              onPressed: () => context.go('/admin'),
            ),
          IconButton(
            onPressed: () async {
              if (!kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notificações push estão disponíveis na versão web (PWA).')),
                );
                return;
              }
              final r = await requestAndRegisterWebNotifications();
              if (!context.mounted) return;
              if (!r.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Não foi possível ativar. Permita notificações no navegador e confira a chave VAPID (Firebase → Cloud Messaging → Web Push).',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              if (r.ownerShopsUpdated > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      r.ownerShopsUpdated == 1
                          ? 'Notificações ativadas para o seu negócio.'
                          : 'Notificações ativadas em ${r.ownerShopsUpdated} negócios.',
                    ),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
                return;
              }
              final shopDocId = widget.barberShop?.id;
              if (shopDocId != null) {
                final token = await requestFcmTokenAndPermission();
                if (!context.mounted) return;
                if (token != null) {
                  await saveOwnerFcmToken(ref, shopDocId, token);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Notificações ativadas para este negócio.'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quando o negócio carregar, use o botão «Ativar notificações» abaixo.'),
                  ),
                );
              }
            },
            tooltip: 'Ativar notificações',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () => context.go('/dashboard/settings'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              child: CircleAvatar(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              onSelected: (v) async {
                if (v == 'sair') {
                  await ref.read(firebaseAuthProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'sair', child: Text('Sair')),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _designGray200),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _dashboardScaffoldBackground(shop)),
          Column(
            children: [
              Expanded(
                child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (ref.read(dashboardTabIndexProvider) != index) {
                  ref.read(dashboardTabIndexProvider.notifier).state = index;
                }
              },
              children: [
                _InicioContent(
                  userEmail: widget.userEmail,
                  barberShop: shop,
                  primaryColor: primary,
                ),
                if (shop == null)
                  const Center(child: CircularProgressIndicator())
                else if (!proAccess)
                  _ProLockedPanel(
                    primary: primary,
                    tabName: 'Agenda',
                    status: shop.subscriptionStatus,
                  )
                else
                  _AgendaContent(barberShop: shop),
                if (shop == null)
                  const Center(child: CircularProgressIndicator())
                else if (!proAccess)
                  _ProLockedPanel(
                    primary: primary,
                    tabName: 'Serviços',
                    status: shop.subscriptionStatus,
                  )
                else
                  _ServicosContent(barberShop: shop),
                if (shop == null)
                  const Center(child: CircularProgressIndicator())
                else if (!proAccess)
                  _ProLockedPanel(
                    primary: primary,
                    tabName: 'Clientes',
                    status: shop.subscriptionStatus,
                  )
                else
                  _ClientesContent(barberShop: shop),
                if (shop == null)
                  const Center(child: CircularProgressIndicator())
                else if (!proAccess)
                  _ProLockedPanel(
                    primary: primary,
                    tabName: 'Estoque',
                    status: shop.subscriptionStatus,
                  )
                else
                  DashboardEstoqueTab(barberShop: shop),
                if (shop == null)
                  const Center(child: CircularProgressIndicator())
                else if (!proAccess)
                  _ProLockedPanel(
                    primary: primary,
                    tabName: 'Relatórios',
                    status: shop.subscriptionStatus,
                  )
                else
                  DashboardDreTab(barberShop: shop),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _designGray200)),
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) {
                  ref.read(dashboardTabIndexProvider.notifier).state = index;
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: primary,
                unselectedItemColor: _designGray600,
                selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
                selectedFontSize: 11,
                unselectedFontSize: 10,
                iconSize: 24,
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.home_rounded, color: primary, size: 28),
                    label: 'Início',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.calendar_month_rounded, color: primary, size: 28),
                    label: 'Agenda',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.content_cut_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.content_cut_rounded, color: primary, size: 28),
                    label: 'Serviços',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.people_rounded, color: primary, size: 28),
                    label: 'Clientes',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.inventory_2_rounded, color: primary, size: 28),
                    label: 'Estoque',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_rounded, color: _designGray600, size: 24),
                    activeIcon: Icon(Icons.bar_chart_rounded, color: primary, size: 28),
                    label: 'Relatórios',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

/// Trial 7d; aviso kSubscriptionTrialWarningDays antes do fim; bloqueio sem acesso pago.
class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.barberShop, required this.primaryColor});
  final BarberShop barberShop;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final trialEndsAt = barberShop.trialEndsAt;
    final status = barberShop.subscriptionStatus;
    final hasAccess = barberShopHasProAccess(barberShop);
    final periodEnd = barberShop.subscriptionCurrentPeriodEnd;
    const warningDays = kSubscriptionTrialWarningDays;

    if (hasAccess && barberShop.cancelAtPeriodEnd && periodEnd != null) {
      final ds = DateFormat('dd/MM/yyyy').format(periodEnd);
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Renovação automática cancelada. Acesso pago até $ds.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (hasAccess && status == 'active' && !barberShop.cancelAtPeriodEnd) {
      return const SizedBox.shrink();
    }
    if (hasAccess && status == 'past_due') {
      return const SizedBox.shrink();
    }
    if (hasAccess && status == 'trial') {
      final end = trialEndsAt;
      if (end == null || !end.isAfter(now)) {
        return const SizedBox.shrink();
      }
      final daysLeft = end.difference(now).inDays;
      if (daysLeft > warningDays) {
        final dateStr = DateFormat('dd/MM/yyyy').format(end);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.blue.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Período de teste (7 dias)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Você tem $daysLeft dia${daysLeft == 1 ? '' : 's'} de teste (até $dateStr)',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        daysLeft <= 0
                            ? 'Seu período de teste acaba hoje'
                            : 'Seu período de teste acaba em $daysLeft dia${daysLeft == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assine para continuar sem interrupções.',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/dashboard/assinar'),
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!hasAccess) {
      if (status == 'refunded') {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.money_off, color: Colors.red.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acesso pro revogado (reembolso)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assine novamente para voltar a usar o plano completo.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => context.go('/dashboard/assinar'),
                    style: FilledButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text('Assinar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Seu acesso expirou',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assine para continuar usando o app com seu negócio.',
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/dashboard/assinar'),
                  style: FilledButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Assinar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Aba 1+ sem assinatura/trial ativo: conteúdo bloqueado (Início continua acessível).
class _ProLockedPanel extends StatelessWidget {
  const _ProLockedPanel({
    required this.primary,
    required this.tabName,
    required this.status,
  });
  final Color primary;
  final String tabName;
  final String status;

  @override
  Widget build(BuildContext context) {
    String detail;
    if (status == 'refunded') {
      detail = 'O reembolso removeu o acesso às funcionalidades pro. Assine de novo para continuar.';
    } else {
      detail =
          'Assine o plano pro para usar agenda, serviços, clientes, estoque e relatórios. O período de teste (7 dias) dá acesso completo; depois, é necessária a assinatura.';
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 56, color: primary.withValues(alpha: 0.8)),
              const SizedBox(height: 20),
              Text(
                'Secção: $tabName',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _designGray900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.4,
                  color: _designGray600,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go('/dashboard/assinar'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: Text(status == 'refunded' ? 'Assinar de novo' : 'Assinar plano pro'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/dashboard/assinatura'),
                child: const Text('Assinatura, faturas e reembolsos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _greetingName(String? email) {
  if (email == null || email.isEmpty) return 'Dono';
  final local = email.split('@').first;
  if (local.isEmpty) return 'Dono';
  return local[0].toUpperCase() + local.substring(1);
}

/// Compara o dia no fuso local (evita KPI “hoje” errado com Timestamps em UTC).
bool _isSameLocalCalendarDay(DateTime a, DateTime dayLocal) {
  final l = a.toLocal();
  return l.year == dayLocal.year && l.month == dayLocal.month && l.day == dayLocal.day;
}

String _kpiStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'AGENDADO';
    case 'confirmed':
      return 'CONFIRMADO';
    case 'completed':
      return 'REALIZADO';
    case 'canceled':
      return 'CANCELADO';
    default:
      return status.toUpperCase();
  }
}

/// Conteúdo da aba Início (mock: card escuro, link, KPIs 2×2, próximos horários).
class _InicioContent extends ConsumerWidget {
  final String? userEmail;
  final BarberShop? barberShop;
  final Color primaryColor;

  const _InicioContent({
    this.userEmail,
    this.barberShop,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = primaryColor;
    final name = _greetingName(userEmail);
    if (barberShop == null) {
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(barberShopProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bem-vindo',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _designGray900,
                ),
              ),
              const SizedBox(height: 16),
              _LinkBarberShopCard(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/dashboard/settings'),
                icon: const Icon(Icons.add),
                label: const Text('Criar meu negócio'),
              ),
            ],
          ),
        ),
      );
    }

    final shop = barberShop!;
    final slug = shop.slug;
    final appointmentsAsync = ref.watch(appointmentsProvider(slug));
    final clientsAsync = ref.watch(clientsProvider(slug));
    final reviewsAsync = ref.watch(reviewsProvider(slug));
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(appointmentsProvider(slug));
        ref.invalidate(clientsProvider(slug));
        ref.invalidate(reviewsProvider(slug));
        ref.invalidate(barberShopProvider);
        try {
          await ref.read(appointmentsProvider(slug).future);
        } catch (_) {}
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrialBanner(barberShop: shop, primaryColor: primary),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $name!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (userEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    userEmail!,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
                  ),
                ],
                const SizedBox(height: 16),
                if (shop.subscriptionStatus == 'active')
                  Text(
                    'Plano ativo',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF4ADE80),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFD54F), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SEU PLANO',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                  color: const Color(0xFFFFA726),
                                ),
                              ),
                              Text(
                                _trialLine(shop),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => context.go('/dashboard/assinar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text('Assinar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OwnerClientInviteCard(shop: shop, primary: primary),
          const SizedBox(height: 20),
          appointmentsAsync.when(
            data: (all) {
              final now = DateTime.now();
              final startToday = DateTime(now.year, now.month, now.day);
              final endToday = startToday.add(const Duration(days: 1));
              final todayAppts = all.where(
                (a) => a.status != 'canceled' && _isSameLocalCalendarDay(a.dateTime, startToday),
              );
              final agendHoje = todayAppts.length;
              final receitaDia = todayAppts
                  .where((a) => a.status == 'completed')
                  .fold<double>(0, (s, a) => s + a.bookedRevenue);
              return clientsAsync.when(
                data: (clients) {
                  final newToday = clients.where((c) {
                    final cAt = c.createdAt;
                    return cAt != null && cAt.isAfter(startToday) && cAt.isBefore(endToday);
                  }).length;
                  return reviewsAsync.when(
                    data: (revs) {
                      final avg = revs.isEmpty
                          ? null
                          : revs.fold<int>(0, (a, b) => a + b.rating) / revs.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _KpiRow(
                            a: _KpiCell(
                              icon: Icons.check_circle_outline_rounded,
                              iconBg: const Color(0xFFE8F5E9),
                              iconColor: const Color(0xFF2E7D32),
                              value: '$agendHoje',
                              label: 'AGENDAMENTOS HOJE',
                            ),
                            b: _KpiCell(
                              icon: Icons.group_outlined,
                              iconBg: const Color(0xFFE3F2FD),
                              iconColor: const Color(0xFF1565C0),
                              value: newToday == 0 ? '0' : '+$newToday',
                              label: 'NOVOS CLIENTES',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _KpiRow(
                            a: _KpiCell(
                              icon: Icons.trending_up_rounded,
                              iconBg: const Color(0xFFEDE7F6),
                              iconColor: const Color(0xFF5E35B1),
                              value: money.format(receitaDia).replaceAll('R\$', 'R\$ ').trim(),
                              label: 'RECEITA DO DIA',
                            ),
                            b: _KpiCell(
                              icon: Icons.star_rate_rounded,
                              iconBg: const Color(0xFFFFF3E0),
                              iconColor: const Color(0xFFE65100),
                              value: avg == null ? '—' : avg.toStringAsFixed(1),
                              label: 'AVALIAÇÕES',
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('Erro: $e'),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _designGray200),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Próximos horários',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _designGray900,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref.read(dashboardTabIndexProvider.notifier).state = 1,
                        child: Text(
                          'Ver agenda >',
                          style: GoogleFonts.poppins(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  appointmentsAsync.when(
                    data: (all) {
                      final fromNow = all
                          .where(
                            (a) =>
                                a.status != 'canceled' && !a.dateTime.isBefore(
                                  DateTime.now().subtract(const Duration(minutes: 1)),
                                ),
                          )
                          .toList()
                        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                      final take = fromNow.take(4).toList();
                      if (take.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Nenhum agendamento à frente.',
                            style: GoogleFonts.poppins(color: _designGray600, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: take.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final a = take[i];
                          final t = DateFormat('HH:mm').format(a.dateTime);
                          final staff = a.staffName?.isNotEmpty == true ? a.staffName! : 'Equipe';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _designGray900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.clientName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: _designGray900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${a.serviceName} • $staff',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _designGray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _kpiStatusBorderColor(a.status),
                                    ),
                                    color: _kpiStatusBorderColor(a.status).withValues(alpha: 0.1),
                                  ),
                                  child: Text(
                                    _kpiStatusLabel(a.status),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _kpiStatusBorderColor(a.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Erro: $e'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _LoyaltyRuleCard(barberShop: shop),
          const SizedBox(height: 12),
          _ReferralPointsCard(barberShop: shop),
          const SizedBox(height: 12),
          _QuemMaisAtendeCard(slug: shop.slug),
          const SizedBox(height: 12),
          _VouchersCard(slug: shop.slug),
        ],
        ),
      ),
    );
  }
}

/// Cor de texto/ícones em cima de [background] (contraste acessível).
Color _onBrandColor(Color background) =>
    background.computeLuminance() > 0.55 ? const Color(0xFF1A1D21) : Colors.white;

/// Cor dos módulos do QR: usa a cor de marca se for escura o suficiente; senão preto padrão (leitores escaneiam melhor).
Color _qrModuleColorForBrand(Color primary, Color secondary) {
  for (final c in [primary, secondary]) {
    if (c.computeLuminance() < 0.5) {
      return c;
    }
  }
  return const Color(0xFF1A1D21);
}

/// Cartão: link público de cadastro de clientes, QR para escanear e partilha no WhatsApp.
/// Usa a logo e as cores (tema) do negócio quando configuradas.
class _OwnerClientInviteCard extends StatelessWidget {
  const _OwnerClientInviteCard({required this.shop, required this.primary});

  final BarberShop shop;
  final Color primary;

  static String cadastroUrlForSlug(String slug) => '${Uri.base.origin}/b/$slug/cadastro';

  void _showQrDialog(BuildContext context) {
    final url = cadastroUrlForSlug(shop.slug);
    final secondary = shop.secondaryColorAsColor;
    final qrColor = _qrModuleColorForBrand(primary, secondary);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'QR Code — cadastro de clientes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Peça para o cliente apontar a câmera do telefone. Ele será levado à página de cadastro do seu negócio.',
                style: GoogleFonts.poppins(fontSize: 14, color: _designGray600, height: 1.35),
                textAlign: TextAlign.center,
              ),
              if (shop.logoUrl != null && shop.logoUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      shop.logoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: qrColor),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                url,
                style: GoogleFonts.poppins(fontSize: 11, color: _designGray600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Fechar', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: _onBrandColor(primary)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link de cadastro copiado!')),
              );
            },
            child: const Text('Copiar link'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final url = cadastroUrlForSlug(shop.slug);
    final text =
        'Olá! Cadastre-se no ${shop.name} para agendar, usar o cartão fidelidade e acompanhar seus horários.\n\n$url';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = cadastroUrlForSlug(shop.slug);
    final secondary = shop.secondaryColorAsColor;
    final onGradient = _onBrandColor(
      Color.lerp(primary, secondary, 0.5) ?? primary,
    );
    final hasLogo = shop.logoUrl != null && shop.logoUrl!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, Color.lerp(primary, secondary, 0.55) ?? secondary],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasLogo)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.95),
                        child: Image.network(
                          shop.logoUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              width: 56,
                              height: 56,
                              color: Colors.white24,
                              alignment: Alignment.center,
                              child: Icon(Icons.storefront_rounded, color: onGradient, size: 28),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Icon(Icons.qr_code_2_rounded, color: onGradient, size: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: onGradient,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cartão de visita digital — cadastre clientes',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: onGradient.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: Color.lerp(Colors.white, primary, 0.04) ?? Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'QR no salão ou link no WhatsApp — o cliente cria a conta (e-mail) com a identidade do seu negócio.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _designGray600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    url,
                    maxLines: 2,
                    style: GoogleFonts.poppins(fontSize: 11, color: _designGray600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showQrDialog(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: const Text('Ver QR Code'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary.withValues(alpha: 0.55)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat_rounded, size: 20),
                        label: const Text('WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link de cadastro copiado!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        label: const Text('Copiar link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _designGray600,
                          side: BorderSide(
                            color: Color.lerp(_designGray200, primary, 0.25) ?? _designGray200,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _trialLine(BarberShop shop) {
  if (shop.subscriptionStatus == 'refunded') {
    return 'Reembolsado — sem acesso pro';
  }
  if (shop.subscriptionStatus == 'active' && !shop.cancelAtPeriodEnd) {
    final p = shop.subscriptionCurrentPeriodEnd;
    if (p != null) {
      return 'Pro — renovação em torno de ${DateFormat('dd/MM/yyyy').format(p)}';
    }
    return 'Plano: Pro ativo';
  }
  if (shop.cancelAtPeriodEnd && shop.subscriptionCurrentPeriodEnd != null) {
    return 'Pro até ${DateFormat('dd/MM/yyyy').format(shop.subscriptionCurrentPeriodEnd!)}';
  }
  final now = DateTime.now();
  final end = shop.trialEndsAt;
  if (end == null) return 'Plano: trial (7 dias)';
  if (end.isBefore(now)) return 'Trial expirado';
  final d = end.difference(now).inDays;
  return 'Trial (7d) — $d ${d == 1 ? 'dia' : 'dias'} restantes';
}

Color _kpiStatusBorderColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFF1E88E5);
    case 'confirmed':
      return const Color(0xFF2E7D32);
    case 'completed':
      return const Color(0xFF5C636A);
    default:
      return const Color(0xFF5C636A);
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.a, required this.b});
  final _KpiCell a;
  final _KpiCell b;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _KpiBox(cell: a)),
        const SizedBox(width: 12),
        Expanded(child: _KpiBox(cell: b)),
      ],
    );
  }
}

class _KpiCell {
  const _KpiCell({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({required this.cell});
  final _KpiCell cell;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _designGray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cell.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(cell.icon, size: 20, color: cell.iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            cell.value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _designGray900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cell.label,
            maxLines: 2,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _designGray600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteúdo da aba Agenda: calendário com dias marcados e lista de agendamentos.
class _AgendaContent extends ConsumerWidget {
  final BarberShop? barberShop;

  const _AgendaContent({this.barberShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barberShop == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crie ou vincule seu negócio em Configurações para ver a agenda.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final primary = barberShop!.primaryColorAsColor;
    return ColoredBox(
      color: _designGray50,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _designGray200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua agenda',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _designGray900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Veja os horários por dia. Cliente chegou sem marcação? Use atendimento avulso na área de ações abaixo.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _designGray600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: _AppointmentsCard(slug: barberShop!.id, primaryColor: primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteúdo da aba Serviços.
class _ServicosContent extends ConsumerWidget {
  final BarberShop? barberShop;

  const _ServicosContent({this.barberShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barberShop == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crie ou vincule seu negócio em Configurações para gerenciar serviços.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final primary = barberShop!.primaryColorAsColor;
    return ColoredBox(
      color: _designGray50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _designGray200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catálogo de serviços',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _designGray900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Preços, duração e produtos consumidos (baixa ao concluir) aparecem no editor.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _designGray600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  showWalkInCheckoutSheet(
                    context,
                    slug: barberShop!.id,
                    primaryColor: primary,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF121212),
                  foregroundColor: const Color(0xFFFFD54F),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                label: Text(
                  'Atendimento avulso',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ServicesCard(slug: barberShop!.id, primaryColor: primary),
          ],
        ),
      ),
    );
  }
}

/// Conteúdo da aba Clientes.
class _ClientesContent extends ConsumerWidget {
  final BarberShop? barberShop;

  const _ClientesContent({this.barberShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barberShop == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crie ou vincule seu negócio em Configurações para ver os clientes.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _ClientsCard(
        slug: barberShop!.id,
        primaryColor: barberShop!.primaryColorAsColor,
      ),
    );
  }
}

/// Card para vincular um negócio existente (pelo slug) à conta atual.
/// Útil quando o negócio não aparece porque ownerUid no Firestore está diferente do UID do usuário.
class _LinkBarberShopCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LinkBarberShopCard> createState() => _LinkBarberShopCardState();
}

class _LinkBarberShopCardState extends ConsumerState<_LinkBarberShopCard> {
  final _slugController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _linkBySlug() async {
    final slug = _slugController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    if (slug.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite o slug do negócio (ex: meunegocio).')),
        );
      }
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final doc = await firestore.collection(barbershopsCollection).doc(slug).get();
      if (!mounted) return;
      if (!doc.exists || doc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum negócio encontrado com esse slug. Verifique o nome na URL (ex: /b/meunegocio).')),
        );
        setState(() => _loading = false);
        return;
      }
      final data = doc.data()!;
      final currentOwner = data['ownerUid'] as String?;
      if (currentOwner != null && currentOwner != user.uid) {
        setState(() => _loading = false);
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Negócio já vinculado'),
            content: const Text(
              'Este negócio está vinculado a outra conta no sistema.\n\n'
              'Se você é o dono (ex.: recadastrou o e-mail ou a conta e o vínculo mudou), '
              'pode vincular à esta conta atual. Use apenas se for realmente o dono do negócio.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sou o dono, vincular à minha conta'),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        setState(() => _loading = true);
        await doc.reference.update({'ownerUid': user.uid});
        ref.invalidate(barberShopProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Negócio vinculado à sua conta!'), backgroundColor: Colors.green),
          );
        }
        setState(() => _loading = false);
        return;
      }
      await doc.reference.update({'ownerUid': user.uid});
      ref.invalidate(barberShopProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Negócio vinculado! Atualize a página se não aparecer.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Já tem um negócio?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'O app vincula o negócio pelo e-mail desta conta. Se você já criou um antes e não aparece, informe o slug (nome da página, ex: meunegocio ou eugenio) para vincular.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugController,
              decoration: const InputDecoration(
                labelText: 'Slug do negócio',
                hintText: 'Ex: meunegocio',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.none,
              enabled: !_loading,
              onSubmitted: (_) => _linkBySlug(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _linkBySlug,
              icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link, size: 18),
              label: Text(_loading ? 'Vinculando...' : 'Vincular negócio a esta conta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoyaltyRuleCard extends ConsumerWidget {
  final BarberShop barberShop;

  const _LoyaltyRuleCard({required this.barberShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Regra de fidelidade',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => _LoyaltyRuleFormSheet(barberShop: barberShop),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A cada ${barberShop.loyaltyPointsRequired} pontos → voucher ${barberShop.voucherDiscountLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoyaltyRuleFormSheet extends ConsumerStatefulWidget {
  final BarberShop barberShop;

  const _LoyaltyRuleFormSheet({required this.barberShop});

  @override
  ConsumerState<_LoyaltyRuleFormSheet> createState() => _LoyaltyRuleFormSheetState();
}

class _LoyaltyRuleFormSheetState extends ConsumerState<_LoyaltyRuleFormSheet> {
  late final TextEditingController _pointsController;
  late final TextEditingController _valueController;
  late String _discountType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(
      text: widget.barberShop.loyaltyPointsRequired.toString(),
    );
    _valueController = TextEditingController(
      text: widget.barberShop.voucherDiscountValue.toStringAsFixed(
        widget.barberShop.voucherDiscountType == 'percent' ? 0 : 2,
      ),
    );
    _discountType = widget.barberShop.voucherDiscountType;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final points = int.tryParse(_pointsController.text.trim());
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));

    if (points == null || points < 1 || points > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe entre 1 e 10000 pontos')),
      );
      return;
    }
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido')),
      );
      return;
    }
    if (_discountType == 'percent' && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentual não pode ser maior que 100')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore
          .collection(barbershopsCollection)
          .doc(widget.barberShop.slug)
          .update({
        'loyaltyPointsRequired': points,
        'voucherDiscountType': _discountType,
        'voucherDiscountValue': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(barberShopProvider);
      ref.invalidate(barberShopBySlugProvider(widget.barberShop.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regra de fidelidade atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Regra de fidelidade',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ao concluir agendamento, o cliente ganha +10 pontos. A cada X pontos, gera 1 voucher.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsController,
              decoration: const InputDecoration(
                labelText: 'Pontos necessários para 1 voucher',
                hintText: '100',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _discountType,
              decoration: const InputDecoration(
                labelText: 'Tipo de desconto do voucher',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'percent', child: Text('Percentual (%)')),
                DropdownMenuItem(value: 'fixed', child: Text('Valor fixo (R\$)')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _discountType = v ?? 'fixed'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: _discountType == 'percent' ? 'Valor (%)' : 'Valor (R\$)',
                hintText: _discountType == 'percent' ? '15' : '10,00',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_saving,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar regra'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card que exibe e permite editar os pontos por indicação.
class _ReferralPointsCard extends ConsumerWidget {
  final BarberShop barberShop;

  const _ReferralPointsCard({required this.barberShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pontos por indicação',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => _ReferralPointsFormSheet(barberShop: barberShop),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Quem indicar um cliente (cadastro ou agendamento) ganha +${barberShop.referralPoints} pontos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralPointsFormSheet extends ConsumerStatefulWidget {
  final BarberShop barberShop;

  const _ReferralPointsFormSheet({required this.barberShop});

  @override
  ConsumerState<_ReferralPointsFormSheet> createState() => _ReferralPointsFormSheetState();
}

class _ReferralPointsFormSheetState extends ConsumerState<_ReferralPointsFormSheet> {
  late final TextEditingController _pointsController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(
      text: widget.barberShop.referralPoints.toString(),
    );
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final points = int.tryParse(_pointsController.text.trim());
    if (points == null || points < 0 || points > 9999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe entre 0 e 9999 pontos')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore
          .collection(barbershopsCollection)
          .doc(widget.barberShop.slug)
          .update({
        'referralPoints': points,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(barberShopProvider);
      ref.invalidate(barberShopBySlugProvider(widget.barberShop.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pontos por indicação atualizados!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pontos por indicação',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantos pontos o cliente ganha quando alguém que ele indicou se cadastra ou agenda.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsController,
              decoration: const InputDecoration(
                labelText: 'Pontos',
                hintText: '30',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_saving,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsCard extends ConsumerStatefulWidget {
  final String slug;
  final Color primaryColor;

  const _AppointmentsCard({
    required this.slug,
    required this.primaryColor,
  });

  @override
  ConsumerState<_AppointmentsCard> createState() => _AppointmentsCardState();
}

class _AppointmentsCardState extends ConsumerState<_AppointmentsCard> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  /// Antecipa horário confirmado: atualiza [dateTime] — a receita no DRE conta pelo novo dia ao concluir.
  Future<void> _anticipateAppointment(Appointment a) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (a.status != 'confirmed') return;
    if (!a.dateTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Só é possível antecipar agendamentos futuros.')),
      );
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    final cur = a.dateTime;
    final curDay = DateTime(cur.year, cur.month, cur.day);

    if (curDay.isBefore(today)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data do agendamento inválida para antecipação.')),
      );
      return;
    }
    var firstDate = today;
    var lastDate = curDay;
    var initialDate = today;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Nova data (até o dia do agendamento atual)',
      locale: const Locale('pt', 'BR'),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
      helpText: 'Hora anterior à atual',
    );
    if (pickedTime == null || !mounted) return;

    final newDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!newDt.isBefore(cur)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha data e hora anteriores ao agendamento atual.')),
      );
      return;
    }
    if (!newDt.isAfter(now.subtract(const Duration(minutes: 1)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A nova data e hora não podem ser no passado.')),
      );
      return;
    }

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('appointments').doc(a.id).update({
        'dateTime': Timestamp.fromDate(newDt),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(appointmentsProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Horário antecipado para ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(newDt)}. '
              'Ao concluir, a receita entra no dia deste novo horário.',
              style: const TextStyle(height: 1.35),
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Dono sugere outro horário; o cliente confirma na área pública (push + tela Agenda).
  Future<void> _suggestAlternateTime(Appointment a) async {
    if (!mounted) return;
    if (a.status != 'pending' && a.status != 'confirmed') return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 120));
    var initialDate = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day);
    if (initialDate.isBefore(today)) initialDate = today;
    if (initialDate.isAfter(lastDay)) initialDate = lastDay;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDay,
      locale: const Locale('pt', 'BR'),
      helpText: 'Data sugerida ao cliente',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: a.dateTime.hour, minute: a.dateTime.minute),
      helpText: 'Hora sugerida',
    );
    if (pickedTime == null || !mounted) return;

    final newDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!newDt.isAfter(now.subtract(const Duration(minutes: 1)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha data e hora no futuro.')),
      );
      return;
    }

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('appointments').doc(a.id).update({
        'proposedDateTime': Timestamp.fromDate(newDt),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(appointmentsProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sugestão: ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(newDt)}. O cliente recebe aviso (se ativou notificações).',
              style: const TextStyle(height: 1.35),
            ),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _clearProposedTime(Appointment a) async {
    if (a.proposedDateTime == null) return;
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('appointments').doc(a.id).update({
        'proposedDateTime': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(appointmentsProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sugestão removida.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(
    String appointmentId,
    String newStatus, {
    String? clientId,
  }) async {
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('appointments').doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'canceled') 'canceledBy': 'owner',
        if (newStatus == 'completed') 'completedAt': FieldValue.serverTimestamp(),
      });
      if (newStatus == 'completed' && clientId != null && clientId.isNotEmpty) {
        final vouchersCreated = await awardLoyaltyAfterCompletedAppointment(
          ref: ref,
          firestore: firestore,
          slug: widget.slug,
          clientId: clientId,
        );
        final shop = await ref.read(barberShopBySlugProvider(widget.slug).future);
        final pointsRequired = (shop?.loyaltyPointsRequired ?? 100).clamp(1, 10000);
        if (mounted) {
          showLoyaltyVouchersSnackBar(
            context,
            mounted: mounted,
            shop: shop,
            pointsRequired: pointsRequired,
            vouchersGenerated: vouchersCreated,
          );
        }
      }
      if (newStatus == 'completed') {
        await applyServiceConsumptionsFromAppointmentDoc(
          ref: ref,
          firestore: firestore,
          slug: widget.slug,
          appointmentId: appointmentId,
        );
      }
      ref.invalidate(appointmentsProvider(widget.slug));
      if (mounted) {
        if (newStatus == 'confirmed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Horário confirmado. O cliente só recebe notificação push se tiver ativado "Receber lembretes no celular" na página de agendamento e se o navegador permitir notificações.',
                style: TextStyle(height: 1.35),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status atualizado para $newStatus')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _statusLabel(String status) {
    return _kpiStatusLabel(status);
  }

  void _showNovoAgendamentoInfo() {
    final url = '${Uri.base.origin}/b/${widget.slug}/agendar';
    final primary = widget.primaryColor;
    final onPrimary = _onBrandColor(primary);
    const onSurfaceLocal = Color(0xFF1A1D21);
    const surfaceVariantLocal = Color(0xFF5C636A);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.paddingOf(ctx).bottom + 24,
              top: 8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Novo agendamento pelo cliente',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: onSurfaceLocal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compartilhe o link para o cliente escolher serviço e horário na página pública do seu negócio.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: surfaceVariantLocal,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _designGray50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _designGray200),
                    ),
                    child: SelectableText(
                      url,
                      style: GoogleFonts.poppins(fontSize: 12, color: _designGray900, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text('Abrir', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link de agendamento copiado!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text('Copiar link', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsProvider(widget.slug));

    final primary = widget.primaryColor;
    final onSurface = const Color(0xFF1A1D21);
    final surfaceVariant = const Color(0xFF5C636A);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _designGray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: appointmentsAsync.when(
          data: (all) {
            final eventsMap = <DateTime, List<Appointment>>{};
            for (final a in all) {
              if (a.status == 'canceled') continue;
              final d = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day);
              eventsMap.putIfAbsent(d, () => []).add(a);
            }
            final filtered = _selectedDay == null
                ? <Appointment>[]
                : all
                    .where((a) {
                      return a.dateTime.year == _selectedDay!.year &&
                          a.dateTime.month == _selectedDay!.month &&
                          a.dateTime.day == _selectedDay!.day;
                    })
                    .toList()
                  ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

            final monthTitle = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
            final dayTitle = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDay ?? _focusedDay);
            final today = DateTime.now();
            final selectedIsToday =
                _selectedDay != null && isSameDay(_selectedDay!, today);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agenda',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            monthTitle[0].toUpperCase() + monthTitle.substring(1),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: surfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Filtros (em breve)',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Filtros em breve.')),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: _designGray50,
                        foregroundColor: onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Ações rápidas',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: surfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          showWalkInCheckoutSheet(
                            context,
                            slug: widget.slug,
                            primaryColor: primary,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: _onBrandColor(primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                        label: Text(
                          'Atendimento avulso',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showNovoAgendamentoInfo,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF121212),
                          foregroundColor: const Color(0xFFFFD54F),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.link_rounded, size: 20),
                        label: Text(
                          'Link público',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _designGray50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _designGray200),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                    child: TableCalendar<Appointment>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      _selectedDay != null && isSameDay(_selectedDay, day),
                  eventLoader: (day) =>
                      eventsMap[DateTime(day.year, day.month, day.day)] ?? [],
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      final count = events.length;
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onFormatChanged: (format) {
                    if (format != _calendarFormat) {
                      setState(() => _calendarFormat = format);
                    }
                  },
                  availableCalendarFormats: const {
                    CalendarFormat.week: 'Semana',
                    CalendarFormat.month: 'Mês',
                  },
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  locale: 'pt_BR',
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonTextStyle: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: primary),
                    rightChevronIcon: Icon(Icons.chevron_right, color: primary),
                    headerPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: TextStyle(color: onSurface, fontSize: 14),
                    weekendTextStyle: TextStyle(color: onSurface.withValues(alpha: 0.7)),
                    selectedDecoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.white),
                    todayDecoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFF121212),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 5,
                    outsideTextStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: surfaceVariant, fontWeight: FontWeight.w500),
                    weekendStyle: TextStyle(color: surfaceVariant),
                  ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDay != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dayTitle[0].toUpperCase()}${dayTitle.substring(1)}',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filtered.length} atendimento${filtered.length == 1 ? '' : 's'} neste dia',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: surfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selectedIsToday)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Hoje',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _designGray50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _designGray200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 44,
                              color: surfaceVariant.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _selectedDay == null
                                  ? 'Selecione um dia'
                                  : 'Nada marcado neste dia',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedDay == null
                                  ? 'Toque no calendário para ver os horários.'
                                  : 'Venda na hora ou combine pelo link com o cliente.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: surfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            if (_selectedDay != null) ...[
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () {
                                  showWalkInCheckoutSheet(
                                    context,
                                    slug: widget.slug,
                                    primaryColor: primary,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: _onBrandColor(primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                                label: Text(
                                  'Iniciar atendimento avulso',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: filtered.map((a) {
                      final timeStr = DateFormat('HH:mm').format(a.dateTime);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  timeStr,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${a.durationMinutes}M',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: surfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Material(
                                elevation: 0,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _designGray200),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.clientName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: onSurface,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              color: _kpiStatusBorderColor(a.status).withValues(alpha: 0.12),
                                            ),
                                            child: Text(
                                              _statusLabel(a.status),
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _kpiStatusBorderColor(a.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (a.proposedDateTime != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sugestão enviada ao cliente: ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(a.proposedDateTime!)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF00695C),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  a.serviceName,
                                                  style: GoogleFonts.poppins(fontSize: 12, color: onSurface),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (a.walkIn)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF8E1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: const Color(0xFFFFB74D)),
                                              ),
                                              child: Text(
                                                'Avulso',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFFE65100),
                                                ),
                                              ),
                                            ),
                                          if (a.staffName != null && a.staffName!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 9,
                                                    backgroundColor: const Color(0xFFE5E7EB),
                                                    child: Text(
                                                      a.staffName![0].toUpperCase(),
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w700,
                                                        color: onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    a.staffName!,
                                                    style: GoogleFonts.poppins(fontSize: 12, color: onSurface),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (a.status == 'pending') ...[
                                            IconButton(
                                              icon: const Icon(Icons.check, color: Colors.green),
                                              tooltip: 'Confirmar',
                                              onPressed: () => _updateStatus(a.id, 'confirmed'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _suggestAlternateTime(a),
                                              icon: const Icon(Icons.schedule_send_outlined, size: 18, color: Color(0xFF00695C)),
                                              label: Text(
                                                'Sugerir horário',
                                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF00695C)),
                                              ),
                                            ),
                                            if (a.proposedDateTime != null)
                                              TextButton.icon(
                                                onPressed: () => _clearProposedTime(a),
                                                icon: Icon(Icons.undo_rounded, size: 18, color: Colors.grey.shade700),
                                                label: Text(
                                                  'Cancelar sugestão',
                                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                                ),
                                              ),
                                            IconButton(
                                              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                                              tooltip: 'Cancelar',
                                              onPressed: () => _updateStatus(a.id, 'canceled'),
                                            ),
                                          ] else if (a.status == 'confirmed') ...[
                                            TextButton.icon(
                                              onPressed: () => _anticipateAppointment(a),
                                              icon: const Icon(Icons.call_made_rounded, size: 18, color: Color(0xFF1565C0)),
                                              label: Text(
                                                'Antecipar',
                                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF1565C0)),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _suggestAlternateTime(a),
                                              icon: const Icon(Icons.schedule_send_outlined, size: 18, color: Color(0xFF00695C)),
                                              label: Text(
                                                'Sugerir horário',
                                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF00695C)),
                                              ),
                                            ),
                                            if (a.proposedDateTime != null)
                                              TextButton.icon(
                                                onPressed: () => _clearProposedTime(a),
                                                icon: Icon(Icons.undo_rounded, size: 18, color: Colors.grey.shade700),
                                                label: Text(
                                                  'Cancelar sugestão',
                                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                                ),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.done_all, color: Colors.blue),
                                              tooltip: 'Concluir',
                                              onPressed: () =>
                                                  _updateStatus(a.id, 'completed', clientId: a.clientId),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                                              tooltip: 'Cancelar',
                                              onPressed: () => _updateStatus(a.id, 'canceled'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agendamentos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    _selectedDay != null && isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarFormat: CalendarFormat.month,
                locale: 'pt_BR',
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erro ao carregar: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServicesCard extends ConsumerWidget {
  final String slug;
  final Color primaryColor;

  const _ServicesCard({required this.slug, required this.primaryColor});

  String _durLabel(Service s) {
    final m = s.durationMinutes;
    if (m >= 60) {
      final h = m ~/ 60;
      final r = m % 60;
      return r == 0 ? '${h}h' : '${h}h ${r}min';
    }
    return '$m min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider(slug));
    final primary = primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _openServiceForm(context, ref, slug, null),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text('Adicionar'),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum serviço cadastrado. Clique em Adicionar para criar.',
                  style: GoogleFonts.poppins(
                    color: _designGray600,
                  ),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                const spacing = 12.0;
                final crossAxisCount = w >= 560 ? 2 : 1;
                final cellW = (w - spacing * (crossAxisCount > 1 ? 1 : 0)) / crossAxisCount;
                final side = (cellW - 28).clamp(120.0, kServicePhotoEditorPreviewSide);
                final estHeight = side + 178;
                final aspect = (cellW / estHeight).clamp(0.48, 0.92);

                Widget serviceTile(int i, Service s) {
                  final highlight = i == 0;
                  final url = s.imageUrl?.trim();
                  final hasUrl = url != null && url.isNotEmpty;
                  return Opacity(
                    opacity: s.active ? 1 : 0.62,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: highlight ? const Color(0xFFFFC107) : _designGray200,
                            width: highlight ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: side,
                                        height: side,
                                        child: hasUrl
                                            ? ServiceStorageImage(
                                                key: ValueKey('svc_img_${s.id}_$url'),
                                                imageUrl: url,
                                                width: side,
                                                height: side,
                                                fit: BoxFit.cover,
                                                showLoading: true,
                                                placeholder: ColoredBox(
                                                  color: highlight
                                                      ? const Color(0xFFFFF8E1)
                                                      : const Color(0xFFF3F4F6),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.content_cut_rounded,
                                                      color: highlight
                                                          ? const Color(0xFFFF8F00)
                                                          : _designGray600,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : ServiceThumbnailImage(
                                                key: ValueKey('svc_thumb_${s.id}'),
                                                slug: slug,
                                                serviceId: s.id,
                                                imageUrl: null,
                                                width: side,
                                                height: side,
                                                borderRadius: 0,
                                                fit: BoxFit.cover,
                                                showLoading: true,
                                                placeholder: ColoredBox(
                                                  color: highlight
                                                      ? const Color(0xFFFFF8E1)
                                                      : const Color(0xFFF3F4F6),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.content_cut_rounded,
                                                      color: highlight
                                                          ? const Color(0xFFFF8F00)
                                                          : _designGray600,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  if (!s.active)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Material(
                                        color: const Color(0xFF374151),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Text(
                                            'Oculto no link',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    s.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _designGray900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 14, color: _designGray600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _durLabel(s),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _designGray600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        s.priceFormatted,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: _designGray900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Tooltip(
                                        message: 'Mostrar no link de agendamento',
                                        child: Transform.scale(
                                          scale: 0.82,
                                          child: Switch(
                                            value: s.active,
                                            onChanged: (v) =>
                                                _setServiceActive(context, ref, slug, s.id, v),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 21),
                                        color: _designGray600,
                                        onPressed: () => _openServiceForm(context, ref, slug, s),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, size: 21, color: Theme.of(context).colorScheme.error),
                                        onPressed: () => _deleteService(context, ref, slug, s.id),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: aspect,
                  ),
                  itemCount: services.length,
                  itemBuilder: (context, i) => serviceTile(i, services[i]),
                );
              },
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Erro ao carregar: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  void _openServiceForm(
    BuildContext context,
    WidgetRef ref,
    String slug,
    Service? existing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ServiceFormSheet(slug: slug, existing: existing),
    );
  }

  Future<void> _setServiceActive(
    BuildContext context,
    WidgetRef ref,
    String slug,
    String serviceId,
    bool active,
  ) async {
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore
          .collection(barbershopsCollection)
          .doc(slug)
          .collection('services')
          .doc(serviceId)
          .set({'active': active}, SetOptions(merge: true));
      ref.invalidate(servicesProvider(slug));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteService(
    BuildContext context,
    WidgetRef ref,
    String slug,
    String serviceId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir serviço?'),
        content: const Text(
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore
          .collection(barbershopsCollection)
          .doc(slug)
          .collection('services')
          .doc(serviceId)
          .delete();
      ref.invalidate(servicesProvider(slug));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço excluído.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _ClientsCard extends ConsumerStatefulWidget {
  final String slug;
  final Color primaryColor;

  const _ClientsCard({required this.slug, required this.primaryColor});

  @override
  ConsumerState<_ClientsCard> createState() => _ClientsCardState();
}

String _formatClientPhone(String w) {
  if (w.length >= 10) {
    return '(${w.substring(0, 2)}) ${w.length == 11 ? w.substring(2, 7) : w.substring(2, 6)}-${w.length == 11 ? w.substring(7) : w.substring(6)}';
  }
  return w;
}

String _ultimaVisitaLabel(DateTime? d) {
  if (d == null) return 'Última: —';
  final n = DateTime.now();
  final t0 = DateTime(n.year, n.month, n.day);
  final d0 = DateTime(d.year, d.month, d.day);
  if (d0 == t0) return 'Última: Hoje';
  if (d0 == t0.subtract(const Duration(days: 1))) return 'Última: Ontem';
  final diff = t0.difference(d0).inDays;
  if (diff < 7) return 'Última: Há $diff ${diff == 1 ? "dia" : "dias"}';
  if (diff < 30) return 'Última: Há ${(diff / 7).floor()} ${(diff / 7).floor() == 1 ? "semana" : "semanas"}';
  return 'Última: ${DateFormat("d MMM", "pt_BR").format(d)}';
}

class _ClientsCardState extends ConsumerState<_ClientsCard> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, DateTime> _lastVisitsByWhatsapp(List<Appointment> appts) {
    final m = <String, DateTime>{};
    final now = DateTime.now();
    for (final a in appts) {
      if (a.status == 'canceled') continue;
      if (!a.dateTime.isBefore(now)) continue;
      final w = a.clientWhatsapp;
      final t = a.dateTime;
      if (!m.containsKey(w) || t.isAfter(m[w]!)) m[w] = t;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider(widget.slug));
    final appointmentsAsync = ref.watch(appointmentsProvider(widget.slug));
    final search = _searchController.text.trim().toLowerCase();
    final primary = widget.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        clientsAsync.when(
          data: (clients) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clientes',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _designGray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sua base de clientes (${clients.length})',
                  style: GoogleFonts.poppins(fontSize: 14, color: _designGray600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente...',
                          prefixIcon: const Icon(Icons.search_rounded, color: _designGray600),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _designGray200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _designGray200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Filtro em breve.')),
                          );
                        },
                        icon: const Icon(Icons.filter_list_rounded),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: _designGray200),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        clientsAsync.when(
          data: (clients) {
            return appointmentsAsync.when(
              data: (appts) {
                final lastBy = _lastVisitsByWhatsapp(appts);
                final referralCounts = <String, int>{};
                for (final c in clients) {
                  if (c.referredByWhatsapp != null && c.referredByWhatsapp!.isNotEmpty) {
                    referralCounts[c.referredByWhatsapp!] = (referralCounts[c.referredByWhatsapp!] ?? 0) + 1;
                  }
                }
                final topReferrers = clients
                    .where((c) => (referralCounts[c.whatsapp] ?? 0) > 0)
                    .toList()
                  ..sort(
                    (a, b) => (referralCounts[b.whatsapp] ?? 0).compareTo(referralCounts[a.whatsapp] ?? 0),
                  );
                final top5 = topReferrers.take(5).toList();

                final filtered = search.isEmpty
                    ? clients
                    : clients.where((c) {
                        final q = search.replaceAll(RegExp(r'[^\d\w]'), '');
                        return c.name.toLowerCase().contains(search) || c.whatsapp.contains(q);
                      }).toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      clients.isEmpty
                          ? 'Nenhum cliente cadastrado ainda. Clientes são adicionados ao agendar na página pública.'
                          : 'Nenhum cliente encontrado.',
                      style: GoogleFonts.poppins(color: _designGray600),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _designGray200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (top5.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            'Quem mais indica',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ),
                        ...top5.asMap().entries.map((e) {
                          final c = e.value;
                          final count = referralCounts[c.whatsapp] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Text('${e.key + 1}.', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _designGray600, fontSize: 12)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(c.name, style: GoogleFonts.poppins(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                Chip(
                                  label: Text('$count indicações', style: const TextStyle(fontSize: 10)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          );
                        }),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1),
                        ),
                      ],
                      ...filtered.asMap().entries.map((e) {
                        final c = e.value;
                        final isLast = e.key == filtered.length - 1;
                        final phone = _formatClientPhone(c.whatsapp);
                        final visits = c.totalAppointments;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: primary.withValues(alpha: 0.2),
                                    foregroundColor: primary,
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _designGray900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_rounded, size: 14, color: _designGray600),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: _designGray600)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$visits visitas',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _designGray900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event_rounded, size: 12, color: _designGray600),
                                          const SizedBox(width: 4),
                                          Text(
                                            _ultimaVisitaLabel(lastBy[c.whatsapp]),
                                            style: GoogleFonts.poppins(fontSize: 11, color: _designGray600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Erro ao carregar: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// Painel "Quem mais atende": ranking por atendimentos realizados.
class _QuemMaisAtendeCard extends ConsumerWidget {
  const _QuemMaisAtendeCard({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider(slug));
    return appointmentsAsync.when(
      data: (list) {
        final completed = list.where((a) => a.status == 'completed').toList();
        final byStaff = <String, int>{};
        for (final a in completed) {
          final key = a.staffName != null && a.staffName!.isNotEmpty ? a.staffName! : 'Dono / Único';
          byStaff[key] = (byStaff[key] ?? 0) + 1;
        }
        final sorted = byStaff.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quem mais atende',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...sorted.take(5).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${e.value} atend.', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VouchersCard extends ConsumerWidget {
  final String slug;

  const _VouchersCard({required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(vouchersProvider(slug));
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final btn = FilledButton.icon(
                  onPressed: () => _openVoucherForm(context, slug),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Criar Voucher'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                );
                if (c.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vouchers / Promocionais',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: btn),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Vouchers / Promocionais',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    btn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            vouchersAsync.when(
              data: (vouchers) {
                if (vouchers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nenhum voucher. Clique em Criar Voucher para adicionar.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return Column(
                  children: vouchers.map((v) {
                    final status = !v.active
                        ? 'Inativo'
                        : v.isExpired
                            ? 'Expirado'
                            : 'Ativo';
                    final statusColor = !v.active
                        ? Colors.grey
                        : v.isExpired
                            ? Colors.orange
                            : Colors.green;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text('${v.code} — ${v.description}'),
                          ),
                          if (v.generatedFromPoints)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: const Text(
                                  'Fidelidade',
                                  style: TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${v.discountLabel} • Válido até ${v.expiresAt != null ? dateFormat.format(v.expiresAt!) : "—"} • $status • ${v.usedBy.length} usos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Chip(
                        label: Text(
                          status,
                          style: TextStyle(fontSize: 11, color: statusColor),
                        ),
                        backgroundColor: statusColor.withValues(alpha: 0.2),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Erro ao carregar: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVoucherForm(BuildContext context, String slug) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VoucherFormSheet(slug: slug),
    );
  }
}

class _VoucherFormSheet extends ConsumerStatefulWidget {
  final String slug;

  const _VoucherFormSheet({required this.slug});

  @override
  ConsumerState<_VoucherFormSheet> createState() => _VoucherFormSheetState();
}

class _VoucherFormSheetState extends ConsumerState<_VoucherFormSheet> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _codeController;
  late final TextEditingController _valueController;
  String _discountType = 'percent';
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _codeController = TextEditingController(text: generateVoucherCode());
    _valueController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _codeController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final description = _descriptionController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição do voucher')),
      );
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ou gere um código')),
      );
      return;
    }
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido')),
      );
      return;
    }
    if (_discountType == 'percent' && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentual não pode ser maior que 100')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final voucher = Voucher(
        id: '',
        code: code,
        description: description,
        discountType: _discountType,
        discountValue: value,
        expiresAt: _expiresAt,
        usedBy: const [],
        active: true,
        createdAt: null,
      );
      await firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('vouchers')
          .add(voucher.toFirestore());

      ref.invalidate(vouchersProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher criado! Código: use no campo do formulário.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Criar Voucher',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: 10% off no Corte + Barba',
                border: OutlineInputBorder(),
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Código',
                hintText: 'INDICA10',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Gerar novo código',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _codeController.text = generateVoucherCode()),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _discountType,
              decoration: const InputDecoration(
                labelText: 'Tipo de desconto',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'percent', child: Text('Percentual (%)')),
                DropdownMenuItem(value: 'fixed', child: Text('Valor fixo (R\$)')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _discountType = v ?? 'percent'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: _discountType == 'percent' ? 'Valor (%)' : 'Valor (R\$)',
                hintText: _discountType == 'percent' ? '10' : '10,00',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Válido até'),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(_expiresAt),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiresAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _expiresAt = picked);
                      }
                    },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar Voucher'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFormSheet extends ConsumerStatefulWidget {
  final String slug;
  final Service? existing;

  const _ServiceFormSheet({required this.slug, this.existing});

  @override
  ConsumerState<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<_ServiceFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late final TextEditingController _descriptionController;
  bool _saving = false;
  List<ServiceProductUse> _productConsumptions = [];
  String? _category;
  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;
  bool _visibleToClients = true;

  @override
  void initState() {
    super.initState();
    _visibleToClients = widget.existing?.active ?? true;
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _priceController = TextEditingController(
      text: widget.existing?.price.toStringAsFixed(2) ?? '',
    );
    _durationController = TextEditingController(
      text: widget.existing?.durationMinutes.toString() ?? '30',
    );
    _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
    _category = widget.existing?.category;
    _existingImageUrl = widget.existing?.imageUrl;
    _productConsumptions = List.from(widget.existing?.productConsumptions ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.existing == null || !mounted) return;
      final u = widget.existing!.imageUrl?.trim();
      if (u != null && u.isNotEmpty) return;
      try {
        final storage = ref.read(firebaseStorageProvider);
        String? url;
        for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
          try {
            url = await storage
                .ref('services/${widget.slug}/${widget.existing!.id}.$ext')
                .getDownloadURL();
            break;
          } catch (_) {}
        }
        if (url == null) return;
        if (!mounted) return;
        setState(() => _existingImageUrl = url);
        await ref.read(firestoreProvider)
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('services')
            .doc(widget.existing!.id)
            .set({'imageUrl': url}, SetOptions(merge: true));
        ref.invalidate(servicesProvider(widget.slug));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Na Web, [FilePicker] por vezes devolve [PlatformFile.bytes] vazio; lê [readStream] se existir.
  Future<Uint8List?> _readPickerBytes(FilePickerResult? result) async {
    final f = result?.files.singleOrNull;
    if (f == null) return null;
    if (f.bytes != null && f.bytes!.isNotEmpty) return f.bytes;
    final stream = f.readStream;
    if (stream != null) {
      final chunks = <int>[];
      await for (final c in stream) {
        chunks.addAll(c);
      }
      if (chunks.isEmpty) return null;
      return Uint8List.fromList(chunks);
    }
    return null;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do serviço')),
      );
      return;
    }
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um preço válido')),
      );
      return;
    }
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration < 5 || duration > 240) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duração deve ser entre 5 e 240 minutos')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final desc = _descriptionController.text.trim();
      String? imageUrl = _existingImageUrl;

      late final DocumentReference<Map<String, dynamic>> serviceDocRef;
      if (widget.existing != null) {
        serviceDocRef = firestore
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('services')
            .doc(widget.existing!.id);
      } else {
        serviceDocRef = firestore
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('services')
            .doc();
      }

      if (_pickedImageBytes != null) {
        final resized = resizeAndCompressForMobile(_pickedImageBytes!);
        final bytesToUpload = resized ?? _pickedImageBytes!;
        final contentType =
            resized != null ? 'image/jpeg' : storageContentTypeForBytes(_pickedImageBytes!);
        final storage = ref.read(firebaseStorageProvider);
        final path = 'services/${widget.slug}/${serviceDocRef.id}.jpg';
        final refStorage = storage.ref().child(path);
        await refStorage.putData(
          bytesToUpload,
          SettableMetadata(contentType: contentType),
        );
        imageUrl = await refStorage.getDownloadURL();
      }

      final data = <String, dynamic>{
        'name': name,
        'price': price,
        'durationMinutes': duration,
        'active': _visibleToClients,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (desc.isNotEmpty) 'description': desc,
        if (_category != null && _category!.isNotEmpty) 'category': _category,
        if (_productConsumptions.isNotEmpty)
          'productConsumptions': _productConsumptions.map((e) => e.toMap()).toList(),
      };

      await serviceDocRef.set(data, SetOptions(merge: true));
      // Confirma no servidor antes de atualizar a lista (evita fechar o sheet com snapshot antigo).
      final serverSnap = await serviceDocRef.get(const GetOptions(source: Source.server));
      if (_pickedImageBytes != null) {
        final u = serverSnap.data()?['imageUrl'];
        final ok = u is String && u.trim().isNotEmpty;
        if (!ok) {
          throw Exception(
            'A foto foi enviada ao Storage, mas o Firestore não guardou o campo imageUrl. '
            'Verifique no Firebase Console o documento do serviço e as regras de escrita em barbershops/{id}/services.',
          );
        }
      }

      ref.invalidate(servicesProvider(widget.slug));
      // Garante que a lista recebe imageUrl antes de fechar o sheet (evita miniatura presa na tesoura).
      try {
        await ref.read(servicesProvider(widget.slug).future).timeout(const Duration(seconds: 15));
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'Serviço atualizado!'
                  : 'Serviço adicionado!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            widget.existing != null ? 'Editar Serviço' : 'Adicionar Serviço',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome do serviço',
              hintText: 'Ex: Corte Masculino',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Preço (R\$)',
              hintText: '40,00',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            decoration: const InputDecoration(
              labelText: 'Duração (minutos)',
              hintText: '30',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_saving,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visível no link de agendamento'),
            subtitle: Text(
              'Desligue para ocultar temporariamente dos clientes (continua no seu painel).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
            value: _visibleToClients,
            onChanged: _saving ? null : (v) => setState(() => _visibleToClients = v),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Foto do serviço', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Quadrado fixo — a imagem preenche o centro (igual ao catálogo e ao link de agendamento).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              Center(
                child: ServiceImageSquareFrame(
                  side: kServicePhotoEditorPreviewSide,
                  child: _pickedImageBytes != null
                      ? Image.memory(
                          _pickedImageBytes!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          gaplessPlayback: true,
                        )
                      : widget.existing != null &&
                              _existingImageUrl != null &&
                              _existingImageUrl!.trim().isNotEmpty
                          ? ServiceStorageImage(
                              imageUrl: _existingImageUrl!.trim(),
                              width: kServicePhotoEditorPreviewSide,
                              height: kServicePhotoEditorPreviewSide,
                              fit: BoxFit.cover,
                              showLoading: true,
                              placeholder: serviceImageEmptySquarePlaceholder(side: kServicePhotoEditorPreviewSide),
                            )
                          : widget.existing != null
                              ? ServiceThumbnailImage(
                                  slug: widget.slug,
                                  serviceId: widget.existing!.id,
                                  imageUrl: null,
                                  width: kServicePhotoEditorPreviewSide,
                                  height: kServicePhotoEditorPreviewSide,
                                  borderRadius: 0,
                                  fit: BoxFit.cover,
                                  showLoading: true,
                                  placeholder: serviceImageEmptySquarePlaceholder(side: kServicePhotoEditorPreviewSide),
                                )
                              : serviceImageEmptySquarePlaceholder(side: kServicePhotoEditorPreviewSide),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (!context.mounted) return;
                            final raw = await _readPickerBytes(result);
                            if (raw == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Não foi possível ler a imagem. Tente JPG ou PNG, ou um ficheiro mais pequeno.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            if (!context.mounted) return;
                            final cropped = await showServiceSquareCropDialog(context, imageBytes: raw);
                            if (cropped != null && context.mounted) {
                              setState(() => _pickedImageBytes = cropped);
                            }
                          },
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: Text(_pickedImageBytes != null ? 'Trocar imagem' : 'Escolher imagem'),
                  ),
                  if (_pickedImageBytes != null)
                    Text(
                      'Nova foto: toque em Salvar para publicar.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  if (_pickedImageBytes == null &&
                      widget.existing != null &&
                      (_existingImageUrl != null && _existingImageUrl!.trim().isNotEmpty))
                    Text(
                      'Foto do catálogo (use Trocar imagem para substituir).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Detalhes / descrição (opcional)',
              hintText: 'Ex: procedimento, passo a passo, indicações',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            enabled: !_saving,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nenhuma')),
              ...serviceCategoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          Text(
            'Produtos consumidos (baixa ao concluir agendamento). Use "Uso no studio (%)" para consumo percentual por atendimento.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_productConsumptions.length, (i) {
            final use = _productConsumptions[i];
            final productsAsync = ref.watch(productsProvider(widget.slug));
            final productName = productsAsync.valueOrNull?.where((p) => p.id == use.productId).firstOrNull?.name ?? use.productId;
            final label = use.useStudio
                ? '$productName: ${use.consumptionPercent?.toStringAsFixed(0)}% por atend. (studio)'
                : '$productName: ${use.quantity} ${use.quantity == 1 ? 'un.' : 'un.'} (estoque)';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _saving ? null : () => setState(() => _productConsumptions.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          _AddProductConsumptionRow(
            slug: widget.slug,
            existingIds: _productConsumptions.map((e) => e.productId).toSet(),
            onAdd: (use) => setState(() => _productConsumptions.add(use)),
            enabled: !_saving,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.existing != null ? 'Salvar' : 'Adicionar'),
          ),
        ],
        ),
      ),
    );
  }
}

class _AddProductConsumptionRow extends ConsumerStatefulWidget {
  final String slug;
  final Set<String> existingIds;
  final void Function(ServiceProductUse) onAdd;
  final bool enabled;

  const _AddProductConsumptionRow({
    required this.slug,
    required this.existingIds,
    required this.onAdd,
    required this.enabled,
  });

  @override
  ConsumerState<_AddProductConsumptionRow> createState() => _AddProductConsumptionRowState();
}

class _AddProductConsumptionRowState extends ConsumerState<_AddProductConsumptionRow> {
  String? _selectedProductId;
  bool _useStudioPercent = true;
  final _percentController = TextEditingController(text: '5');
  final _qtyController = TextEditingController(text: '1');

  @override
  void dispose() {
    _percentController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onAdd() {
    if (!widget.enabled) return;
    final products = ref.read(productsProvider(widget.slug)).valueOrNull ?? [];
    if (products.isEmpty) return;
    final id = _selectedProductId ?? products.first.id;
    if (widget.existingIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este produto já foi adicionado ao serviço')),
      );
      return;
    }
    if (_useStudioPercent) {
      final percent = double.tryParse(_percentController.text.replaceAll(',', '.'));
      if (percent == null || percent <= 0 || percent > 100) return;
      widget.onAdd(ServiceProductUse(productId: id, consumptionPercent: percent));
      _percentController.text = '5';
    } else {
      final qty = double.tryParse(_qtyController.text.replaceAll(',', '.'));
      if (qty == null || qty <= 0) return;
      widget.onAdd(ServiceProductUse(productId: id, quantity: qty));
      _qtyController.text = '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.slug));
    final products = productsAsync.valueOrNull ?? [];
    if (products.isEmpty) {
      return const Text(
        'Cadastre produtos na aba Estoque para vincular ao serviço.',
        style: TextStyle(fontSize: 12, color: Color(0xFF5C636A)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedProductId ?? products.first.id,
                decoration: const InputDecoration(
                  labelText: 'Produto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.unitLabel})'))).toList(),
                onChanged: widget.enabled ? (v) => setState(() => _selectedProductId = v) : null,
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Studio %')),
                ButtonSegment(value: false, label: Text('Qtd')),
              ],
              selected: {_useStudioPercent},
              onSelectionChanged: widget.enabled
                  ? (s) => setState(() => _useStudioPercent = s.first)
                  : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _useStudioPercent ? _percentController : _qtyController,
                decoration: InputDecoration(
                  labelText: _useStudioPercent ? '%' : 'Qtd',
                  hintText: _useStudioPercent ? '5' : '1',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: widget.enabled,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Adicionar consumo',
              onPressed: widget.enabled ? _onAdd : null,
            ),
          ],
        ),
        if (_useStudioPercent)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Retire o produto para uso no studio na aba Estoque. Ao concluir atendimento, esse % será descontado até acabar; em 15% pode retirar outro.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF5C636A)),
            ),
          ),
      ],
    );
  }
}

ColorPreset _presetFromColors(Color primary, Color secondary) {
  final p = primary.value & 0x00FFFFFF;
  ColorPreset best = ColorPreset.rosa;
  int bestDiff = 0xFFFFFF;
  for (final preset in ColorPreset.values) {
    final diff = (p - (preset.primary & 0x00FFFFFF)).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = preset;
    }
  }
  return best;
}

class _BarberShopFormSheet extends ConsumerStatefulWidget {
  final BarberShop? initial;

  const _BarberShopFormSheet({this.initial});

  @override
  ConsumerState<_BarberShopFormSheet> createState() =>
      _BarberShopFormSheetState();
}

class _BarberShopFormSheetState extends ConsumerState<_BarberShopFormSheet> {
  static const _businessTypeOptions = [
    ('barbershop', 'Barbearia'),
    ('beauty_salon', 'Salão de Beleza'),
    ('manicure', 'Manicure'),
    ('pedicure', 'Pedicure'),
    ('eyebrows', 'Sobrancelhas'),
    ('lash_design', 'Lash Design'),
  ];
  TextEditingController? _nameController;
  TextEditingController? _slugController;
  List<String> _businessTypes = const ['barbershop'];
  String _themeStyle = 'both';
  String _loyaltyCardStyle = 'masculine';
  bool _singleAttendant = true;
  final _openTimeController = TextEditingController(text: '09:00');
  final _closeTimeController = TextEditingController(text: '19:00');
  /// Dias fechados (yyyy-MM-dd)
  Set<String> _closedDateKeys = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _slugController = TextEditingController(text: widget.initial?.slug ?? '');
    _businessTypes = List.from(widget.initial?.businessTypes ?? ['barbershop']);
    if (_businessTypes.isEmpty) _businessTypes = ['barbershop'];
    _themeStyle = widget.initial?.themeStyle ?? 'both';
    _loyaltyCardStyle = widget.initial?.loyaltyCardStyle ?? 'masculine';
    _singleAttendant = widget.initial?.singleAttendant ?? true;
    _openTimeController.text = widget.initial?.openTime ?? '09:00';
    _closeTimeController.text = widget.initial?.closeTime ?? '19:00';
    _closedDateKeys = Set<String>.from(widget.initial?.closedDates ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(barberShopEditProvider.notifier).initFrom(widget.initial);
    });
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _slugController?.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  void _openStaffSheet(BuildContext context, String slug) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StaffSheet(slug: slug),
    );
  }

  Future<void> _pickBackground() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final bytes = result.files.first.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível ler a imagem.')),
          );
        }
        return;
      }
      if (mounted) {
        ref.read(barberShopEditProvider.notifier).setSelectedBackgroundFile(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de fundo selecionada. Clique em Salvar.')),
        );
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Erro ao escolher fundo: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _pickClosedDay() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
      helpText: 'Marcar dia fechado',
    );
    if (picked != null && mounted) {
      setState(() {
        _closedDateKeys.add(BarberShop.closedDateKeyForDay(picked));
      });
    }
  }

  String _closedDateLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    try {
      return DateFormat('dd/MM/yyyy').format(
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
      );
    } catch (_) {
      return key;
    }
  }

  Future<void> _save() async {
    final name = _nameController?.text.trim() ?? '';
    var slug = (_slugController?.text.trim() ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    if (slug.isEmpty) slug = 'meunegocio';

    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o nome do negócio.')),
        );
      }
      return;
    }

    final editNotifier = ref.read(barberShopEditProvider.notifier);
    editNotifier.setUploading(true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Usuário não logado');

      final editState = ref.read(barberShopEditProvider);
      String? backgroundImageUrl = widget.initial?.backgroundImageUrl;

      final storage = ref.read(firebaseStorageProvider);
      if (editState.selectedBackgroundFile != null) {
        final bytes = editState.selectedBackgroundFile!;
        final contentType = storageContentTypeForBytes(bytes);
        final ext = contentType == 'image/png'
            ? 'png'
            : contentType == 'image/webp'
                ? 'webp'
                : 'jpg';
        final refPath =
            'backgrounds/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final refStorage = storage.ref().child(refPath);
        await refStorage.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        backgroundImageUrl = await refStorage.getDownloadURL();
      }

      final primaryHex = colorToHex(editState.selectedColor);
      final secondaryHex = colorToHex(editState.selectedSecondaryColor);
      final firestore = ref.read(firestoreProvider);
      final openTime = _openTimeController.text.trim().isEmpty ? '09:00' : _openTimeController.text.trim();
      final closeTime = _closeTimeController.text.trim().isEmpty ? '19:00' : _closeTimeController.text.trim();
      final now = DateTime.now();
      final trialEndsAt = widget.initial == null
          ? now.add(const Duration(days: 7))
          : widget.initial!.trialEndsAt;
      final subscriptionStatus = widget.initial?.subscriptionStatus ?? 'trial';

      await firestore.collection(barbershopsCollection).doc(slug).set({
        'name': name,
        'slug': slug,
        'ownerUid': user.uid,
        'primaryColor': primaryHex,
        'secondaryColor': secondaryHex,
        if (backgroundImageUrl != null) 'backgroundImageUrl': backgroundImageUrl,
        'watermarkOpacity': widget.initial?.watermarkOpacity ?? 0.15,
        'plan': widget.initial?.plan ?? 'basic',
        'businessTypes': _businessTypes,
        'themeStyle': _themeStyle,
        'loyaltyCardStyle': _loyaltyCardStyle,
        'singleAttendant': _singleAttendant,
        'openTime': openTime,
        'closeTime': closeTime,
        'closedDates': _closedDateKeys.toList()..sort(),
        'referralPoints': widget.initial?.referralPoints ?? 30,
        if (trialEndsAt != null) 'trialEndsAt': Timestamp.fromDate(trialEndsAt),
        'subscriptionStatus': subscriptionStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.initial == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ref.invalidate(barberShopProvider);
      ref.invalidate(barberShopBySlugProvider(slug));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alterações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      editNotifier.setUploading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(barberShopEditProvider);
    final editNotifier = ref.read(barberShopEditProvider.notifier);
    final uploading = editState.uploading;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Criar meu negócio' : 'Configurações do negócio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dados do negócio',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController!,
              decoration: const InputDecoration(
                labelText: 'Nome do negócio',
                hintText: 'Ex: Corte Legal',
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !uploading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugController!,
              decoration: const InputDecoration(
                labelText: 'Slug (URL)',
                hintText: 'meunegocio',
              ),
              enabled: widget.initial == null && !uploading,
            ),
            const SizedBox(height: 24),
            Text(
              'Tipo de estabelecimento',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _businessTypeOptions.map((e) {
                final value = e.$1;
                final label = e.$2;
                final selected = _businessTypes.contains(value);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: uploading
                      ? null
                      : (v) {
                          setState(() {
                            if (v) {
                              if (!_businessTypes.contains(value)) _businessTypes = [..._businessTypes, value];
                            } else {
                              _businessTypes = _businessTypes.where((x) => x != value).toList();
                              if (_businessTypes.isEmpty) _businessTypes = ['barbershop'];
                            }
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Tema (público-alvo)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'masculine', label: Text('Masculino')),
                ButtonSegment(value: 'feminine', label: Text('Feminino')),
                ButtonSegment(value: 'both', label: Text('Ambos')),
              ],
              selected: {_themeStyle},
              onSelectionChanged: uploading ? null : (s) => setState(() => _themeStyle = s.first),
            ),
            const SizedBox(height: 20),
            Text(
              'Cartão fidelidade (estilo)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'masculine', label: Text('Masculino')),
                ButtonSegment(value: 'feminine', label: Text('Feminino')),
              ],
              selected: {_loyaltyCardStyle},
              onSelectionChanged: uploading ? null : (s) => setState(() => _loyaltyCardStyle = s.first),
            ),
            const SizedBox(height: 24),
            Text(
              'Atendimento e horário',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Sou o único que atende'),
              subtitle: const Text('Desmarque se tiver funcionários; o cliente poderá escolher o profissional ao agendar.'),
              value: _singleAttendant,
              onChanged: uploading ? null : (v) => setState(() => _singleAttendant = v),
            ),
            if (!_singleAttendant && widget.initial?.slug != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: uploading ? null : () => _openStaffSheet(context, widget.initial!.slug),
                icon: const Icon(Icons.people_outline, size: 20),
                label: const Text('Gerenciar funcionários'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _openTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Abertura (HH:mm)',
                      hintText: '09:00',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.datetime,
                    enabled: !uploading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _closeTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Fechamento (HH:mm)',
                      hintText: '19:00',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.datetime,
                    enabled: !uploading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Feriados e dias fechados',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Datas em que o negócio não abre. O cliente não verá horários nesses dias.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: uploading ? null : _pickClosedDay,
              icon: const Icon(Icons.event_busy_outlined, size: 20),
              label: const Text('Adicionar dia fechado'),
            ),
            if (_closedDateKeys.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final key in (_closedDateKeys.toList()..sort()))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_closedDateLabel(key)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: uploading
                        ? null
                        : () => setState(() => _closedDateKeys.remove(key)),
                    tooltip: 'Remover',
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Aparência (página de agendamento e dashboard)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: uploading ? null : _pickBackground,
              icon: const Icon(Icons.wallpaper),
              label: const Text('Upload fundo da página'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Foto de fundo do negócio (interior, fachada). Aparece no painel (todas as abas), na página de agendamento e nas demais telas do link público do cliente.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (editState.selectedBackgroundFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  editState.selectedBackgroundFile!,
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (widget.initial?.backgroundImageUrl != null &&
                widget.initial!.backgroundImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.initial!.backgroundImageUrl!,
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Estilo de cores',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'O plano de fundo do app é sempre branco. Escolha uma combinação de cores para botões e destaques.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ColorPreset>(
              value: _presetFromColors(
                  editState.selectedColor, editState.selectedSecondaryColor),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
              items: ColorPreset.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: p.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(p.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: uploading
                  ? null
                  : (p) {
                      if (p != null) {
                        editNotifier.setSelectedColor(p.primaryColor);
                        editNotifier.setSelectedSecondaryColor(p.secondaryColor);
                      }
                    },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: uploading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: uploading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet para gerenciar funcionários: lista + adicionar + compartilhar link.
class _StaffSheet extends ConsumerWidget {
  const _StaffSheet({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider(slug));
    final servicesAsync = ref.watch(servicesProvider(slug));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Funcionários', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddStaffDialog(context, ref, slug, servicesAsync.valueOrNull ?? []),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Adicionar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final url = '${Uri.base.origin}/b/$slug/funcionario';
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link do funcionário copiado! Envie para ele entrar com o e-mail cadastrado.')),
                    );
                  },
                  icon: const Icon(Icons.link, size: 20),
                  label: const Text('Copiar link do funcionário'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Cadastre os profissionais. O cliente escolhe quem atende ao agendar.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link para o funcionário (não é o link de clientes):', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SelectableText(
                    '${Uri.base.origin}/b/$slug/funcionario',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: staffAsync.when(
                data: (list) => list.isEmpty
                    ? const Center(child: Text('Nenhum funcionário. Clique em Adicionar.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          return ListTile(
                            title: Text(s.name),
                            subtitle: Text('${s.email} • ${s.serviceIds.isEmpty ? "Todos os serviços" : "${s.serviceIds.length} serviço(s)"}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteStaff(ref, slug, s.id),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref, String slug, List<Service> services) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final selectedIds = <String>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Adicionar funcionário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                const Text('Serviços que realiza (vazio = todos):', style: TextStyle(fontSize: 12)),
                ...services.map((s) => CheckboxListTile(
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
                  value: selectedIds.contains(s.id),
                  onChanged: (v) => setState(() {
                    if (v == true) selectedIds.add(s.id); else selectedIds.remove(s.id);
                  }),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || email.isEmpty) return;
                final firestore = ref.read(firestoreProvider);
                await firestore.collection(barbershopsCollection).doc(slug).collection('staff').add({
                  'name': name,
                  'email': email,
                  'serviceIds': selectedIds.toList(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                ref.invalidate(staffProvider(slug));
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStaff(WidgetRef ref, String slug, String staffId) async {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection(barbershopsCollection).doc(slug).collection('staff').doc(staffId).delete();
    ref.invalidate(staffProvider(slug));
  }
}
