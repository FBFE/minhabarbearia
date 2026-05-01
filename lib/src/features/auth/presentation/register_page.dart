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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail não está habilitado. Ative em Authentication → Sign-in method no Firebase.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'unauthorized-domain':
        return 'Domínio não autorizado. No Firebase: Authentication → Settings → Authorized domains, adicione localhost e 127.0.0.1.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
        return 'API key do Firebase inválida. Execute: dart run flutterfire configure';
      default:
        if (e.code.contains('api-key') || e.code.contains('invalid')) {
          return 'API key do Firebase inválida. Execute: dart run flutterfire configure';
        }
        final msg = e.message;
        if (msg != null && msg.isNotEmpty) {
          return msg;
        }
        return 'Erro (${e.code}). Tente novamente.';
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'As senhas não coincidem.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: code=${e.code}, message=${e.message}');
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e);
        _isLoading = false;
      });
    } on Exception catch (e, stack) {
      debugPrint('Register Exception: $e');
      debugPrint('Stack: $stack');
      setState(() {
        final raw = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = raw.split('\n').first.trim();
        if (_errorMessage!.isEmpty || _errorMessage == 'Error') {
          _errorMessage = 'Erro ao criar conta. Tente novamente.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
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
          setState(() => _errorMessage = _getFirebaseErrorMessage(e));
        }
      }
    } on Exception catch (e, stack) {
      debugPrint('Google register Exception: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() {
          final raw = e.toString().replaceFirst('Exception: ', '');
          _errorMessage = raw.split('\n').first.trim();
          if (_errorMessage!.isEmpty || _errorMessage == 'Error') {
            _errorMessage = 'Erro ao criar conta com o Google. Tente novamente.';
          }
        });
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
    const fieldFill = Color(0xFF2A2A2A);

    final fieldDecoration = InputDecoration(
      labelStyle: GoogleFonts.poppins(color: Colors.white60),
      hintStyle: GoogleFonts.poppins(color: Colors.white38),
      floatingLabelStyle: GoogleFonts.poppins(color: purple600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: purple600, width: 2),
      ),
    );

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
                  'Preencha os dados para se cadastrar',
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
                        TextField(
                          controller: _emailController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: fieldDecoration.copyWith(
                            labelText: 'E-mail',
                            fillColor: fieldFill,
                            filled: true,
                            prefixIcon: Icon(Icons.email_outlined, color: purple600.withValues(alpha: 0.95)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: fieldDecoration.copyWith(
                            labelText: 'Senha',
                            fillColor: fieldFill,
                            filled: true,
                            prefixIcon: Icon(Icons.lock_outline, color: purple600.withValues(alpha: 0.95)),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: fieldDecoration.copyWith(
                            labelText: 'Confirmar senha',
                            fillColor: fieldFill,
                            filled: true,
                            prefixIcon: Icon(Icons.lock_outline, color: purple600.withValues(alpha: 0.95)),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _register(),
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _register,
                          style: FilledButton.styleFrom(
                            backgroundColor: purple600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Cadastrar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ou',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: border)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _isLoading || !kIsWeb ? null : _signInWithGoogle,
                          icon: Icon(Icons.g_mobiledata_rounded, size: 28, color: purple600),
                          label: Text(
                            'Cadastrar com Google',
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
                      'Já tem conta? Entrar',
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
