import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/barber_shop.dart';
import '../../../core/models/client.dart';
import '../../../core/models/service.dart';
import '../../../core/models/staff.dart';
import '../../../core/models/voucher.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/fcm_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/theme_providers.dart';
import 'package:minhabarbearia/src/core/utils/slot_utils.dart';

import 'public_shop_hero_header.dart';
import '../../../core/widgets/service_storage_image.dart';

/// Máscara WhatsApp: (00) 00000-0000 ou (00) 0000-0000
final _whatsappMask = MaskTextInputFormatter(
  mask: '(##) #####-####',
  filter: {'#': RegExp(r'[0-9]')},
);

/// Máscara Data de Nascimento: dd/MM/yyyy
final _dobMask = MaskTextInputFormatter(
  mask: '##/##/####',
  filter: {'#': RegExp(r'[0-9]')},
);

/// Retorna true se [dob] (dd/MM/yyyy) é do mês de aniversário (mês atual).
bool _isBirthMonth(String? dob) {
  if (dob == null || dob.length < 10) return false;
  final parts = dob.split('/');
  if (parts.length != 3) return false;
  final month = int.tryParse(parts[1]);
  return month != null && month == DateTime.now().month;
}

/// Aplica 10% de desconto no mês de aniversário do cliente.
double _priceWithBirthdayDiscount(double total, String? dob) {
  if (!_isBirthMonth(dob)) return total;
  return total * 0.9;
}

class PublicBookingPage extends ConsumerStatefulWidget {
  final String slug;
  final String? refParam;

  const PublicBookingPage({super.key, required this.slug, this.refParam});

  @override
  ConsumerState<PublicBookingPage> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends ConsumerState<PublicBookingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentSlugProvider.notifier).state = widget.slug;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentSlugProvider.notifier).state = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barberShopAsync = ref.watch(barberShopBySlugProvider(widget.slug));

    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) return const _NotFoundView();
        return Theme(
          data: _themeFromBarberShop(context, shop),
          child: _BookingScaffold(
            barberShop: shop,
            refParam: widget.refParam,
          ),
        );
      },
      loading: () => const _LoadingView(),
      error: (error, _) => _ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(barberShopBySlugProvider(widget.slug)),
      ),
    );
  }

  ThemeData _themeFromBarberShop(BuildContext context, BarberShop shop) {
    final base = Theme.of(context);
    final primary = shop.primaryColorAsColor;
    final secondary = shop.secondaryColorAsColor;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}

class _BookingScaffold extends ConsumerWidget {
  final BarberShop barberShop;
  final String? refParam;

  const _BookingScaffold({required this.barberShop, this.refParam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = barberShop.primaryColorAsColor;
    final slug = barberShop.slug;

    // Sem Scaffold: PublicShellPage já compõe o layout com bottom bar (evita overflow vertical).
    return SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(barberShopBySlugProvider(slug));
            ref.invalidate(servicesProvider(slug));
            ref.invalidate(staffProvider(slug));
            try {
              await ref.read(barberShopBySlugProvider(slug).future);
            } catch (_) {}
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: PublicShopHeroHeader(
                    shop: barberShop,
                    primary: primary,
                    overlayOnly: true,
                  ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Agendamento',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Escolha os serviços desejados',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF5C636A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Funcionamento: ${barberShop.scheduleSummaryLine}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF5C636A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 88),
                sliver: SliverToBoxAdapter(
                  child: _BookingForm(
                    barberShop: barberShop,
                    refParam: refParam,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Modo do fluxo de cliente: escolher | verificar | novo | confirmado
enum _ClientFlowMode { choose, verify, newClient, confirmed }

class _BookingForm extends ConsumerStatefulWidget {
  final BarberShop barberShop;
  final String? refParam;

  const _BookingForm({required this.barberShop, this.refParam});

  @override
  ConsumerState<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<_BookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _referredByController = TextEditingController();
  final _promoCodeController = TextEditingController();

  _ClientFlowMode _flowMode = _ClientFlowMode.choose;
  Client? _verifiedClient;
  bool _verifying = false;
  bool _submitting = false;
  bool _applyingPromo = false;

  Voucher? _appliedVoucher;

  final List<Service> _cart = []; // carrinho: múltiplos serviços no mesmo agendamento
  Staff? _selectedStaff;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  DateTime? _selectedSlot;

  DateTime? _dateOfBirth;
  bool _syncedClientData = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _referredByController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  String _normalizePhone(String text) =>
      text.replaceAll(RegExp(r'[^\d]'), '');

  String _formatPhoneForDisplay(String digits) {
    final d = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length == 11) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    }
    if (d.length == 10) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    }
    return digits;
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String? _validateWhatsApp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe o WhatsApp';
    final digits = _normalizePhone(value);
    if (digits.length < 10 || digits.length > 11) {
      return 'WhatsApp inválido (10 ou 11 dígitos)';
    }
    return null;
  }

  String? _validateDob(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe a data de nascimento';
    final parts = value.split('/');
    if (parts.length != 3) return 'Use o formato dd/MM/yyyy';
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return 'Data inválida';
    if (d < 1 || d > 31 || m < 1 || m > 12 || y < 1900 || y > DateTime.now().year) {
      return 'Data inválida';
    }
    return null;
  }

  Future<void> _verifyClient() async {
    final phone = _normalizePhone(_whatsappController.text);
    final dob = _dobController.text.trim();
    if (phone.length < 10 || phone.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um WhatsApp válido')),
      );
      return;
    }
    if (dob.length != 10 || !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de nascimento (dd/MM/yyyy)')),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final client = await ref.read(clientByPhoneAndDobProvider((
        slug: widget.barberShop.slug,
        phone: phone,
        dob: dob,
      )).future);

