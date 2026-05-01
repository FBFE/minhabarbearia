import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwa_install/pwa_install.dart';

import 'src/core/url_strategy.dart';
import 'src/config/app_router.dart';
import 'firebase_options.dart';
import 'src/core/providers/theme_providers.dart';
import 'src/features/pwa_install/presentation/pwa_install_events.dart';
import 'src/features/pwa_install/presentation/pwa_install_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();

  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  PWAInstall().setup(installCallback: () {
    PwaInstallEvents.instance.notifyAppInstalled();
    debugPrint('PWA instalado com sucesso!');
  });

  if (kIsWeb) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM (foreground): ${message.notification?.title}');
    });
  }

  runApp(
    const ProviderScope(
      child: MinhaBarbeariaApp(),
    ),
  );
}

class MinhaBarbeariaApp extends ConsumerWidget {
  const MinhaBarbeariaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(dynamicThemeProvider);

    return MaterialApp.router(
      title: 'Studio 10',
      theme: theme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => PwaInstallOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
