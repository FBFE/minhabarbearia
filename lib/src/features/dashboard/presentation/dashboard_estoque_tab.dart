import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/barber_shop.dart';
import '../../../core/models/product.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/firestore_user_error.dart';
import '../logic/appointment_completion_logic.dart';

const _productCategories = [
  'Shampoo',
  'Condicionador',
  'Esmalte',
  'Tintura',
  'Descolorante',
  'Hidratante',
  'Outros',
];

const _units = ['un', 'ml', 'g'];

/// Aba Estoque do dashboard: produtos, estoque mínimo, entradas/saídas/ajustes.
class DashboardEstoqueTab extends ConsumerWidget {
  const DashboardEstoqueTab({super.key, this.barberShop});

  final BarberShop? barberShop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barberShop == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crie ou vincule seu negócio em Configurações para gerenciar estoque.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _EstoqueCard(slug: barberShop!.slug, primaryColor: barberShop!.primaryColorAsColor),
    );
  }
}

class _EstoqueCard extends ConsumerStatefulWidget {
  final String slug;
  final Color primaryColor;

  const _EstoqueCard({required this.slug, required this.primaryColor});

  @override
  ConsumerState<_EstoqueCard> createState() => _EstoqueCardState();
}

class _EstoqueCardState extends ConsumerState<_EstoqueCard> {
  final _searchController = TextEditingController();
  String? _filterCategory;
  bool _syncConsumptionsLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  (int, int) _entradasSaidasMes(List<StockMovement> movements) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, 1);
    int inC = 0, outC = 0;
    for (final m in movements) {
      if (m.date.isBefore(start) || m.date.isAfter(n)) continue;
      if (m.type == 'purchase' || m.type == 'transfer_to_studio' || (m.type == 'adjustment' && m.quantity > 0)) {
        inC++;
      } else if (m.type == 'sale' || m.type == 'service_use' || (m.type == 'adjustment' && m.quantity < 0)) {
        outC++;
      }
    }
    return (inC, outC);
  }

  Future<void> _syncMissingServicoConsumptions() async {
    if (_syncConsumptionsLoading) return;
    setState(() => _syncConsumptionsLoading = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final result = await syncMissingConsumptionForCompletedAppointments(
        ref: ref,
        firestore: firestore,
        slug: widget.slug,
      );
      if (!mounted) return;
      final n = result.appliedCount;
      final errs = result.skippedErrors;
      final hint = result.firstErrorHint;
      late final String summary;
      if (n == 0 && errs == 0) {
        summary =
            'Nada a corrigir: todos os atendimentos já tinham baixa de consumo registada '
            '(ou os serviços não têm produtos vinculados).';
      } else if (n > 0 && errs > 0) {
        summary =
            'Baixas aplicadas em $n atendimento(s). $errs atendimento(s) falharam: ${hint ?? "ver detalhes no log"}.';
      } else if (n > 0) {
        summary = 'Baixas de produto aplicadas para $n atendimento(s) que estavam em falta.';
      } else if (errs > 0 && hint != null) {
        summary = 'Sincronização não aplicou novas baixas. Alguns registos falharam: $hint';
      } else {
        summary = 'Nenhuma nova baixa aplicada.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
          backgroundColor: errs > 0
              ? (n > 0 ? Colors.deepOrange.shade800 : Theme.of(context).colorScheme.error)
              : Colors.green.shade800,
          duration: Duration(seconds: errs > 0 ? 7 : 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: ${firestoreUserVisibleError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncConsumptionsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.slug));
    final movementsAsync = ref.watch(stockMovementsProvider(widget.slug));
    final search = _searchController.text.trim().toLowerCase();

    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estoque',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Controle de produtos',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF5C636A),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showProductForm(context, ref, widget.slug, null),
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                  label: const Text('Novo Produto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            movementsAsync.when(
              data: (moves) {
                final t = _entradasSaidasMes(moves);
                return Row(
                  children: [
                    Expanded(
                      child: _EstoqueKpiMini(
                        label: 'Entradas',
                        value: '${t.$1}',
                        sub: 'itens este mês',
                        color: const Color(0xFF16A34A),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EstoqueKpiMini(
                        label: 'Saídas',
                        value: '${t.$2}',
                        sub: 'itens este mês',
                        color: const Color(0xFFDC2626),
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _syncConsumptionsLoading ? null : _syncMissingServicoConsumptions,
              icon: _syncConsumptionsLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                _syncConsumptionsLoading ? 'Sincronizando…' : 'Sincronizar consumos dos serviços',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Usa quando a baixa automática falhou antes (ex.: após atualizar a app). '
              'Revê atendimentos concluídos sem movimento de «uso nos serviços».',
              style: GoogleFonts.poppins(fontSize: 11, height: 1.35, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Text(
              'Seus produtos',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D21),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar produto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _filterCategory == null,
                    onSelected: (_) => setState(() => _filterCategory = null),
                  ),
                  ..._productCategories.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text(c),
                          selected: _filterCategory == c,
                          onSelected: (_) => setState(() => _filterCategory = c),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            productsAsync.when(
              data: (products) {
                var list = products;
                if (search.isNotEmpty) {
                  list = list.where((p) => p.name.toLowerCase().contains(search)).toList();
                }
                if (_filterCategory != null) {
                  list = list.where((p) => p.category == _filterCategory).toList();
                }
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      products.isEmpty
                          ? 'Nenhum produto. Clique em "Novo produto" para cadastrar.'
                          : 'Nenhum produto encontrado.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5C636A),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F6F8)),
                    columns: const [
                      DataColumn(label: Text('Produto')),
                      DataColumn(label: Text('Categoria')),
                      DataColumn(label: Text('Estoque atual')),
                      DataColumn(label: Text('Studio')),
                      DataColumn(label: Text('Mínimo')),
                      DataColumn(label: Text('Un')),
                      DataColumn(label: Text('Ações')),
                    ],
                    rows: list.map((p) {
                      final isLow = p.isLowStock;
                      final studioLow = p.isStudioLow;
                      final studioText = p.studioRemainingPercent != null && p.studioRemainingPercent! > 0
                          ? '${p.studioRemainingPercent!.toStringAsFixed(0)}%'
                          : '—';
                      return DataRow(
                        color: studioLow ? WidgetStateProperty.all(Colors.orange.shade50) : null,
                        cells: [
                          DataCell(Text(p.name)),
                          DataCell(Text(p.category)),
                          DataCell(
                            Text(
                              '${p.currentStock.toStringAsFixed(p.unit == 'un' ? 0 : 1)}',
                              style: TextStyle(
                                color: isLow ? Colors.red : null,
                                fontWeight: isLow ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              studioText,
                              style: TextStyle(
                                color: studioLow ? Colors.orange.shade800 : null,
                                fontWeight: studioLow ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                          DataCell(Text(p.minStock.toStringAsFixed(p.unit == 'un' ? 0 : 1))),
                          DataCell(Text(p.unitLabel)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showProductForm(context, ref, widget.slug, p),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => _showMovementSheet(context, ref, widget.slug, p, 'purchase'),
                                tooltip: 'Entrada',
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => _showMovementSheet(context, ref, widget.slug, p, 'sale'),
                                tooltip: 'Saída / Venda',
                              ),
                              IconButton(
                                icon: const Icon(Icons.storefront_outlined, size: 20),
                                onPressed: p.currentStock >= 1
                                    ? () => _withdrawToStudio(context, ref, widget.slug, p)
                                    : null,
                                tooltip: p.currentStock >= 1
                                    ? 'Retirar 1 un. para uso no studio'
                                    : 'Sem estoque para retirar',
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune, size: 20),
                                onPressed: () => _showMovementSheet(context, ref, widget.slug, p, 'adjustment'),
                                tooltip: 'Ajuste',
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erro: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductForm(BuildContext context, WidgetRef ref, String slug, Product? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductFormSheet(
        slug: slug,
        existing: existing,
        primaryColor: widget.primaryColor,
        onSaved: () {
          ref.invalidate(productsProvider(slug));
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showMovementSheet(
    BuildContext context,
    WidgetRef ref,
    String slug,
    Product product,
    String type,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MovementSheet(
        slug: slug,
        product: product,
        type: type,
        primaryColor: widget.primaryColor,
        onSaved: () {
          ref.invalidate(productsProvider(slug));
          ref.invalidate(stockMovementsProvider(slug));
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _withdrawToStudio(BuildContext context, WidgetRef ref, String slug, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar para uso no studio'),
        content: Text(
          'Retirar 1 unidade de "${product.name}" do estoque de vendas para uso no studio? '
          'Serão somados 100% ao “uso no studio” por unidade (ex.: 2 un. = 200%; cada atendimento consome o % definido no serviço).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final firestore = ref.read(firestoreProvider);
      final productRef = firestore
          .collection(barbershopsCollection)
          .doc(slug)
          .collection('products')
          .doc(product.id);
      final movementsRef = firestore
          .collection(barbershopsCollection)
          .doc(slug)
          .collection('stock_movements');
      final newStock = (product.currentStock - 1).clamp(0.0, double.infinity);
      final nextStudio = (product.studioRemainingPercent ?? 0) + 100.0;
      await firestore.runTransaction((tx) async {
        tx.update(productRef, {
          'currentStock': newStock,
          'studioRemainingPercent': nextStudio,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        tx.set(movementsRef.doc(), StockMovement(
          id: '',
          type: 'transfer_to_studio',
          productId: product.id,
          quantity: -1,
          value: product.costPrice,
          date: DateTime.now(),
          reason: 'Retirada para uso no studio (+100%)',
        ).toFirestore());
      });
      ref.invalidate(productsProvider(slug));
      ref.invalidate(stockMovementsProvider(slug));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produto retirado para uso no studio (total: ${nextStudio.toStringAsFixed(0)}%)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _EstoqueKpiMini extends StatelessWidget {
  const _EstoqueKpiMini({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1D21),
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  final String slug;
  final Product? existing;
  final Color primaryColor;
  final VoidCallback onSaved;

  const _ProductFormSheet({
    required this.slug,
    this.existing,
    required this.primaryColor,
    required this.onSaved,
  });

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _saleController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  String _category = _productCategories.first;
  String _unit = 'un';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _category = _productCategories.contains(e.category) ? e.category : 'Outros';
      _costController.text = e.costPrice.toStringAsFixed(2).replaceAll('.', ',');
      _saleController.text = e.salePrice.toStringAsFixed(2).replaceAll('.', ',');
      _stockController.text = e.currentStock.toStringAsFixed(e.unit == 'un' ? 0 : 1).replaceAll('.', ',');
      _minStockController.text = e.minStock.toStringAsFixed(e.unit == 'un' ? 0 : 1).replaceAll('.', ',');
      _unit = _units.contains(e.unit) ? e.unit : 'un';
    } else {
      _minStockController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _saleController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do produto')),
      );
      return;
    }
    final cost = _parseDouble(_costController.text);
    final sale = _parseDouble(_saleController.text);
    final stock = _parseDouble(_stockController.text);
    final minStock = _parseDouble(_minStockController.text);
    if (cost == null || cost < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o custo válido')),
      );
      return;
    }
    if (sale == null || sale < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o preço de venda válido')),
      );
      return;
    }
    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o estoque inicial válido')),
      );
      return;
    }
    if (minStock == null || minStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estoque mínimo deve ser um número ≥ 0')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final data = {
        'name': name,
        'category': _category,
        'costPrice': cost,
        'salePrice': sale,
        'currentStock': stock,
        'minStock': minStock,
        'unit': _unit,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (widget.existing != null) {
        await firestore
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('products')
            .doc(widget.existing!.id)
            .update(data);
      } else {
        await firestore
            .collection(barbershopsCollection)
            .doc(widget.slug)
            .collection('products')
            .add(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing != null ? 'Produto atualizado!' : 'Produto cadastrado!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _parseDouble(String s) {
    final n = s.replaceAll(',', '.');
    return double.tryParse(n);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing != null ? 'Editar produto' : 'Cadastrar produto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estoque mínimo: quando o estoque ficar igual ou abaixo desse valor, o sistema avisa que está acabando.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5C636A)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do produto',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: _productCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costController,
                    decoration: const InputDecoration(
                      labelText: 'Custo (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _saleController,
                    decoration: const InputDecoration(
                      labelText: 'Preço venda (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Estoque atual',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Estoque mínimo (alerta)',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: 5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(
                labelText: 'Unidade',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                DropdownMenuItem(value: 'ml', child: Text('Mililitro (ml)')),
                DropdownMenuItem(value: 'g', child: Text('Gramas (g)')),
              ],
              onChanged: (v) => setState(() => _unit = v ?? 'un'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: widget.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementSheet extends ConsumerStatefulWidget {
  final String slug;
  final Product product;
  final String type;
  final Color primaryColor;
  final VoidCallback onSaved;

  const _MovementSheet({
    required this.slug,
    required this.product,
    required this.type,
    required this.primaryColor,
    required this.onSaved,
  });

  @override
  ConsumerState<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends ConsumerState<_MovementSheet> {
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qtyStr = _qtyController.text.replaceAll(',', '.');
    final qty = double.tryParse(qtyStr);
    if (qty == null || qty == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a quantidade (use negativo para baixa no ajuste)')),
      );
      return;
    }
    if (widget.type != 'adjustment' && qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade deve ser positiva')),
      );
      return;
    }
    final reason = _reasonController.text.trim();

    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final productRef = firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('products')
          .doc(widget.product.id);
      final movementsRef = firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('stock_movements');

      double newStock = widget.product.currentStock;
      double value = 0;
      double quantity = qty;
      if (widget.type == 'purchase') {
        newStock += qty;
        value = qty * widget.product.costPrice;
      } else if (widget.type == 'sale') {
        if (qty > widget.product.currentStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Estoque insuficiente'), backgroundColor: Colors.red),
            );
          }
          setState(() => _saving = false);
          return;
        }
        newStock -= qty;
        quantity = -qty;
        value = qty * widget.product.salePrice;
      } else {
        // adjustment: positive = add, negative = subtract
        newStock += qty;
        value = 0;
        quantity = qty;
      }
      if (newStock < 0) newStock = 0;

      await firestore.runTransaction((tx) async {
        tx.update(productRef, {
          'currentStock': newStock,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        final movement = StockMovement(
          id: '',
          type: widget.type,
          productId: widget.product.id,
          quantity: widget.type == 'adjustment' ? quantity : (widget.type == 'purchase' ? qty : -qty),
          value: value,
          costValue: widget.type == 'sale' ? qty * widget.product.costPrice : null,
          date: DateTime.now(),
          reason: reason.isEmpty ? null : reason,
        );
        tx.set(movementsRef.doc(), movement.toFirestore());
      });

      ref.invalidate(productsProvider(widget.slug));
      ref.invalidate(stockMovementsProvider(widget.slug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimentação registrada!'), backgroundColor: Colors.green),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _title {
    switch (widget.type) {
      case 'purchase':
        return 'Entrada (compra)';
      case 'sale':
        return 'Saída / Venda';
      case 'adjustment':
        return 'Ajuste de estoque';
      default:
        return 'Movimentação';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdjustment = widget.type == 'adjustment';
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Produto: ${widget.product.name}', style: const TextStyle(color: Color(0xFF5C636A))),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyController,
            decoration: InputDecoration(
              labelText: isAdjustment ? 'Quantidade (+ ou -)' : 'Quantidade',
              hintText: isAdjustment ? 'Ex: -2 ou 3' : null,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (widget.type != 'purchase')
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
