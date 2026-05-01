import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/client.dart';
import '../../../core/models/product.dart';
import '../../../core/models/service.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/widgets/service_storage_image.dart';
import '../logic/appointment_completion_logic.dart';

const _gray600 = Color(0xFF5C636A);
const _gray900 = Color(0xFF1A1D21);
const _gray200 = Color(0xFFE5E7EB);

class _ProductCartLine {
  const _ProductCartLine({required this.product, required this.qty});
  final Product product;
  final double qty;
}

/// Bottom sheet: carrinho de atendimento avulso (vários serviços + produtos à venda).
class WalkInCheckoutSheet extends ConsumerStatefulWidget {
  const WalkInCheckoutSheet({
    super.key,
    required this.slug,
    required this.primaryColor,
  });

  final String slug;
  final Color primaryColor;

  @override
  ConsumerState<WalkInCheckoutSheet> createState() => _WalkInCheckoutSheetState();
}

class _WalkInCheckoutSheetState extends ConsumerState<WalkInCheckoutSheet> {
  final List<Service> _serviceCart = [];
  final Map<String, _ProductCartLine> _productById = {};
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  Client? _linkedClient;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _setLinkedClient(Client? c) {
    setState(() {
      _linkedClient = c;
      if (c != null) {
        _nameController.text = c.name;
        _whatsappController.text = c.whatsapp;
      }
    });
  }

  double get _servicesSubtotal =>
      _serviceCart.fold<double>(0, (s, e) => s + e.price);

  double get _productsSubtotal => _productById.values.fold<double>(
        0,
        (s, line) => s + line.qty * line.product.salePrice,
      );

  double get _grandTotal => _servicesSubtotal + _productsSubtotal;

