import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/barber_shop_providers.dart';

/// Shell da área do funcionário: sem bottom nav de cliente; AppBar com Sair.
class StaffShellPage extends ConsumerWidget {
  const StaffShellPage({
    super.key,
    required this.slug,
    required this.child,
    this.title,
  });

  final String slug;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(barberShopBySlugProvider(slug));
    final primary = Theme.of(context).colorScheme.primary;

    return shopAsync.when(
      data: (shop) {
        final appBarTitle = title ?? shop?.name ?? 'Funcionário';
        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: shop?.primaryColorAsColor ?? primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sair',
                onPressed: () {
                  ref.read(currentStaffProvider.notifier).state = null;
                  context.go('/b/$slug/funcionario');
                },
              ),
            ],
          ),
          body: child,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title ?? 'Funcionário')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('$e')),
      ),
    );
  }
}
