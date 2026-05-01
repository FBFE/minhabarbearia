import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notificador para o GoRouter reagir a mudanças de auth.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    _subscription =
        FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  StreamSubscription<User?>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
