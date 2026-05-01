import 'package:flutter/foundation.dart';

/// Sinal vindo do [beforeinstallprompt] + instalação concluída (index.html / pwa_install).
class PwaInstallEvents extends ChangeNotifier {
  PwaInstallEvents._();
  static final PwaInstallEvents instance = PwaInstallEvents._();

  int _installedTick = 0;
  int get installedTick => _installedTick;

  void notifyAppInstalled() {
    _installedTick++;
    notifyListeners();
  }
}