  Future<void> _pickProductQuantity(Product product) async {
    final ctrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantidade',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final q = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (q == null || q <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade inválida')),
      );
      return;
    }
    if (q > product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estoque insuficiente para ${product.name}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final prev = _productById[product.id];
    final nextQty = (prev?.qty ?? 0) + q;
    if (nextQty > product.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Total no carrinho excede o estoque de ${product.name}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    setState(() {
      _productById[product.id] = _ProductCartLine(product: product, qty: nextQty);
    });
  }

  Future<void> _registerProductSale(
    FirebaseFirestore firestore,
    Product product,
    double qty,
    String? linkedAppointmentId,
  ) async {
    final productRef = firestore
        .collection(barbershopsCollection)
        .doc(widget.slug)
        .collection('products')
        .doc(product.id);
    final movementsRef = firestore
        .collection(barbershopsCollection)
        .doc(widget.slug)
        .collection('stock_movements');

    await firestore.runTransaction((tx) async {
      final snap = await tx.get(productRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Produto não encontrado');
      }
      final p = Product.fromFirestore(snap.id, snap.data()!);
      if (qty > p.currentStock) {
        throw StateError('Estoque insuficiente: ${p.name}');
      }
      final newStock = p.currentStock - qty;
      final value = qty * p.salePrice;
      tx.update(productRef, {
        'currentStock': newStock,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      tx.set(
        movementsRef.doc(),
        StockMovement(
          id: '',
          type: 'sale',
          productId: p.id,
          quantity: -qty,
          value: value,
          costValue: qty * p.costPrice,
          date: DateTime.now(),
          reason: 'Venda — atendimento avulso',
          linkedAppointmentId: linkedAppointmentId,
        ).toFirestore(),
      );
    });
  }

  Future<void> _finalize() async {
    if (_serviceCart.isEmpty && _productById.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um serviço ou produto')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final firestore = ref.read(firestoreProvider);
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    String? appointmentId;
    final now = DateTime.now();

    try {
      final clientNameManual = _nameController.text.trim();
      final clientWhatsappManual = _whatsappController.text.trim();
      final cid = _linkedClient?.id;
      final displayName = (cid != null ? _linkedClient!.name : clientNameManual).trim();
      final displayWhatsapp =
          (cid != null ? _linkedClient!.whatsapp : clientWhatsappManual).trim();

      if (_serviceCart.isNotEmpty) {
        final servicesTotal = _servicesSubtotal;
        final totalDuration = _serviceCart.fold<int>(0, (s, sv) => s + sv.durationMinutes);
        final servicesData = _serviceCart
            .map(
              (s) => {
                'serviceId': s.id,
                'serviceName': s.name,
                'price': s.price,
                'durationMinutes': s.durationMinutes,
              },
            )
            .toList();

        final doc = await firestore.collection('appointments').add({
          'barberShopId': widget.slug,
          if (cid != null && cid.isNotEmpty) 'clientId': cid,
          'clientName': displayName.isEmpty ? 'Cliente avulso' : displayName,
          'clientWhatsapp': displayWhatsapp,
          'serviceId': _serviceCart.first.id,
          'serviceName': _serviceCart.map((s) => s.name).join(', '),
          'services': servicesData,
          'dateTime': Timestamp.fromDate(now),
          'originalDateTime': Timestamp.fromDate(now),
          'durationMinutes': totalDuration,
          'status': 'completed',
          'walkIn': true,
          'completedAt': FieldValue.serverTimestamp(),
          'originalPrice': servicesTotal,
          'finalPrice': servicesTotal,
          'reminderSent': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        appointmentId = doc.id;

        await applyServiceConsumptionsForServices(
          ref: ref,
          firestore: firestore,
          slug: widget.slug,
          appointmentId: appointmentId,
          servicesToApply: List<Service>.from(_serviceCart),
        );

        if (cid != null && cid.isNotEmpty) {
          await firestore
              .collection(barbershopsCollection)
              .doc(widget.slug)
              .collection('clients')
              .doc(cid)
              .update({
            'totalAppointments': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          ref.invalidate(clientsProvider(widget.slug));

          final vouchersCreated = await awardLoyaltyAfterCompletedAppointment(
            ref: ref,
            firestore: firestore,
            slug: widget.slug,
            clientId: cid,
          );
          final shop = await ref.read(barberShopBySlugProvider(widget.slug).future);
          final pointsRequired =
              (shop?.loyaltyPointsRequired ?? 100).clamp(1, 10000);
          if (mounted) {
            showLoyaltyVouchersSnackBar(
              context,
              mounted: mounted,
              shop: shop,
              pointsRequired: pointsRequired,
              vouchersGenerated: vouchersCreated,
            );
          }
        }
      }

      for (final line in _productById.values) {
        await _registerProductSale(
          firestore,
          line.product,
          line.qty,
          appointmentId,
        );
      }
      ref.invalidate(productsProvider(widget.slug));
      ref.invalidate(stockMovementsProvider(widget.slug));
      ref.invalidate(appointmentsProvider(widget.slug));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registrado: ${money.format(_grandTotal)}'
            '${_serviceCart.isEmpty ? ' (somente produtos)' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final servicesAsync = ref.watch(servicesProvider(widget.slug));
    final productsAsync = ref.watch(productsProvider(widget.slug));
    final clientsAsync = ref.watch(clientsProvider(widget.slug));

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Atendimento avulso',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _gray900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Monte o carrinho com os serviços feitos agora e produtos vendidos ao cliente — sem passar pela agenda.',
              style: GoogleFonts.poppins(fontSize: 13, color: _gray600, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              children: [
                Text(
                  'Cliente (opcional)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _gray900,
                  ),
                ),
                const SizedBox(height: 8),
                clientsAsync.when(
                  data: (clients) {
                    final clientIds = {for (final c in clients) c.id};
                    if (_linkedClient != null && !clientIds.contains(_linkedClient!.id)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _setLinkedClient(null);
                      });
                    }
                    final dropdownValue =
                        _linkedClient != null && clientIds.contains(_linkedClient!.id)
                            ? _linkedClient!.id
                            : null;
                    return DropdownButtonFormField<String?>(
                      value: dropdownValue,
                      decoration: const InputDecoration(
                        labelText: 'Vincular cliente cadastrado',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Não vincular — preencher nome abaixo'),
                        ),
                        ...clients.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text('${c.name} · ${c.whatsapp}'),
                          ),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (id) {
                              if (id == null) {
                                _setLinkedClient(null);
                                return;
                              }
                              final c = clients.firstWhere((e) => e.id == id);
                              _setLinkedClient(c);
                            },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro clientes: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  enabled: _saving ? false : _linkedClient == null,
                  decoration: const InputDecoration(
                    labelText: 'Nome do cliente',
                    hintText: 'Ex.: João (ou deixe em branco)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _whatsappController,
                  enabled: _saving ? false : _linkedClient == null,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                Text(
                  'Adicionar serviços',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque em um serviço para colocar no carrinho (pode repetir o mesmo).',
                  style: GoogleFonts.poppins(fontSize: 12, color: _gray600),
                ),
                const SizedBox(height: 8),
                servicesAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return Text(
                        'Nenhum serviço cadastrado.',
                        style: GoogleFonts.poppins(color: _gray600),
                      );
                    }
                    return Column(
                      children: list
                          .map(
                            (s) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: _gray200),
                              ),
                              child: ListTile(
                                leading: ServiceThumbnailImage(
                                  slug: widget.slug,
                                  serviceId: s.id,
                                  imageUrl: s.imageUrl,
                                  width: 48,
                                  height: 48,
                                  borderRadius: 10,
                                ),
                                title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${s.durationMinutes} min · ${money.format(s.price)}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: _gray600),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: widget.primaryColor),
                                  onPressed: _saving ? null : () => setState(() => _serviceCart.add(s)),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Erro: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Produtos (estoque)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Baixa no estoque e registro de venda no financeiro.',
                  style: GoogleFonts.poppins(fontSize: 12, color: _gray600),
                ),
                const SizedBox(height: 8),
                productsAsync.when(
                  data: (list) {
                    final sorted = [...list]..sort((a, b) => a.name.compareTo(b.name));
                    if (sorted.isEmpty) {
                      return Text(
                        'Nenhum produto no estoque.',
                        style: GoogleFonts.poppins(color: _gray600),
                      );
                    }
                    return Column(
                      children: sorted
                          .where((p) => p.currentStock > 0)
                          .map(
                            (p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: _gray200),
                              ),
                              child: ListTile(
                                title: Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Estoque: ${p.currentStock.toStringAsFixed(p.unit == 'un' ? 0 : 1)} ${p.unitLabel} · ${money.format(p.salePrice)}',
                                  style: GoogleFonts.poppins(fontSize: 12, color: _gray600),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.shopping_cart_outlined, color: widget.primaryColor),
                                  onPressed: _saving ? null : () => _pickProductQuantity(p),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => Text('Erro produtos: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Carrinho',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _gray900,
                  ),
                ),
                const SizedBox(height: 8),
                if (_serviceCart.isEmpty && _productById.isEmpty)
                  Text(
                    'Vazio — adicione serviços ou produtos acima.',
                    style: GoogleFonts.poppins(color: _gray600),
                  )
                else ...[
                  ..._serviceCart.asMap().entries.map((e) {
                    final s = e.value;
                    final idx = e.key;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ServiceThumbnailImage(
                        slug: widget.slug,
                        serviceId: s.id,
                        imageUrl: s.imageUrl,
                        width: 40,
                        height: 40,
                        borderRadius: 8,
                        placeholder: Icon(Icons.content_cut_rounded, color: widget.primaryColor, size: 22),
                      ),
                      title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(money.format(s.price), style: GoogleFonts.poppins(fontSize: 12, color: _gray600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: _gray600),
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _serviceCart.removeAt(idx);
                                }),
                      ),
                    );
                  }),
                  ..._productById.values.map(
                    (line) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.inventory_2_outlined, color: widget.primaryColor, size: 22),
                      title: Text(line.product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(
                        '${line.qty.toStringAsFixed(line.product.unit == 'un' ? 0 : 1)} ${line.product.unitLabel} · ${money.format(line.qty * line.product.salePrice)}',
                        style: GoogleFonts.poppins(fontSize: 12, color: _gray600),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: _gray600),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _productById.remove(line.product.id)),
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      Text(
                        money.format(_grandTotal),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 88),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: FilledButton(
              onPressed: _saving ? null : _finalize,
              style: FilledButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Finalizar atendimento',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showWalkInCheckoutSheet(
  BuildContext context, {
  required String slug,
  required Color primaryColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(ctx).top + 8),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.92,
        child: WalkInCheckoutSheet(slug: slug, primaryColor: primaryColor),
      ),
    ),
  );
}
