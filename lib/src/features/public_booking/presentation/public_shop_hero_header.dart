import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/barber_shop.dart';

/// Cabeçalho escuro com logo, nome e telefone (páginas públicas do cliente).
class PublicShopHeroHeader extends StatelessWidget {
  const PublicShopHeroHeader({
    super.key,
    required this.shop,
    required this.primary,
    this.height = 200,
    /// Quando o fundo já cobre a página (ex.: [PublicShellPage]), só escurece a faixa do cabeçalho.
    this.overlayOnly = false,
  });

  final BarberShop shop;
  final Color primary;
  final double height;
  final bool overlayOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!overlayOnly) ...[
            if (shop.backgroundImageUrl != null && shop.backgroundImageUrl!.isNotEmpty)
              Image.network(
                shop.backgroundImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primary.withValues(alpha: 0.75), const Color(0xFF1A1A1A)],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ] else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (shop.logoUrl != null && shop.logoUrl!.isNotEmpty)
                        ? Image.network(
                            shop.logoUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _logoPlaceholder(),
                          )
                        : _logoPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shop.businessTypeLabel,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(Icons.phone_rounded, color: primary),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Peça o contato do negócio na recepção ou pelo WhatsApp no agendamento.',
                            ),
                          ),
                        );
                      },
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

  Widget _logoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300), width: 1),
      ),
      child: const Icon(Icons.content_cut_rounded, color: Color(0xFFFFB300), size: 28),
    );
  }
}
