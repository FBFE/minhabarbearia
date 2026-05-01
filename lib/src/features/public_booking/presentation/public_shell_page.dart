import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/barber_shop_providers.dart';

/// Shell da página pública: sempre mostra Bottom Nav (Agenda/Fidelidade/Perfil pedem verificação).
class PublicShellPage extends ConsumerWidget {
  const PublicShellPage({
    super.key,
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  static const _mainPaths = ['agendar', 'agenda', 'fidelidade', 'perfil'];

  static int? _mainTabIndex(String location, String slug) {
    for (var i = 0; i < _mainPaths.length; i++) {
      final p = '/b/$slug/${_mainPaths[i]}';
      if (location == p || location == '$p/') {
        return i;
      }
    }
    return null;
  }

  static void _goTab(BuildContext context, String slug, int index) {
    if (index < 0 || index >= _mainPaths.length) {
      return;
    }
    context.go('/b/$slug/${_mainPaths[index]}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicPair = ref.watch(currentPublicClientProvider);
    final streamClientId =
        publicPair != null && publicPair.slug == slug ? publicPair.client.id : '';
    ref.listen(
      clientInShopByIdStreamProvider((slug: slug, clientId: streamClientId)),
      (prev, next) {
        next.when(
          data: (c) {
            if (c == null) return;
            final cur = ref.read(currentPublicClientProvider);
            if (cur != null && cur.slug == slug && cur.client.id == c.id) {
              ref.read(currentPublicClientProvider.notifier).state = (slug: cur.slug, client: c);
            }
          },
          loading: () {},
          error: (_, __) {},
        );
      },
    );
    final location = GoRouterState.of(context).matchedLocation;
    final tab = _mainTabIndex(location, slug);
    final body = tab == null
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 200) {
                return;
              }
              if (v < 0 && tab < 3) {
                _goTab(context, slug, tab + 1);
              } else if (v > 0 && tab > 0) {
                _goTab(context, slug, tab - 1);
              }
            },
            child: child,
          );
    final shopAsync = ref.watch(barberShopBySlugProvider(slug));

    Widget wrapWithShopBackground(Widget w) {
      return shopAsync.when(
        data: (shop) {
          final url = shop?.backgroundImageUrl?.trim();
          if (url == null || url.isEmpty) {
            return ColoredBox(color: const Color(0xFFF8F9FA), child: w);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF8F9FA)),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xFFF8F9FA).withValues(alpha: 0.82),
                ),
              ),
              w,
            ],
          );
        },
        loading: () => ColoredBox(color: const Color(0xFFF8F9FA), child: w),
        error: (_, __) => ColoredBox(color: const Color(0xFFF8F9FA), child: w),
      );
    }

    final wrappedBody = wrapWithShopBackground(body);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: wrappedBody,
      bottomNavigationBar: _PublicBottomNav(slug: slug),
    );
  }
}

class _PublicBottomNav extends StatelessWidget {
  const _PublicBottomNav({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isHome = location == '/b/$slug/agendar' || location == '/b/$slug/agendar/';
    final isAgenda = location.endsWith('/agenda');
    final isFidelidade = location.endsWith('/fidelidade');
    final isPerfil = location.endsWith('/perfil');

    // Design reference: white nav, border-t gray-200, h-16
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Início',
                selected: isHome,
                onTap: () => context.go('/b/$slug/agendar'),
              ),
              _NavItem(
                icon: Icons.calendar_today_rounded,
                label: 'Agenda',
                selected: isAgenda,
                onTap: () => context.go('/b/$slug/agenda'),
              ),
              _NavItem(
                icon: Icons.card_giftcard_rounded,
                label: 'Fidelidade',
                selected: isFidelidade,
                onTap: () => context.go('/b/$slug/fidelidade'),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Perfil',
                selected: isPerfil,
                onTap: () => context.go('/b/$slug/perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeGold = Color(0xFFFFC107);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? activeGold : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? const Color(0xFF1A1D21) : const Color(0xFF5C636A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF1A1D21) : const Color(0xFF5C636A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
