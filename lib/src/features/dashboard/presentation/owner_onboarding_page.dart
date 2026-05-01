import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/barber_shop.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/dashboard_tab_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/color_utils.dart';

const _bg = Color(0xFFF2F2F2);
const _orange = Color(0xFFFF8C00);

const _swatches = <Color>[
  Color(0xFF7C3AED),
  Color(0xFF2563EB),
  Color(0xFF0D9488),
  Color(0xFFFF8C00),
  Color(0xFFEF4444),
  Color(0xFF4B5563),
];

/// Assistente em 3 passos (Dados → Serviços → Horário) alinhado ao Figma.
class OwnerOnboardingPage extends ConsumerStatefulWidget {
  const OwnerOnboardingPage({super.key, this.initialShop});

  final BarberShop? initialShop;

  @override
  ConsumerState<OwnerOnboardingPage> createState() => _OwnerOnboardingPageState();
}

class _ServiceDraft {
  _ServiceDraft({required this.name, required this.price, required this.durationMin});
  String name;
  double price;
  int durationMin;
}

class _DayConfig {
  _DayConfig({
    required this.weekday,
    required this.label,
    required this.open,
    required this.start,
    required this.end,
  });
  final int weekday;
  final String label;
  bool open;
  String start;
  String end;
}

class _OwnerOnboardingPageState extends ConsumerState<OwnerOnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  final _name = TextEditingController();
  final _slug = TextEditingController();
  int _swatchIndex = 3;
  Color get _swatch => _swatches[_swatchIndex];
  Uint8List? _logoBytes;
  String? _logoUrlExisting;

  final List<_ServiceDraft> _services = [];
  List<_DayConfig> _days = [];
  final List<TextEditingController> _dayStartC = [];
  final List<TextEditingController> _dayEndC = [];

  bool _saving = false;
  String? _slugToUse;

  int get _stepFromShop {
    final s = widget.initialShop;
    if (s == null) return 0;
    return s.onboardingScreen.clamp(0, 3) >= 3 ? 0 : s.onboardingScreen.clamp(0, 2);
  }

  @override
  void initState() {
    super.initState();
    final shop = widget.initialShop;
    _currentPage = _stepFromShop;
    _pageController = PageController(initialPage: _currentPage);
    if (shop != null) {
      _name.text = shop.name;
      _slug.text = shop.slug;
      _slugToUse = shop.slug;
      final pc = Color(shop.primaryColor);
      for (var i = 0; i < _swatches.length; i++) {
        if (_swatches[i].value == pc.value) {
          _swatchIndex = i;
          break;
        }
      }
      _logoUrlExisting = shop.logoUrl;
      if (shop.weeklyHours != null && shop.weeklyHours!.isNotEmpty) {
        _parseWeeklyToDays(shop.weeklyHours!);
      } else {
        _initDefaultDays();
      }
    } else {
      _initDefaultDays();
    }
    for (var i = 0; i < 7; i++) {
      _dayStartC.add(TextEditingController(text: _days[i].start));
      _dayEndC.add(TextEditingController(text: _days[i].end));
    }
    if (shop != null && (shop.onboardingScreen == 1 || shop.onboardingScreen == 2) && _services.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadServicesIfNeeded(shop.slug));
    }
  }

  void _initDefaultDays() {
    const labels = <String, String>{
      '1': 'Segunda-feira',
      '2': 'Terça-feira',
      '3': 'Quarta-feira',
      '4': 'Quinta-feira',
      '5': 'Sexta-feira',
      '6': 'Sábado',
      '7': 'Domingo',
    };
    _days = List.generate(7, (i) {
      final w = i + 1;
      final isSun = w == 7;
      return _DayConfig(
        weekday: w,
        label: labels['$w']!,
        open: !isSun,
        start: '09:00',
        end: w == 6 ? '14:00' : '18:00',
      );
    });
  }

  void _parseWeeklyToDays(Map<String, dynamic> wh) {
    const labels = <String, String>{
      '1': 'Segunda-feira',
      '2': 'Terça-feira',
      '3': 'Quarta-feira',
      '4': 'Quinta-feira',
      '5': 'Sexta-feira',
      '6': 'Sábado',
      '7': 'Domingo',
    };
    _days = List.generate(7, (i) {
      final w = i + 1;
      final m = wh['$w'];
      if (m is Map) {
        return _DayConfig(
          weekday: w,
          label: labels['$w']!,
          open: m['open'] != false,
          start: (m['start'] as String?) ?? '09:00',
          end: (m['end'] as String?) ?? '18:00',
        );
      }
      return _DayConfig(weekday: w, label: labels['$w']!, open: w != 7, start: '09:00', end: w == 6 ? '14:00' : '18:00');
    });
  }

  Future<void> _loadServicesIfNeeded(String slug) async {
    if (_services.isNotEmpty) return;
    final firestore = ref.read(firestoreProvider);
    final snap = await firestore
        .collection(barbershopsCollection)
        .doc(slug)
        .collection('services')
        .get();
    if (!mounted) return;
    if (snap.docs.isEmpty) return;
    setState(() {
      _services.clear();
      for (final d in snap.docs) {
        final m = d.data();
        _services.add(
          _ServiceDraft(
            name: m['name'] as String? ?? 'Serviço',
            price: (m['price'] as num?)?.toDouble() ?? 0,
            durationMin: m['durationMinutes'] as int? ?? 30,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in _dayStartC) {
      c.dispose();
    }
    for (final c in _dayEndC) {
      c.dispose();
    }
    _pageController.dispose();
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  String _normSlug(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  double _progressForPage(int p) {
    if (p <= 0) return 0.33;
    if (p == 1) return 0.66;
    return 1.0;
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final b = result.files.first.bytes;
    if (b != null) setState(() => _logoBytes = b);
  }

  bool _isValidTime(String t) {
    final p = t.trim().split(':');
    if (p.length < 2) return false;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h < 24 && m >= 0 && m < 60;
  }

  Map<String, dynamic> _buildWeeklyMap() {
    return {
      for (final d in _days)
        '${d.weekday}': {'open': d.open, 'start': d.start, 'end': d.end}
    };
  }

  (String, String) _defaultOpenClose() {
    final mon = _days.firstWhere((e) => e.weekday == 1, orElse: () => _days.first);
    return (mon.start, mon.end);
  }

  Future<void> _saveStep0() async {
    final name = _name.text.trim();
    var slug = _normSlug(_slug.text);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do negócio.')),
      );
      return;
    }
    if (slug.isEmpty) {
      slug = _normSlug(name).replaceAll('-', '');
      if (slug.isEmpty) slug = 'meunegocio';
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final existing = await firestore.collection(barbershopsCollection).doc(slug).get();
      if (existing.exists) {
        final o = existing.data()?['ownerUid'] as String?;
        if (o != null && o != user.uid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Este endereço já está em uso. Escolha outro slug.')),
            );
          }
          return;
        }
      }
      String? logoUrl = _logoUrlExisting;
      final storage = ref.read(firebaseStorageProvider);
      if (_logoBytes != null) {
        final refSt = storage.ref().child('logos/${user.uid}/$slug.jpg');
        await refSt.putData(_logoBytes!, SettableMetadata(contentType: 'image/jpeg'));
        logoUrl = await refSt.getDownloadURL();
      }
      final now = DateTime.now();
      await firestore.collection(barbershopsCollection).doc(slug).set({
        'name': name,
        'slug': slug,
        'ownerUid': user.uid,
        'primaryColor': colorToHex(_swatch),
        'secondaryColor': colorToHex(const Color(0xFF1A1A2E)),
        'watermarkOpacity': 0.15,
        'plan': 'basic',
        'businessTypes': ['barbershop'],
        'themeStyle': 'both',
        'loyaltyCardStyle': 'masculine',
        'singleAttendant': true,
        'openTime': '09:00',
        'closeTime': '18:00',
        'referralPoints': 30,
        'subscriptionStatus': 'trial',
        'trialEndsAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'onboardingScreen': 1,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _slugToUse = slug;
        _logoUrlExisting = logoUrl;
      });
      ref.invalidate(barberShopProvider);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveStep1() async {
    final slug = _slugToUse ?? _normSlug(_slug.text);
    if (slug.isEmpty) return;
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um serviço.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final col = firestore.collection(barbershopsCollection).doc(slug).collection('services');
      final existing = await col.get();
      for (final d in existing.docs) {
        await d.reference.delete();
      }
      for (final s in _services) {
        await col.add({
          'name': s.name,
          'price': s.price,
          'durationMinutes': s.durationMin,
        });
      }
      await firestore.collection(barbershopsCollection).doc(slug).update({
        'onboardingScreen': 2,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(barberShopProvider);
      ref.invalidate(servicesProvider(slug));
      if (!mounted) return;
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishStep2() async {
    for (var i = 0; i < 7; i++) {
      _days[i].start = _dayStartC[i].text.trim();
      _days[i].end = _dayEndC[i].text.trim();
    }
    for (final d in _days) {
      if (d.open) {
        if (!_isValidTime(d.start) || !_isValidTime(d.end)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Horário inválido em ${d.label} (use HH:mm).')),
          );
          return;
        }
      }
    }
    final slug = _slugToUse ?? _normSlug(_slug.text);
    if (slug.isEmpty) return;
    final oc = _defaultOpenClose();
    final defOpen = oc.$1;
    final defClose = oc.$2;
    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final weekly = _buildWeeklyMap();
      await firestore.collection(barbershopsCollection).doc(slug).update({
        'openTime': defOpen,
        'closeTime': defClose,
        'weeklyHours': weekly,
        'onboardingScreen': 3,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(barberShopProvider);
      ref.read(ownerOnboardingRequestProvider.notifier).state = false;
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addServiceDialog() {
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    final durC = TextEditingController(text: '30');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(
              controller: priceC,
              decoration: const InputDecoration(labelText: 'Preço (R\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: durC,
              decoration: const InputDecoration(labelText: 'Duração (min)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              final price = double.tryParse(priceC.text.replaceAll(',', '.'));
              final dur = int.tryParse(durC.text);
              if (name.isEmpty || price == null || dur == null) return;
              setState(() => _services.add(_ServiceDraft(name: name, price: price, durationMin: dur)));
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D21)),
          onPressed: _saving
              ? null
              : () {
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    context.go('/login');
                  }
                },
        ),
        title: Text(
          _currentPage == 0
              ? 'Dados do negócio'
              : _currentPage == 1
                  ? 'Seus serviços'
                  : 'Horário de funcionamento',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1D21),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: _currentPage == 2
              ? Container(height: 3, color: _orange)
              : const SizedBox(height: 0),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progressForPage(_currentPage),
                minHeight: 4,
                backgroundColor: const Color(0xFFE0E0E0),
                color: _orange,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildDadosForm(),
                _buildServicesForm(),
                _buildHoursForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDadosForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _saving ? null : _pickLogo,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD0D0D0),
                      width: 2,
                    ),
                    color: _logoBytes != null || (_logoUrlExisting != null && _logoUrlExisting!.isNotEmpty)
                        ? null
                        : const Color(0xFFF5F5F5),
                    image: _logoBytes != null
                        ? DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover)
                        : _logoUrlExisting != null && _logoUrlExisting!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_logoUrlExisting!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: _logoBytes == null && (_logoUrlExisting == null || _logoUrlExisting!.isEmpty)
                      ? Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey[600])
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adicionar logo',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF5C636A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Nome do negócio', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          enabled: !_saving,
          decoration: _roundedDecoration(hint: 'Barbearia do João'),
        ),
        const SizedBox(height: 20),
        Text('Link de agendamento', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'meunegocio.app/b/',
              style: GoogleFonts.poppins(color: const Color(0xFF8E9399), fontSize: 15),
            ),
            Expanded(
              child: TextField(
                controller: _slug,
                enabled: _slugToUse == null && !_saving,
                decoration: _roundedDecoration(hint: 'barbeariadojoao'),
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        if (_slugToUse != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'O link já foi criado. Para alterar o slug, use Configurações depois.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
            ),
          ),
        const SizedBox(height: 20),
        Text('Cor principal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          'Esta cor será usada na página do seu cliente.',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _swatches.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            final sel = _swatchIndex == i;
            return GestureDetector(
              onTap: _saving ? null : () => setState(() => _swatchIndex = i),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2),
                  boxShadow: sel
                      ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                      : null,
                ),
                child: sel
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        _blackButton(
          label: 'Continuar',
          onPressed: _saving ? null : _saveStep0,
        ),
      ],
    );
  }

  Widget _buildServicesForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Text(
          'Adicione os serviços que você oferece. Você poderá editar isso depois.',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
        ),
        const SizedBox(height: 16),
        ..._services.map((s) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.content_cut_rounded, color: _orange),
              ),
              title: Text(
                s.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${s.durationMin} min • R\$ ${s.price.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.poppins(color: const Color(0xFF5C636A), fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB0B0B0)),
                onPressed: _saving
                    ? null
                    : () => setState(() => _services.remove(s)),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _addServiceDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBDBDBD), width: 1.2),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Color(0xFF5C636A)),
                  const SizedBox(width: 8),
                  Text(
                    'Adicionar novo serviço',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _blackButton(label: 'Continuar', onPressed: _saving ? null : _saveStep1),
      ],
    );
  }

  Widget _buildHoursForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Defina os dias e horários que seu negócio estará aberto.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                child: Column(
                  children: List.generate(7, (i) {
                    final d = _days[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.label,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                              Switch(
                                value: d.open,
                                activeThumbColor: Colors.white,
                                activeTrackColor: _orange,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => d.open = v),
                              ),
                            ],
                          ),
                          if (d.open) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('Das ', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1D21))),
                                SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: _dayStartC[i],
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                    ),
                                    keyboardType: TextInputType.datetime,
                                  ),
                                ),
                                Text('  às  ', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF1A1D21))),
                                SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: _dayEndC[i],
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                    ),
                                    keyboardType: TextInputType.datetime,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFCCCCCC)),
                              ],
                            ),
                          ],
                          if (i < 6) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _blackButton(
            label: 'Finalizar e ir para Dashboard',
            onPressed: _saving ? null : _finishStep2,
          ),
        ),
      ],
    );
  }

  InputDecoration _roundedDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E5E0)),
      ),
    );
  }

  Widget _blackButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
