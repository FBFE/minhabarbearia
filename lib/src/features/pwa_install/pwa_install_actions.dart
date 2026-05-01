import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pwa_install/pwa_install.dart';

import 'pwa_web_info.dart';

/// Tenta o diálogo nativo de instalação (Android Chrome, Edge, etc.). Retorna [true] se o prompt existiu.
Future<bool> pwaTryNativeInstallPrompt() async {
  if (!kIsWeb) {
    return false;
  }
  try {
    if (PWAInstall().installPromptEnabled) {
      PWAInstall().promptInstall_();
      return true;
    }
  } catch (_) {
    // Sem beforeinstallprompt
  }
  return false;
}

Future<void> pwaShowAndroidInstallGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Instalar no Android',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '1. Toque no menu ⋮ (três pontos) no canto do Chrome, normalmente no canto superior direito.\n\n'
                '2. Toque em Instalar aplicação ou Adicionar à tela inicial.\n\n'
                '3. Confirme. O ícone do app passa a aparecer no ecrã ou na gaveta de aplicações.',
                style: GoogleFonts.poppins(fontSize: 15, height: 1.45),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Passo a passo iOS (Safari) — não dá para instalar por programação.
Future<void> pwaShowIosInstallSteps(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Instalar no iPhone / iPad', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            '1. Abra o site no Safari (não use o Chrome de dentro do Instagram/Facebook: use Abrir no Safari se aparecer).\n\n'
            '2. Toque no botão Partilhar (quadrado com a seta para cima) na barra de baixo do Safari.\n\n'
            '3. Desça a lista e toque em «Adicionar à Tela de Início».\n\n'
            '4. Edite o nome se quiser e toque em Adicionar no canto superior direito.\n\n'
            '5. O ícone passa a estar na tela inicial como uma app. Abra a partir dali para receber notificações (iOS 16.4+).',
            style: GoogleFonts.poppins(fontSize: 15, height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      );
    },
  );
}

/// Um único sítio para abrir a ajuda correta (ou nativo) para o [context].
Future<void> pwaRunInstallFlowForContext(BuildContext context) async {
  if (!kIsWeb) {
    return;
  }
  if (pwaIsStandalonePwa) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A app já está instalada. Use o ícone na tela inicial.'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return;
  }
  final usedNative = await pwaTryNativeInstallPrompt();
  if (usedNative) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (pwaIsLikelyIOS) {
    await pwaShowIosInstallSteps(context);
  } else if (pwaIsAndroidPhone) {
    await pwaShowAndroidInstallGuide(context);
  } else {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instalar aplicação'),
        content: const Text(
          'No teu computador, usa o menu do browser (canto do endereço) em «Instalar» ou «Instalar app», '
          'ou no mobile segue o guia consoante Android ou iPhone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }
}
