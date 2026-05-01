import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/fcm_provider.dart';
import '../pwa_install_actions.dart';
import '../pwa_web_info.dart';
import 'pwa_install_events.dart';

/// Secção em Configurações do negócio: instalar PWA + ativar notificações (dono).
class PwaBusinessSettingsSection extends ConsumerStatefulWidget {
  const PwaBusinessSettingsSection({super.key});

  @override
  ConsumerState<PwaBusinessSettingsSection> createState() => _PwaBusinessSettingsSectionState();
}

class _PwaBusinessSettingsSectionState extends ConsumerState<PwaBusinessSettingsSection> {
  bool _loadingNotif = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    PwaInstallEvents.instance.addListener(_onInstalled);
  }

  @override
  void dispose() {
    PwaInstallEvents.instance.removeListener(_onInstalled);
    super.dispose();
  }

  void _onInstalled() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onInstallTap() async {
    if (!kIsWeb) {
      return;
    }
    if (pwaIsStandalonePwa) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A aplicação já está instalada. Abra pelo ícone na tela inicial.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    setState(() => _installing = true);
    try {
      await pwaRunInstallFlowForContext(context);
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  Future<void> _onNotifTap(String? slug) async {
    if (!kIsWeb) {
      return;
    }
    setState(() => _loadingNotif = true);
    try {
      final r = await requestAndRegisterWebNotifications();
      if (!mounted) {
        return;
      }
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível. Permita notificações no browser e confira a chave VAPID no Firebase.'),
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
        setState(() {});
        return;
      }
      if (slug != null && slug.isNotEmpty) {
        final token = await requestFcmTokenAndPermission();
        if (token != null && mounted) {
          await saveOwnerFcmToken(ref, slug, token);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notificações ativadas para este negócio.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingNotif = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    final shop = ref.watch(barberShopProvider).valueOrNull;
    final slug = shop?.slug;

    final installed = pwaIsStandalonePwa;
    final browserNotifGranted = pwaWebNotificationsGranted;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aplicativo e notificações',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1D21),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Instale o app no telemóvel e ative as notificações para lembretes e alertas do negócio.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF5C636A),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            if (installed) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                title: Text(
                  'App na tela inicial',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Não precisa instalar de novo. Use o ícone do app para abrir.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
                ),
                dense: true,
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  pwaIsLikelyIOS ? Icons.phone_iphone : Icons.smartphone,
                  color: const Color(0xFF6366F1),
                  size: 28,
                ),
                title: Text(
                  pwaIsLikelyIOS ? 'Colocar na Tela de Início (iPhone/iPad)' : 'Instalar no Android (Chrome)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  pwaIsLikelyIOS
                      ? 'O Safari mostra o passo a passo. No iOS a instalação é sempre manual.'
                      : 'Se aparecer, confirmamos a instalação de imediato; caso contrário, mostramos o guia do Chrome (⋮).',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
                ),
                dense: true,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _installing
                    ? null
                    : () async {
                        if (pwaIsLikelyIOS) {
                          await pwaShowIosInstallSteps(context);
                        } else {
                          await _onInstallTap();
                        }
                      },
                icon: _installing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        pwaIsLikelyIOS ? Icons.list_alt : Icons.get_app,
                        size: 20,
                      ),
                label: Text(
                  pwaIsLikelyIOS
                      ? 'Abrir guia: instalar como app (iOS)'
                      : _installing
                          ? 'A processar…'
                          : 'Instalar aplicação',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                browserNotifGranted ? Icons.notifications_active : Icons.notifications_outlined,
                color: browserNotifGranted ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                size: 28,
              ),
              title: Text(
                browserNotifGranted ? 'Notificações permitidas no browser' : 'Ativar notificações push',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                browserNotifGranted
                    ? 'Pode tocar de novo para voltar a registar o dispositivo no negócio.'
                    : 'Agendamentos, cancelamentos, estoque, etc. (conta de dono).',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
              ),
              dense: true,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingNotif ? null : () => _onNotifTap(slug),
              icon: _loadingNotif
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      browserNotifGranted ? Icons.refresh : Icons.notifications_active_outlined,
                      size: 20,
                    ),
              label: Text(
                _loadingNotif
                    ? 'A ativar…'
                    : browserNotifGranted
                        ? 'Voltar a registar notificações'
                        : 'Ativar notificações',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