      if (mounted) {
        if (client != null) {
          ref.read(currentPublicClientProvider.notifier).state = (
            slug: widget.barberShop.slug,
            client: client,
          );
          setState(() {
            _verifiedClient = client;
            _flowMode = _ClientFlowMode.confirmed;
            _nameController.text = client.name;
            _whatsappController.text = _formatPhoneForDisplay(client.whatsapp);
            _dobController.text = client.dateOfBirth;
          });
        } else {
          setState(() => _flowMode = _ClientFlowMode.newClient);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cliente não encontrado. Preencha o cadastro completo.'),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao verificar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = _formatDob(picked);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstCalendarDay = DateTime(now.year, now.month, now.day);
    var initial = _date;
    if (initial.isBefore(firstCalendarDay)) initial = firstCalendarDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstCalendarDay,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return widget.barberShop.effectiveHoursForDate(d) != null;
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um serviço ao carrinho')),
      );
      return;
    }
    final slugCheck = widget.barberShop.slug;
    final catalog = ref.read(servicesProvider(slugCheck)).valueOrNull;
    if (catalog != null) {
      final byId = {for (final s in catalog) s.id: s};
      for (final c in _cart) {
        final cur = byId[c.id];
        if (cur == null || !cur.active) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Um ou mais serviços não estão mais disponíveis para agendamento. Atualize o carrinho.',
                ),
              ),
            );
          }
          return;
        }
      }
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um horário disponível')),
      );
      return;
    }
    final slot = _selectedSlot!;
    final slotDay = DateTime(slot.year, slot.month, slot.day);
    if (widget.barberShop.effectiveHoursForDate(slotDay) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este dia não está disponível para agendamento.')),
      );
      return;
    }
    if (slot.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um horário no futuro')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final whatsapp = _normalizePhone(_whatsappController.text);
    final currentForSubmit = ref.read(currentPublicClientProvider);
    final clientForSubmit = (currentForSubmit != null && currentForSubmit.slug == widget.barberShop.slug)
        ? currentForSubmit.client
        : _verifiedClient;
    final dob = clientForSubmit != null
        ? clientForSubmit.dateOfBirth
        : _dobController.text.trim();

    if (dob.isEmpty || !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de nascimento (dd/MM/yyyy)')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final slug = widget.barberShop.slug;
      String? clientId = clientForSubmit?.id;
      Client? newClientForNav;

      if (clientForSubmit != null) {
        // Cliente existente: atualizar totalAppointments
        final clientsRef = firestore
            .collection('barbershops')
            .doc(slug)
            .collection('clients')
            .doc(clientForSubmit.id);
        await clientsRef.update({
          'totalAppointments': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Novo cliente: criar documento
        final clientsRef = firestore
            .collection('barbershops')
            .doc(slug)
            .collection('clients')
            .doc();
        clientId = clientsRef.id;

        final referredByDigits = _normalizePhone(_referredByController.text);
        final referredByWhatsapp =
            referredByDigits.length >= 10 ? referredByDigits : null;

        final client = Client(
          id: clientId,
          name: name,
          whatsapp: whatsapp,
          dateOfBirth: dob,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          photoUrl: null,
          loyaltyPoints: 0,
          totalAppointments: 1,
          referredByWhatsapp: referredByWhatsapp,
          createdAt: null,
        );
        await clientsRef.set(client.toFirestore());
        newClientForNav = client;

        // Cadastrou via link de indicação (?ref=whatsapp): quem indicou ganha +30
        final refFromUrl = widget.refParam?.replaceAll(RegExp(r'[^\d]'), '');
        if (refFromUrl != null &&
            refFromUrl.length >= 10 &&
            refFromUrl != whatsapp) {
          final referrerSnap = await firestore
              .collection('barbershops')
              .doc(slug)
              .collection('clients')
              .where('whatsapp', isEqualTo: refFromUrl)
              .limit(1)
              .get();
          if (referrerSnap.docs.isNotEmpty) {
            final points = widget.barberShop.referralPoints;
            if (points > 0) {
              await referrerSnap.docs.first.reference.update({
                'loyaltyPoints': FieldValue.increment(points),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        // Se indicou alguém (campo "quem te indicou"), dar pontos ao indicador (configurável)
        if (referredByWhatsapp != null &&
            referredByWhatsapp != whatsapp &&
            referredByWhatsapp.isNotEmpty) {
          final referrerSnap = await firestore
              .collection('barbershops')
              .doc(slug)
              .collection('clients')
              .where('whatsapp', isEqualTo: referredByWhatsapp)
              .limit(1)
              .get();

          if (referrerSnap.docs.isNotEmpty) {
            final points = widget.barberShop.referralPoints;
            if (points > 0) {
              await referrerSnap.docs.first.reference.update({
                'loyaltyPoints': FieldValue.increment(points),
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      final totalOriginal = _cart.fold<double>(0, (s, sv) => s + sv.price);
      final totalAfterBirthday = _priceWithBirthdayDiscount(totalOriginal, dob);
      final finalPrice = _appliedVoucher != null
          ? _appliedVoucher!.priceWithDiscount(totalAfterBirthday)
          : totalAfterBirthday;
      final totalDuration = _cart.fold<int>(0, (s, sv) => s + sv.durationMinutes);
      final servicesData = _cart
          .map((s) => {
                'serviceId': s.id,
                'serviceName': s.name,
                'price': s.price,
                'durationMinutes': s.durationMinutes,
              })
          .toList();

      await firestore.collection('appointments').add({
        'barberShopId': slug,
        'clientId': clientId,
        'serviceId': _cart.first.id,
        'serviceName': _cart.map((s) => s.name).join(', '),
        'services': servicesData,
        'clientName': name,
        'clientWhatsapp': whatsapp,
        'dateTime': Timestamp.fromDate(_selectedSlot!),
        'originalDateTime': Timestamp.fromDate(_selectedSlot!),
        'durationMinutes': totalDuration,
        'status': 'pending',
        'reminderSent': false,
        'originalPrice': totalOriginal,
        'finalPrice': finalPrice,
        if (_isBirthMonth(dob)) 'birthdayDiscountApplied': true,
        if (_selectedStaff != null) 'staffId': _selectedStaff!.id,
        if (_selectedStaff != null) 'staffName': _selectedStaff!.name,
        if (_appliedVoucher != null) 'voucherCode': _appliedVoucher!.code,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kIsWeb && clientId != null && clientId.isNotEmpty) {
        try {
          await requestAndRegisterWebNotifications(clientSlug: slug, clientId: clientId);
        } catch (_) {}
      }

      if (_appliedVoucher != null) {
        await firestore
            .collection('barbershops')
            .doc(slug)
            .collection('vouchers')
            .doc(_appliedVoucher!.id)
            .update({
          'usedBy': FieldValue.arrayUnion([whatsapp]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        if (newClientForNav != null) {
          ref.read(currentPublicClientProvider.notifier).state = (
            slug: slug,
            client: newClientForNav,
          );
        }
        final referredByDigits = _normalizePhone(_referredByController.text);
        final refFromUrl = widget.refParam?.replaceAll(RegExp(r'[^\d]'), '');
        final pts = widget.barberShop.referralPoints;
        String msg = 'Agendamento enviado! O barbeiro confirmará via WhatsApp.';
        if (refFromUrl != null && refFromUrl.length >= 10 && pts > 0) {
          msg =
              'Obrigado! Seu amigo ganhou +$pts pontos por indicar você. Agendamento enviado!';
        } else if (referredByDigits.length >= 10 && pts > 0) {
          msg =
              'Agendamento enviado! Se o indicador existir, ele ganhou +$pts pontos. O barbeiro confirmará via WhatsApp.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _cart.clear();
          _selectedSlot = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o código promocional')),
      );
      return;
    }

    setState(() => _applyingPromo = true);
    try {
      ref.invalidate(voucherByCodeProvider((slug: widget.barberShop.slug, code: code)));
      final voucher = await ref.read(voucherByCodeProvider((
        slug: widget.barberShop.slug,
        code: code,
      )).future);

      if (!mounted) return;
      if (voucher == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código inválido ou expirado'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _appliedVoucher = null);
        return;
      }

      final whatsapp = _normalizePhone(_whatsappController.text);
      if (whatsapp.length >= 10 && voucher.usedBy.contains(whatsapp)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este código já foi utilizado por você'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _appliedVoucher = null);
        return;
      }

      setState(() => _appliedVoucher = voucher);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desconto aplicado: ${voucher.discountLabel}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao validar código: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _appliedVoucher = null);
      }
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  void _resetFlow() {
    ref.read(currentPublicClientProvider.notifier).state = null;
    setState(() {
      _flowMode = _ClientFlowMode.choose;
      _verifiedClient = null;
      _nameController.clear();
      _whatsappController.clear();
      _dobController.clear();
      _addressController.clear();
      _referredByController.clear();
      _promoCodeController.clear();
      _appliedVoucher = null;
      _dateOfBirth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.barberShop.primaryColorAsColor;
    final slug = widget.barberShop.slug;
    final currentPair = ref.watch(currentPublicClientProvider);
    final Client? effectiveClient = (currentPair != null && currentPair.slug == slug)
        ? currentPair.client
        : (_flowMode == _ClientFlowMode.confirmed ? _verifiedClient : null);
    // Sincroniza dados do cliente logado nos controllers (para o submit do agendamento)
    if (effectiveClient != null && !_syncedClientData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nameController.text = effectiveClient.name;
        _whatsappController.text = _formatPhoneForDisplay(effectiveClient.whatsapp);
        _dobController.text = effectiveClient.dateOfBirth;
        _addressController.text = effectiveClient.address ?? '';
        setState(() => _syncedClientData = true);
      });
    } else if (effectiveClient == null) {
      _syncedClientData = false;
    }
    final servicesAsync = ref.watch(servicesProvider(slug));
    ref.listen(servicesProvider(slug), (prev, next) {
      next.whenData((services) {
        final byId = {for (final s in services) s.id: s};
        final removedNames = <String>[];
        final had = _cart.length;
        _cart.removeWhere((c) {
          final cur = byId[c.id];
          if (cur == null || !cur.active) {
            removedNames.add(c.name);
            return true;
          }
          return false;
        });
        if (_cart.length != had && mounted) {
          setState(() {});
          if (removedNames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    removedNames.length == 1
                        ? '"${removedNames.first}" não está mais disponível para agendamento e foi removido do carrinho.'
                        : 'Alguns serviços deixaram de estar disponíveis e foram removidos do carrinho.',
                  ),
                ),
              );
            });
          }
        }
      });
    });
    final staffAsync = ref.watch(staffProvider(slug));
    final staffList = staffAsync.valueOrNull ?? [];
    final cartServiceIds = _cart.map((s) => s.id).toSet();
    final staffForService = _cart.isEmpty
        ? staffList
        : staffList.where((st) => cartServiceIds.every((sid) => st.performsService(sid))).toList();
    final defaultStaffId = (!widget.barberShop.singleAttendant && staffForService.isNotEmpty)
        ? staffForService.first.id
        : null;
    final totalCartDuration = _cart.fold<int>(0, (s, sv) => s + sv.durationMinutes);
    final totalCartPrice = _cart.fold<double>(0, (s, sv) => s + sv.price);
    final dobForDiscount = effectiveClient?.dateOfBirth ?? _dobController.text.trim();
    final totalAfterBirthday = _priceWithBirthdayDiscount(totalCartPrice, dobForDiscount);
    final staffIdForSlots = _selectedStaff?.id ?? defaultStaffId;
    final dayStart = DateTime(_date.year, _date.month, _date.day);
    final appointmentsAsync = ref.watch(
      appointmentsForDayProvider((slug: slug, date: dayStart, staffId: staffIdForSlots)),
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Quando não está logado: apenas Entrar e Cadastrar (link com ?ref= vai direto para cadastro)
          if (_flowMode == _ClientFlowMode.choose && effectiveClient == null) ...[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFFF5F6F8),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/b/${widget.barberShop.slug}/cadastro${widget.refParam != null ? '?ref=${Uri.encodeComponent(widget.refParam!)}' : ''}'),
                        icon: const Icon(Icons.app_registration_rounded, size: 22),
                        label: const Text('Cadastrar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/b/${widget.barberShop.slug}/login'),
                        icon: const Icon(Icons.login_rounded, size: 22),
                        label: const Text('Entrar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _flowMode = _ClientFlowMode.verify),
                child: Text(
                  'Já é cliente? Verifique com WhatsApp e data de nascimento',
                  style: GoogleFonts.poppins(fontSize: 13, color: primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GuestServicePortfolio(
              servicesAsync: servicesAsync,
              slug: slug,
            ),
          ],

          // 2. Verificação: WhatsApp + Data de Nascimento
          if (_flowMode == _ClientFlowMode.verify) ...[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFFF5F6F8),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Verifique seu cadastro',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '(65) 99995-0688',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [_whatsappMask],
              keyboardType: TextInputType.phone,
              validator: _validateWhatsApp,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dobController,
              decoration: InputDecoration(
                labelText: 'Data de Nascimento',
                hintText: 'dd/MM/yyyy',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDateOfBirth,
                ),
              ),
              inputFormatters: [_dobMask],
              keyboardType: TextInputType.datetime,
              validator: _validateDob,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _verifyClient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _verifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verificar cliente'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _resetFlow,
                  child: const Text('Voltar'),
                ),
              ],
            ),
                  ],
                ),
              ),
            ),
          ],

          // 3. Formulário completo (novo cliente ou após não encontrado)
          if (_flowMode == _ClientFlowMode.newClient ||
              effectiveClient != null) ...[
            if (effectiveClient != null) ...[
              _ClientCard(
                slug: slug,
                client: effectiveClient,
                primary: primary,
              ),
              const SizedBox(height: 16),
              _ReferralInviteCard(
                barberShop: widget.barberShop,
                clientWhatsapp: effectiveClient.whatsapp,
                primary: primary,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 12),
                _ClientEnableNotificationsButton(
                  slug: slug,
                  clientId: effectiveClient.id,
                  primary: primary,
                ),
              ],
              const SizedBox(height: 16),
            ],
            // Só mostra formulário de dados quando o cliente NÃO está logado (novo ou verificando)
            if (effectiveClient == null) ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  hintText: 'Seu nome',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                enabled: _flowMode != _ClientFlowMode.confirmed,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe seu nome';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp',
                  hintText: '(65) 99995-0688',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [_whatsappMask],
                keyboardType: TextInputType.phone,
                enabled: _flowMode != _ClientFlowMode.confirmed,
                validator: _validateWhatsApp,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: 'Data de Nascimento (obrigatório)',
                  hintText: 'dd/MM/yyyy',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _flowMode == _ClientFlowMode.confirmed ? null : _pickDateOfBirth,
                  ),
                ),
                inputFormatters: [_dobMask],
                keyboardType: TextInputType.datetime,
                enabled: _flowMode != _ClientFlowMode.confirmed,
                validator: _validateDob,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Endereço (opcional)',
                  hintText: 'Rua, número, bairro',
                  border: OutlineInputBorder(),
                ),
                enabled: _flowMode != _ClientFlowMode.confirmed && !_submitting,
              ),
              if (_flowMode == _ClientFlowMode.newClient) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referredByController,
                  decoration: const InputDecoration(
                    labelText: 'Quem te indicou? (WhatsApp da pessoa - opcional)',
                    hintText: '(65) 99995-0688',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [_whatsappMask],
                  keyboardType: TextInputType.phone,
                  enabled: !_submitting,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ],

          // 4. Serviço, data, horário (quando cliente definido ou já logado)
          if (_flowMode == _ClientFlowMode.newClient ||
              _flowMode == _ClientFlowMode.confirmed ||
              effectiveClient != null) ...[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFFF5F6F8),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Serviços',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 20),
                    servicesAsync.when(
                      data: (services) {
                        final active = services.where((s) => s.active).toList();
                        if (active.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              services.isEmpty
                                  ? 'Nenhum serviço cadastrado.'
                                  : 'Nenhum serviço disponível para agendamento no momento.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inclua um ou mais serviços no carrinho (pode repetir o mesmo). Depois escolha data e horário.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.35,
                                color: const Color(0xFF5C636A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...active.map((s) {
                              final inCartCount = _cart.where((c) => c.id == s.id).length;
                              String dur() {
                                final m = s.durationMinutes;
                                if (m >= 60) {
                                  final h = m ~/ 60;
                                  final r = m % 60;
                                  return r == 0 ? '${h}H' : '${h}H ${r}MIN';
                                }
                                return '$m MIN';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  elevation: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: inCartCount > 0 ? primary : const Color(0xFFE5E7EB),
                                        width: inCartCount > 0 ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        serviceSquareListImage(
                                          shopDocId: widget.barberShop.id,
                                          service: s,
                                          side: 84,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF1A1D21),
                                                ),
                                              ),
                                              if (s.description != null && s.description!.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  s.description!,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: const Color(0xFF5C636A),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF3F4F6),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.schedule, size: 16, color: primary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          dur(),
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: const Color(0xFF5C636A),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    s.priceFormatted,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF1A1D21),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (inCartCount > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Text(
                                                  '$inCartCount× carrinho',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: primary,
                                                  ),
                                                ),
                                              ),
                                            FilledButton.tonalIcon(
                                              onPressed: _submitting
                                                  ? null
                                                  : () => setState(() {
                                                        _cart.add(s);
                                                        _selectedSlot = null;
                                                        _selectedStaff = null;
                                                      }),
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                                              label: Text(
                                                'Adicionar',
                                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (_cart.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text('Carrinho', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF5C636A))),
                              const SizedBox(height: 8),
                              ..._cart.asMap().entries.map((e) {
                                final i = e.key;
                                final s = e.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${s.name} — ${s.priceFormatted} (${s.durationMinutes} min)', style: GoogleFonts.poppins(fontSize: 14)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                        onPressed: _submitting ? null : () => setState(() { _cart.removeAt(i); _selectedSlot = null; }),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(),
                              Text(
                                'Total: R\$ ${totalAfterBirthday.toStringAsFixed(2).replaceAll('.', ',')} • ${_cart.fold<int>(0, (s, sv) => s + sv.durationMinutes)} min${_isBirthMonth(dobForDiscount) ? ' (10% aniversário)' : ''}',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Erro ao carregar serviços: $e',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                    if (_cart.isNotEmpty) ...[
                    if (!widget.barberShop.singleAttendant) ...[
                      const SizedBox(height: 20),
                      staffAsync.when(
                        data: (staffList) {
                          final available = _cart.isEmpty
                              ? staffList
                              : staffList.where((st) => _cart.every((sv) => st.performsService(sv.id))).toList();
                          if (available.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Nenhum profissional disponível para este serviço.',
                                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5C636A)),
                              ),
                            );
                          }
                          final effective = (_selectedStaff != null && available.contains(_selectedStaff))
                              ? _selectedStaff!
                              : available.first;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && (_selectedStaff == null || !available.contains(_selectedStaff))) {
                              setState(() => _selectedStaff = available.first);
                            }
                          });
                          return DropdownButtonFormField<Staff>(
                            value: effective,
                            decoration: InputDecoration(
                              labelText: 'Profissional',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFEEF0F2),
                            ),
                            dropdownColor: Colors.white,
                            items: available
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        '${s.name}${s.serviceIds.isEmpty ? '' : ' (especialidades: ${s.serviceIds.length} serviço(s))'}',
                                        style: GoogleFonts.poppins(color: const Color(0xFF1A1D21)),
                                      ),
                                    ))
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() {
                                      _selectedStaff = v ?? available.first;
                                      _selectedSlot = null;
                                    }),
                          );
                        },
                        loading: () => const SizedBox(height: 48),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Data',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: const Color(0xFFEEF0F2),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _submitting ? null : _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: primary, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A1D21),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Horários disponíveis',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _cart.isEmpty
                        ? const SizedBox(height: 48)
                        : appointmentsAsync.when(
                            data: (appointments) {
                              final duration = totalCartDuration;
                              final dayHours = widget.barberShop.effectiveHoursForDate(dayStart);
                              if (dayHours == null) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Fechado neste dia.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              }
                              final (open, close) = dayHours;
                              final slots = freeSlots(
                                day: dayStart,
                                serviceDurationMinutes: duration,
                                appointments: appointments,
                                openTime: open,
                                closeTime: close,
                              );
                              if (slots.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Sem horários disponíveis neste dia.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: slots.map((slot) {
                                  final selected = _selectedSlot != null &&
                                      _selectedSlot!.hour == slot.hour &&
                                      _selectedSlot!.minute == slot.minute;
                                  return FilterChip(
                                    label: Text(
                                      '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    selected: selected,
                                    onSelected: _submitting
                                        ? null
                                        : (_) => setState(() => _selectedSlot = slot),
                                    backgroundColor: const Color(0xFFEEF0F2),
                                    selectedColor: primary.withValues(alpha: 0.25),
                                    checkmarkColor: primary,
                                    side: BorderSide(
                                      color: selected ? primary : const Color(0xFFDDE1E6),
                                      width: selected ? 2 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                height: 32,
                                width: 32,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: (e, _) => Text(
                              'Erro ao carregar horários: $e',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Text(
                      'Código promocional',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _promoCodeController,
                            decoration: InputDecoration(
                              hintText: 'Tem código de desconto?',
                              filled: true,
                              fillColor: const Color(0xFFEEF0F2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_submitting && !_applyingPromo,
                            onChanged: (_) => setState(() => _appliedVoucher = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _submitting || _applyingPromo ? null : _applyPromoCode,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primary),
                            foregroundColor: primary,
                          ),
                          child: _applyingPromo
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Aplicar'),
                        ),
                      ],
                    ),
                    if (_appliedVoucher != null) ...[
                      const SizedBox(height: 8),
                      Chip(
                        avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        label: Text(
                          '${_appliedVoucher!.description} (${_appliedVoucher!.discountLabel})',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onDeleted: () => setState(() => _appliedVoucher = null),
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                    if (_cart.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumo',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1D21),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _appliedVoucher != null
                                  ? 'Preço original: R\$ ${(totalAfterBirthday).toStringAsFixed(2).replaceAll('.', ',')} → Com desconto: R\$ ${_appliedVoucher!.priceWithDiscount(totalAfterBirthday).toStringAsFixed(2).replaceAll('.', ',')} (${_appliedVoucher!.discountLabel})'
                                  : _isBirthMonth(dobForDiscount)
                                      ? 'Preço: R\$ ${totalCartPrice.toStringAsFixed(2).replaceAll('.', ',')} → R\$ ${totalAfterBirthday.toStringAsFixed(2).replaceAll('.', ',')} (10% mês aniversário)'
                                      : 'Preço: R\$ ${totalCartPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          gradient: LinearGradient(
                            colors: [primary, const Color(0xFF7C4DFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Confirmar Agendamento',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lista somente leitura de serviços e fotos para visitante (antes de login).
class _GuestServicePortfolio extends StatelessWidget {
  const _GuestServicePortfolio({required this.servicesAsync, required this.slug});

  final AsyncValue<List<Service>> servicesAsync;
  final String slug;

  @override
  Widget build(BuildContext context) {
    return servicesAsync.when(
      data: (services) {
        final active = services.where((s) => s.active).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFFF5F6F8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nossos serviços',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Entre ou verifique seu cadastro para reservar. Enquanto isso, veja o portfólio e os valores.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF5C636A),
                  ),
                ),
                const SizedBox(height: 16),
                ...active.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            serviceSquareListImage(
                              shopDocId: slug,
                              service: s,
                              side: 76,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1D21),
                                    ),
                                  ),
                                  if (s.description != null && s.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      s.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF5C636A),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              s.priceFormatted,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1D21),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ReferralInviteCard extends StatelessWidget {
  final BarberShop barberShop;
  final String clientWhatsapp;
  final Color primary;

  const _ReferralInviteCard({
    required this.barberShop,
    required this.clientWhatsapp,
    required this.primary,
  });

  String get _inviteLink {
    // Mesma estratégia que configureAppUrlStrategy (path, sem #) — senão o GoRouter cai em /login.
    return '${Uri.base.origin}/b/${barberShop.slug}?ref=$clientWhatsapp';
  }

  String get _whatsappNumber {
    final digits = clientWhatsapp.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '55';
    return digits.length == 11 ? '55$digits' : '55$digits';
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final text = Uri.encodeComponent(
      'Ei, vim cortar na ${barberShop.name} e tô amando! '
      'Agenda também e a gente ganha pontos: $_inviteLink',
    );
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: primary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded, color: primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Indique um amigo e ganhe +${barberShop.referralPoints} pontos!',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _shareViaWhatsApp(context),
              icon: const Icon(Icons.chat, size: 22),
              label: const Text('Compartilhar convite (WhatsApp)'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _inviteLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copiado! Cole e envie para seu amigo.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.link, size: 20),
              label: const Text('Copiar link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão para o cliente ativar notificações push (lembretes) — só web.
class _ClientEnableNotificationsButton extends ConsumerStatefulWidget {
  const _ClientEnableNotificationsButton({
    required this.slug,
    required this.clientId,
    required this.primary,
  });
  final String slug;
  final String clientId;
  final Color primary;

  @override
  ConsumerState<_ClientEnableNotificationsButton> createState() =>
      _ClientEnableNotificationsButtonState();
}

class _ClientEnableNotificationsButtonState
    extends ConsumerState<_ClientEnableNotificationsButton> {
  bool _loading = false;

  Future<void> _enable() async {
    setState(() => _loading = true);
    try {
      final r = await requestAndRegisterWebNotifications(
        clientSlug: widget.slug,
        clientId: widget.clientId,
      );
      if (!mounted) return;
      if (!r.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão negada ou não disponível neste navegador.')),
        );
        setState(() => _loading = false);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificações ativadas! Lembretes, confirmações e avisos do barbeiro.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _enable,
      icon: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.notifications_active_outlined, size: 18),
      label: Text(_loading ? 'Ativando...' : 'Receber lembretes no celular'),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.primary,
        side: BorderSide(color: widget.primary),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  final String slug;
  final Client client;
  final Color primary;

  const _ClientCard({
    required this.slug,
    required this.client,
    required this.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralCountAsync =
        ref.watch(referralCountProvider((slug: slug, whatsapp: client.whatsapp)));
    final vouchersAsync = ref.watch(vouchersForClientProvider(
      (slug: slug, clientWhatsapp: client.whatsapp),
    ));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: primary.withValues(alpha: 0.3),
              child: Text(
                client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente encontrado',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    client.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pontos: ${client.loyaltyPoints} • ${client.stamps} selos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  referralCountAsync.when(
                    data: (refCount) {
                      if (refCount > 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Você indicou $refCount ${refCount == 1 ? 'amigo' : 'amigos'} • +${refCount * 20} pontos extras por indicações',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  vouchersAsync.when(
                    data: (vouchers) {
                      if (vouchers.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vouchers disponíveis',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            ...vouchers.map((v) {
                              final validUntil = v.expiresAt != null
                                  ? '${v.expiresAt!.day.toString().padLeft(2, '0')}/${v.expiresAt!.month.toString().padLeft(2, '0')}/${v.expiresAt!.year}'
                                  : '—';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${v.discountLabel} — código: ${v.code} (válido até $validUntil)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      tooltip: 'Copiar código',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: v.code),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Código copiado!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Negócio')),
      body: const Center(child: Text('Negócio não encontrado')),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Carregando negócio...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Erro ao carregar',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
