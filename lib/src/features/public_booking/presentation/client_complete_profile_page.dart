import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../core/models/client.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';

final _whatsappMask = MaskTextInputFormatter(
  mask: '(##) #####-####',
  filter: {'#': RegExp(r'[0-9]')},
);
final _dobMask = MaskTextInputFormatter(
  mask: '##/##/####',
  filter: {'#': RegExp(r'[0-9]')},
);
final _cpfMask = MaskTextInputFormatter(
  mask: '###.###.###-##',
  filter: {'#': RegExp(r'[0-9]')},
);

final _referredByMaskComplete = MaskTextInputFormatter(
  mask: '(##) #####-####',
  filter: {'#': RegExp(r'[0-9]')},
);

/// Completar cadastro após login/cadastro com Google.
class ClientCompleteProfilePage extends ConsumerStatefulWidget {
  const ClientCompleteProfilePage({
    super.key,
    required this.slug,
    required this.googleName,
    required this.googleEmail,
    required this.googleUid,
    this.googlePhotoUrl,
    this.authMethod = 'google',
    /// Vindo do link ?ref= (WhatsApp) — pré-preenche indicação.
    this.referralRefParam,
  });

  final String slug;
  final String googleName;
  final String googleEmail;
  final String googleUid;
  final String? googlePhotoUrl;
  /// `google` apenas na prática — mantido para compatibilidade de rotas/antigos extras.
  final String authMethod;
  final String? referralRefParam;

  @override
  ConsumerState<ClientCompleteProfilePage> createState() => _ClientCompleteProfilePageState();
}

