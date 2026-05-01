import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'API key do Firebase inválida. Execute: dart run flutterfire configure';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'E-mail ou senha inválidos.';
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
        _isLoading = false;
      });
    } on Exception catch (e) {
      setState(() {
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '').split('\n').first;
        if (_errorMessage!.isEmpty) _errorMessage = 'E-mail ou senha inválidos.';
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
          String msg = 'Não foi possível entrar com o Google.';
          if (e.code == 'operation-not-allowed') {
            msg = 'Login com Google não está ativo. No Firebase: Authentication → Sign-in method → Google.';
          } else if (e.code == 'account-exists-with-different-credential') {
            msg = 'Este e-mail já está cadastrado com outro método. Use e-mail e senha.';
          } else if (e.message != null && e.message!.isNotEmpty) {
            msg = e.message!;
          }
          setState(() => _errorMessage = msg);
        }
      }
    } catch (e) {
      if (mounted) {
        var msg = e.toString().replaceFirst('Exception: ', '').split('\n').first;
        if (msg.isEmpty) msg = 'Erro ao entrar com o Google.';
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu e-mail para redefinir a senha.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.sendPasswordResetEmail(email: trimmed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail enviado! Verifique sua caixa de entrada para redefinir a senha.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Não foi possível enviar o e-mail. Tente novamente.';
        if (e.code == 'user-not-found') msg = 'Nenhuma conta encontrada com este e-mail.';
        if (e.code == 'invalid-email') msg = 'E-mail inválido.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        onSend: _sendPasswordReset,
      ),
    );
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
                const SizedBox(height: 20),
                Center(
                  child: Semantics(
                    label: 'Studio 10',
                    child: Container(
                      width: 280,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC9A227).withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/login_brand_logo.png',
                          width: 280,
                          height: 150,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) => const ColoredBox(
                            color: Color(0xFF1E1E1E),
                            child: Center(
                              child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Acesse o painel de gestão',
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
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      color: theme.colorScheme.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        TextField(
                          controller: _emailController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: fieldDecoration.copyWith(
                            labelText: 'E-mail',
                            hintText: 'seu@email.com',
                            fillColor: fieldFill,
                            filled: true,
                            prefixIcon: Icon(Icons.email_outlined, color: purple600.withValues(alpha: 0.95)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: fieldDecoration.copyWith(
                            labelText: 'Senha',
                            hintText: '••••••',
                            fillColor: fieldFill,
                            filled: true,
                            prefixIcon: Icon(Icons.lock_outline, color: purple600.withValues(alpha: 0.95)),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signInWithEmail(),
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: _isLoading ? null : _showForgotPasswordDialog,
                            child: Text(
                              'Esqueci minha senha',
                              style: GoogleFonts.poppins(
                                color: purple600,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _isLoading ? null : _signInWithEmail,
                          style: FilledButton.styleFrom(
                            backgroundColor: purple600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Entrar',
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
                            'Continuar com Google',
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
                    onPressed: () => context.go('/register'),
                    child: Text(
                      'Ainda não tem conta? Cadastre-se',
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

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSend,
  });

  final String initialEmail;
  final void Function(String email) onSend;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop();
    widget.onSend(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Esqueci minha senha',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informe o e-mail da sua conta. Enviaremos um link para você redefinir a senha.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF5C636A),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'seu@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.poppins(color: const Color(0xFF5C636A)),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9333EA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Enviar link',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
