// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwa_install/pwa_install.dart';

import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/fcm_provider.dart';
import '../pwa_install_actions.dart';
import '../pwa_web_info.dart';
import 'pwa_install_events.dart';

/// Preferências PWA (migradas de `mb_pwa_v1`).
class _PwaPrefs {
  _PwaPrefs({
    this.ownerInstallDismissed = false,
    this.ownerNotifDismissed = false,
    this.clientNotifDismissed = false,
  });

  final bool ownerInstallDismissed;
  final bool ownerNotifDismissed;
  final bool clientNotifDismissed;

  static const _kKey = 'mb_pwa_v2';

  static _PwaPrefs load() {
    if (!kIsWeb) {
      return _PwaPrefs();
    }
    try {
      var raw = html.window.localStorage[_kKey];
      if (raw == null || raw.isEmpty) {
        final legacy = html.window.localStorage['mb_pwa_v1'];
        if (legacy != null && legacy.isNotEmpty) {
          final m = jsonDecode(legacy) as Map<String, dynamic>?;
          if (m != null) {
            return _PwaPrefs(
              ownerInstallDismissed: m['installNudgeDone'] == true,
              ownerNotifDismissed: m['notifNudgeDone'] == true,
              clientNotifDismissed: m['notifNudgeDone'] == true,
            );
          }
        }
        return _PwaPrefs();
      }
      final m = jsonDecode(raw) as Map<String, dynamic>?;
      if (m == null) {
        return _PwaPrefs();
      }
      return _PwaPrefs(
        ownerInstallDismissed: m['ownerInstallDismissed'] == true,
        ownerNotifDismissed: m['ownerNotifDismissed'] == true,
        clientNotifDismissed: m['clientNotifDismissed'] == true,
      );
    } catch (_) {
      return _PwaPrefs();
    }
  }

  void save() {
    if (!kIsWeb) {
      return;
    }
    html.window.localStorage[_kKey] = jsonEncode({
      'ownerInstallDismissed': ownerInstallDismissed,
      'ownerNotifDismissed': ownerNotifDismissed,
      'clientNotifDismissed': clientNotifDismissed,
    });
  }

  _PwaPrefs copyWith({
    bool? ownerInstallDismissed,
    bool? ownerNotifDismissed,
    bool? clientNotifDismissed,
  }) {
    return _PwaPrefs(
      ownerInstallDismissed: ownerInstallDismissed ?? this.ownerInstallDismissed,
      ownerNotifDismissed: ownerNotifDismissed ?? this.ownerNotifDismissed,
      clientNotifDismissed: clientNotifDismissed ?? this.clientNotifDismissed,
    );
  }
}

/// Overlay global: **área cliente** (só convite a notificações); **resto** (dono, staff, login) instalação + notificações.
class PwaInstallOverlay extends ConsumerStatefulWidget {
  const PwaInstallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PwaInstallOverlay> createState() => _PwaInstallOverlayState();
}

class _PwaInstallOverlayState extends ConsumerState<PwaInstallOverlay> {
  _PwaPrefs _prefs = _PwaPrefs.load();
  bool _userInteracted = false;
  bool _delayPassed = false;
  Timer? _timer;
  bool _showInstallCard = false;
  bool _showIosSheet = false;
  bool _showAndroidSheet = false;
  bool _showNotifCard = false;
  bool _showClientNotifOnly = false;
  bool _notifLoading = false;

