import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUpWithGoogle() async {
    if (!kIsWeb) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = ref.read(firebaseAuthProvider);
      final cred = await auth.signInWithPopup(GoogleAuthProvider());
      if (cred.user != null && mounted) {
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
          String msg = 'Não foi possível criar a conta com o Google.';
          if (e.code == 'operation-not-allowed') {
            msg = 'Google não está habilitado. No Firebase: Authentication → Sign-in method → Google.';
          } else if (e.code == 'account-exists-with-different-credential') {
            msg = 'Este e-mail já existe com outro provedor no Firebase.';
          } else if (e.code == 'unauthorized-domain') {
            msg = 'Domínio não autorizado. No Firebase: Authentication → Authorized domains.';
          } else if (e.message != null && e.message!.isNotEmpty) {
            msg = e.message!;
          }
          setState(() => _errorMessage = msg);
        }
      }
    } catch (e, stack) {
      debugPrint('Google register Exception: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        var raw = e.toString().replaceFirst('Exception: ', '').split('\n').first.trim();
        if (raw.isEmpty || raw == 'Error') raw = 'Erro ao criar conta com o Google.';
        setState(() => _errorMessage = raw);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const purple600 = Color(0xFF9333EA);
    const bg = Color(0xFF121212);
    const cardBg = Color(0xFF1E1E1E);
    const border = Color(0xFF2C2C2C);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add_rounded, size: 40, color: Color(0xFF121212)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Criar conta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWeb ? 'Somente conta Google para acessar o painel.' : 'Use o painel pela versão web no navegador.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 28),
                Material(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: theme.colorScheme.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        OutlinedButton.icon(
                          onPressed: _isLoading || !kIsWeb ? null : _signUpWithGoogle,
                          icon: Icon(Icons.g_mobiledata_rounded, size: 28, color: purple600),
                          label: Text(
                            _isLoading ? 'Aguarde…' : 'Cadastrar com Google',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: border),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Já tenho conta · Entrar',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFB74D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