class _ClientCompleteProfilePageState extends ConsumerState<ClientCompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _referredByController = TextEditingController();

  bool _lgpdConsent = false;
  bool _loading = false;
  String _preferredLoyaltyCardStyle = 'masculine';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.googleName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ref = widget.referralRefParam;
      if (ref != null && ref.isNotEmpty) {
        final digits = ref.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length >= 10) {
          final formatted = _referredByMaskComplete.formatEditUpdate(
            TextEditingValue(),
            TextEditingValue(text: digits.length > 11 ? digits.substring(0, 11) : digits),
          ).text;
          _referredByController.text = formatted;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _referredByController.dispose();
    super.dispose();
  }

  String _normalizePhone(String text) => text.replaceAll(RegExp(r'[^\d]'), '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_lgpdConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário aceitar a Política de Privacidade (LGPD).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();
    final phone = _normalizePhone(_phoneController.text);
    final cpf = _normalizePhone(_cpfController.text);
    final referredByDigits = _normalizePhone(_referredByController.text);
    final referredByWhatsapp = referredByDigits.length >= 10 ? referredByDigits : null;

    if (phone.length < 10 || phone.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um telefone/WhatsApp válido.')),
      );
      return;
    }
    // CPF é opcional para cliente (cadastro de CPF é do dono do negócio)
    if (cpf.isNotEmpty && cpf.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se informar CPF, use 11 dígitos.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final clientRef = firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('clients')
          .doc(widget.googleUid);

      final clientData = {
        'name': name,
        'whatsapp': phone,
        'dateOfBirth': dob,
        'email': widget.googleEmail,
        if (cpf.length == 11) 'cpf': cpf,
        'authUid': widget.googleUid,
        if (widget.googlePhotoUrl != null) 'photoUrl': widget.googlePhotoUrl,
        'lgpdConsentAt': FieldValue.serverTimestamp(),
        'preferredLoyaltyCardStyle': _preferredLoyaltyCardStyle,
        'loyaltyPoints': 0,
        'totalAppointments': 0,
        if (referredByWhatsapp != null) 'referredByWhatsapp': referredByWhatsapp,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await clientRef.set(clientData);

      final shop = ref.read(barberShopBySlugProvider(widget.slug)).valueOrNull;
      final referralPoints = shop?.referralPoints ?? 30;
      if (referredByWhatsapp != null &&
          referredByWhatsapp != phone &&
          referredByWhatsapp.isNotEmpty &&
          referralPoints > 0) {
        final referrerSnap = await firestore
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('clients')
            .where('whatsapp', isEqualTo: referredByWhatsapp)
            .limit(1)
            .get();
        if (referrerSnap.docs.isNotEmpty) {
          await referrerSnap.docs.first.reference.update({
            'loyaltyPoints': FieldValue.increment(referralPoints),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final client = Client(
        id: widget.googleUid,
        name: name,
        whatsapp: phone,
        dateOfBirth: dob,
        email: widget.googleEmail,
        cpf: cpf.length == 11 ? cpf : null,
        authUid: widget.googleUid,
        photoUrl: widget.googlePhotoUrl,
        lgpdConsentAt: DateTime.now(),
        preferredLoyaltyCardStyle: _preferredLoyaltyCardStyle,
        loyaltyPoints: 0,
        totalAppointments: 0,
        referredByWhatsapp: referredByWhatsapp,
      );

      if (mounted) {
        ref.read(currentPublicClientProvider.notifier).state = (slug: widget.slug, client: client);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil completado! Acesso salvo.'),
            backgroundColor: Colors.green,
          ),
        );
        if (kIsWeb && PWAInstall().installPromptEnabled) {
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Salvar como app'),
              content: const Text(
                'Deseja salvar esta página como app no seu celular ou computador?',
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
        context.go('/b/${widget.slug}/perfil');
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
            appBar: AppBar(title: const Text('Completar perfil')),
            body: const Center(child: Text('Estabelecimento não encontrado.')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            title: const Text('Completar perfil'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/b/${widget.slug}/agendar'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Complete seus dados para ${shop.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Informe nome, nascimento e contato para concluir seu cadastro.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F6F8),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.googleEmail,
                      decoration: InputDecoration(
                        labelText: 'E-mail (Google)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Data de nascimento',
                        hintText: 'dd/MM/aaaa',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F6F8),
                      ),
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [_dobMask],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe a data de nascimento';
                        if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v)) return 'Use dd/MM/aaaa';
                        return null;
                      },
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp / Contato',
                        hintText: '(00) 00000-0000',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F6F8),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_whatsappMask],
                      validator: (v) {
                        final d = _normalizePhone(v ?? '');
                        if (d.length < 10 || d.length > 11) return 'Informe um telefone válido';
                        return null;
                      },
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cpfController,
                      decoration: const InputDecoration(
                        labelText: 'CPF (opcional)',
                        hintText: '000.000.000-00',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F6F8),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cpfMask],
                      validator: (v) {
                        final d = _normalizePhone(v ?? '');
                        if (d.isNotEmpty && d.length != 11) return 'Se informar, use 11 dígitos';
                        return null;
                      },
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referredByController,
                      decoration: const InputDecoration(
                        labelText: 'Foi indicado? Quem te indicou? (WhatsApp — opcional)',
                        hintText: '(00) 00000-0000',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F6F8),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_whatsappMask],
                      validator: (v) {
                        final d = _normalizePhone(v ?? '');
                        if (d.isNotEmpty && (d.length < 10 || d.length > 11)) {
                          return 'Se informar, use um WhatsApp válido';
                        }
                        return null;
                      },
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estilo do seu cartão fidelidade',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'masculine', label: Text('Masculino')),
                        ButtonSegment(value: 'feminine', label: Text('Feminino')),
                      ],
                      selected: {_preferredLoyaltyCardStyle},
                      onSelectionChanged: _loading ? null : (s) => setState(() => _preferredLoyaltyCardStyle = s.first),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _lgpdConsent,
                          onChanged: _loading ? null : (v) => setState(() => _lgpdConsent = v ?? false),
                          activeColor: primary,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _lgpdConsent = !_lgpdConsent),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Li e aceito a Política de Privacidade. Autorizo o uso dos meus dados (nome, contato, e-mail, data de nascimento) para agendamentos e fidelidade, em conformidade com a LGPD.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF5C636A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
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
                          : const Text('Salvar e continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Completar perfil')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Completar perfil')),
        body: Center(child: Text('Erro: $e')),
      ),
    );
  }
}