  bool get _bookingClient => pwaPathIsBookingClientArea;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      return;
    }
    PwaInstallEvents.instance.addListener(_onInstalledFromJs);
    final mobile = pwaIsLikelyIOS || pwaIsAndroidPhone;
    final delay = mobile ? const Duration(milliseconds: 600) : const Duration(seconds: 2);
    _timer = Timer(delay, () {
      if (mounted) {
        setState(() => _delayPassed = true);
        _scheduleUi();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleUi());
  }

  void _onInstalledFromJs() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showInstallCard = false;
      _showIosSheet = false;
      _showAndroidSheet = false;
    });
    if (!_bookingClient) {
      _maybeShowOwnerNotifAfterInstall();
    }
  }

  @override
  void dispose() {
    PwaInstallEvents.instance.removeListener(_onInstalledFromJs);
    _timer?.cancel();
    super.dispose();
  }

  void _onUserInteraction() {
    if (_userInteracted) {
      return;
    }
    _userInteracted = true;
    _scheduleUi();
  }

  void _scheduleUi() {
    if (!kIsWeb || !mounted) {
      return;
    }

    // Cliente do agendamento público: apenas lembrete de notificações (sem instalar PWA).
    if (_bookingClient) {
      if (_prefs.clientNotifDismissed || pwaWebNotificationsGranted) {
        return;
      }
      final showAfter = _delayPassed || _userInteracted;
      if (!showAfter) {
        return;
      }
      setState(() {
        _showClientNotifOnly = true;
        _showNotifCard = true;
      });
      return;
    }

    // Dono / staff / login / dashboard: instalação + notificações
    if (pwaIsStandalonePwa) {
      _maybeShowOwnerNotif();
      return;
    }
    if (_prefs.ownerNotifDismissed) {
      return;
    }
    if (_prefs.ownerInstallDismissed) {
      _maybeShowOwnerNotif();
      return;
    }

    final canChromeInstall = PWAInstall().installPromptEnabled;
    final showAfter = _delayPassed || _userInteracted;
    if (!showAfter) {
      return;
    }

    if (pwaIsLikelyIOS) {
      setState(() => _showIosSheet = true);
      return;
    }
    if (pwaIsAndroidPhone) {
      if (canChromeInstall) {
        setState(() => _showInstallCard = true);
      } else {
        setState(() => _showAndroidSheet = true);
      }
      return;
    }
    setState(() => _showInstallCard = true);
  }

  void _maybeShowOwnerNotifAfterInstall() {
    if (!mounted || _prefs.ownerNotifDismissed) {
      return;
    }
    setState(() => _showNotifCard = true);
  }

  void _maybeShowOwnerNotif() {
    if (!mounted || _prefs.ownerNotifDismissed) {
      return;
    }
    setState(() {
      _showClientNotifOnly = false;
      _showNotifCard = true;
    });
  }

  void _dismissInstall() {
    setState(() {
      _showInstallCard = false;
      _showIosSheet = false;
      _showAndroidSheet = false;
    });
    _prefs = _prefs.copyWith(ownerInstallDismissed: true);
    _prefs.save();
    _maybeShowOwnerNotif();
  }

  Future<void> _onPrimaryInstallPressed() async {
    if (pwaIsLikelyIOS) {
      if (!mounted) {
        return;
      }
      await pwaShowIosInstallSteps(context);
      return;
    }
    final ok = await pwaTryNativeInstallPrompt();
    if (!mounted) {
      return;
    }
    if (ok) {
      return;
    }
    if (pwaIsAndroidPhone) {
      if (!mounted) {
        return;
      }
      await pwaShowAndroidInstallGuide(context);
    } else {
      if (!mounted) {
        return;
      }
      await pwaRunInstallFlowForContext(context);
    }
  }

  Future<void> _onEnableNotifications() async {
    if (_notifLoading) {
      return;
    }
    setState(() => _notifLoading = true);
    final client = ref.read(currentPublicClientProvider);
    try {
      final r = await requestAndRegisterWebNotifications(
        clientSlug: client?.slug,
        clientId: client?.client.id,
      );
      if (!mounted) {
        return;
      }
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão negada ou indisponível. Ative nas definições do browser, se precisar.'),
          ),
        );
        setState(() => _notifLoading = false);
        return;
      } else {
        final parts = <String>[];
        if (r.ownerShopsUpdated > 0) {
          parts.add(
            r.ownerShopsUpdated == 1
                ? 'Notificações ligadas ao seu negócio.'
                : 'Notificações ligadas em ${r.ownerShopsUpdated} negócios.',
          );
        } else if (r.clientSaved) {
          parts.add('Notificações ligadas à sua conta.');
        } else {
          parts.add('Notificações ativadas.');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parts.join(' ')),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
      if (_bookingClient) {
        _prefs = _prefs.copyWith(clientNotifDismissed: true);
      } else {
        _prefs = _prefs.copyWith(ownerNotifDismissed: true);
      }
      _prefs.save();
      setState(() {
        _showNotifCard = false;
        _notifLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _notifLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _dismissNotifNudge() {
    if (_bookingClient) {
      _prefs = _prefs.copyWith(clientNotifDismissed: true);
    } else {
      _prefs = _prefs.copyWith(ownerNotifDismissed: true);
    }
    _prefs.save();
    setState(() => _showNotifCard = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return widget.child;
    }
    return Listener(
      onPointerDown: (_) => _onUserInteraction(),
      child: Stack(
        children: [
          widget.child,
          if (_showIosSheet) _buildIosSheet(),
          if (_showAndroidSheet) _buildAndroidSheet(),
          if (_showInstallCard && !_showIosSheet && !_showAndroidSheet) _buildInstallBanner(),
          if (_showNotifCard) _buildNotifCard(),
        ],
      ),
    );
  }

  Widget _buildAndroidSheet() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 20,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Instalar no Android',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque em Instalar abaixo se o Chrome oferecer; senão use o menu ⋮ → Instalar app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await _onPrimaryInstallPressed();
                  if (!mounted) {
                    return;
                  }
                  if (pwaIsStandalonePwa) {
                    _dismissInstall();
                  }
                },
                child: const Text('Tentar instalar agora'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await pwaShowAndroidInstallGuide(context);
                },
                child: const Text('Ver passo a passo'),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismissInstall,
                    child: const Text('Agora não'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosSheet() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 20,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'App no iPhone / iPad',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'No iOS a instalação é sempre em duas etapas no Safari. Abra o guia completo ou ignore por agora.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await pwaShowIosInstallSteps(context);
                },
                child: const Text('Ver passo a passo (Safari)'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismissInstall,
                    child: const Text('Agora não'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallBanner() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.get_app,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Instalar aplicação',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _dismissInstall,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Um toque instala quando o browser permitir; caso contrário mostramos o guia do Chrome.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await _onPrimaryInstallPressed();
                  if (!mounted) {
                    return;
                  }
                  if (pwaIsStandalonePwa) {
                    _dismissInstall();
                  }
                },
                icon: const Icon(Icons.download, size: 20),
                label: const Text('Instalar agora'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _dismissInstall,
                  child: const Text('Agora não'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifCard() {
    final isClient = _showClientNotifOnly;
    final bottomInset = _showInstallCard || _showIosSheet || _showAndroidSheet ? 220.0 : 24.0;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isClient ? 'Ativar lembretes?' : 'Ativar notificações?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isClient
                    ? 'Receba lembretes dos seus agendamentos neste negócio.'
                    : 'Novos agendamentos, alterações, cancelamentos e alertas de estoque (conta dono).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _notifLoading ? null : _onEnableNotifications,
                  child: _notifLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ativar'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _notifLoading ? null : _dismissNotifNudge,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  child: const Text('Agora não'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
