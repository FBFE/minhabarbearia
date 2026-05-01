import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/staff.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';

/// Acesso do cliente: primeiro escolhe Google ou e-mail; no e-mail pode entrar ou criar conta e ir para [ClientCompleteProfilePage].
class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  /// Primeiro passo: Google ou e-mail.
  bool _showChoiceStep = true;
  /// Passo e-mail: false = já tem conta, true = criar conta.
  bool _emailSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = auth.currentUser?.uid;
      if (uid == null || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final client = await ref.read(clientByAuthUidProvider((slug: widget.slug, authUid: uid)).future);
      if (!mounted) {
        setState(() => _loading = false);
        return;
      }
      if (client == null) {
        if (!mounted) {
          setState(() => _loading = false);
          return;
        }
        context.go(
          '/b/${widget.slug}/complete-profile',
          extra: {
            'name': auth.currentUser?.displayName ?? '',
            'email': _emailController.text.trim(),
            'uid': uid,
            'photoUrl': auth.currentUser?.photoURL,
            'authMethod': 'password',
          },
        );
        setState(() => _loading = false);
        return;
      }

      ref.read(currentPublicClientProvider.notifier).state = (slug: widget.slug, client: client);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acesso salvo. Login realizado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (mounted && kIsWeb && PWAInstall().installPromptEnabled) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Salvar como app'),
            content: const Text(
              'Deseja salvar esta página como app no seu celular ou computador? '
              'Você poderá abrir pelo ícone na área de trabalho ou na tela inicial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Agora não'),
              ),
              FilledButton.icon(
                onPressed: () {
                  PWAInstall().promptInstall_();
                  Navigator.of(ctx).pop(true);
                },
                icon: const Icon(Icons.get_app, size: 20),
                label: const Text('Salvar como app'),
              ),
            ],
          ),
        );
      }
      if (mounted) context.go('/b/${widget.slug}/perfil');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'E-mail ou senha incorretos.';
        if (e.code == 'user-not-found') msg = 'Nenhuma conta com este e-mail.';
        if (e.code == 'wrong-password') msg = 'Senha incorreta.';
        if (e.code == 'invalid-email') msg = 'E-mail inválido.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccountWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user?.uid;
      if (uid == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      context.go(
        '/b/${widget.slug}/complete-profile',
        extra: {
          'name': cred.user?.displayName ?? '',
          'email': email,
          'uid': uid,
          'photoUrl': cred.user?.photoURL,
          'authMethod': 'password',
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Não foi possível criar a conta.';
        if (e.code == 'email-already-in-use') {
          msg = 'Este e-mail já tem conta. Use "Já tenho conta" para entrar.';
        }
        if (e.code == 'weak-password') msg = 'Senha fraca. Use ao menos 6 caracteres.';
        if (e.code == 'invalid-email') msg = 'E-mail inválido.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      final provider = GoogleAuthProvider();
      final cred = await auth.signInWithPopup(provider);
      final user = cred.user;
      if (user == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      final uid = user.uid;
      final email = (user.email ?? '').trim().toLowerCase();
      // Se for funcionário, não mandar para "Completar perfil" de cliente
      final staffList = await ref.read(staffProvider(widget.slug).future);
      if (!mounted) {
        setState(() => _loading = false);
        return;
      }
      Staff? staff;
      for (final s in staffList) {
        if ((s.email).trim().toLowerCase() == email) {
          staff = s;
          break;
        }
      }
      if (staff != null) {
        ref.read(currentStaffProvider.notifier).state = (slug: widget.slug, staff: staff);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você entrou como funcionário. Veja os horários marcados com você.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/b/${widget.slug}/funcionario/agenda');
        }
        setState(() => _loading = false);
        return;
      }
      final client = await ref.read(clientByAuthUidProvider((slug: widget.slug, authUid: uid)).future);
      if (!mounted) {
        setState(() => _loading = false);
        return;
      }
      if (client != null) {
        ref.read(currentPublicClientProvider.notifier).state = (slug: widget.slug, client: client);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Acesso salvo. Login realizado!'), backgroundColor: Colors.green),
          );
        }
        if (mounted && kIsWeb && PWAInstall().installPromptEnabled) {
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Salvar como app'),
              content: const Text(
                'Deseja salvar esta página como app no seu celular ou computador?',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Agora não')),
                FilledButton.icon(
                  onPressed: () {
                    PWAInstall().promptInstall_();
                    Navigator.of(ctx).pop(true);
                  },
                  icon: const Icon(Icons.get_app, size: 20),
                  label: const Text('Salvar como app'),
                ),
              ],
            ),
          );
        }
        if (mounted) context.go('/b/${widget.slug}/perfil');
      } else {
        context.go(
          '/b/${widget.slug}/complete-profile',
          extra: {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'uid': uid,
            'photoUrl': user.photoURL,
            'authMethod': 'google',
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao entrar com Google: ${e.message ?? e.code}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barberShopAsync = ref.watch(barberShopBySlugProvider(widget.slug));
    final primary = Theme.of(context).colorScheme.primary;

    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Entrar')),
            body: const Center(child: Text('Estabelecimento não encontrado.')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            title: const Text('Entrar'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _loading
                  ? null
                  : () {
                      if (_showChoiceStep) {
                        context.go('/b/${widget.slug}/agendar');
                      } else {
                        setState(() => _showChoiceStep = true);
                      }
                    },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _showChoiceStep
                  ? _buildAuthChoiceContent(shop.name, primary)
                  : _buildEmailAuthContent(primary),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Entrar')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Entrar')),
        body: Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildAuthChoiceContent(String shopName, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Entrar em $shopName',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1D21),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Escolha como acessar. Depois você completa nome, WhatsApp e data de nascimento.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.4,
            color: const Color(0xFF5C636A),
          ),
        ),
        const SizedBox(height: 28),
        if (kIsWeb) ...[
          OutlinedButton.icon(
            onPressed: _loading ? null : _signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
            label: Text(
              'Continuar com Google',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: primary, width: 1.5),
              foregroundColor: const Color(0xFF1A1D21),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _loading ? null : () => setState(() => _showChoiceStep = false),
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.mail_outline_rounded, size: 22),
          label: Text(
            'Continuar com e-mail e senha',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => context.go('/b/${widget.slug}/cadastro'),
            child: Text(
              'Prefere um cadastro completo numa única página? Toque aqui',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailAuthContent(Color primary) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'E-mail e senha',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1D21),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emailSignUp
                ? 'Crie sua senha. Em seguida você informa os dados pessoais.'
                : 'Use a mesma conta se já se cadastrou. Se faltar algo no cadastro, pediremos na próxima etapa.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.35,
              color: const Color(0xFF5C636A),
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text('Já tenho conta', style: GoogleFonts.poppins(fontSize: 12)),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Criar conta', style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ],
            emptySelectionAllowed: false,
            selected: {_emailSignUp},
            onSelectionChanged: _loading
                ? null
                : (Set<bool> selection) {
                    setState(() {
                      _emailSignUp = selection.first;
                      _passwordConfirmController.clear();
                    });
                  },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'seu@email.com',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFF5F6F8),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o e-mail' : null,
            enabled: !_loading,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Senha',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: const Color(0xFFF5F6F8),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a senha';
              if (_emailSignUp && v.length < 6) return 'Mínimo de 6 caracteres';
              return null;
            },
            enabled: !_loading,
          ),
          if (_emailSignUp) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordConfirmController,
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: const Color(0xFFF5F6F8),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                ),
              ),
              obscureText: _obscurePasswordConfirm,
              validator: (v) {
                if (!_emailSignUp) return null;
                if (v == null || v.isEmpty) return 'Confirme a senha';
                if (v != _passwordController.text) return 'Senhas diferentes';
                return null;
              },
              enabled: !_loading,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading
                ? null
                : () {
                    if (_emailSignUp) {
                      _createAccountWithEmail();
                    } else {
                      _submit();
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _emailSignUp ? 'Criar conta e continuar' : 'Entrar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
