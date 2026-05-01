import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/providers/barber_shop_providers.dart';

/// Painel inferior: últimos atendimentos concluídos e movimentações de stock (vendas, uso serviço, etc.).
Future<void> showOwnerActivityLogBottomSheet(
  BuildContext context,
  WidgetRef ref,
  String slug,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (modalContext) {
      final padBottom = MediaQuery.paddingOf(modalContext).bottom;
      final height = MediaQuery.sizeOf(modalContext).height * 0.86;
      return SizedBox(
        height: height,
        child: OwnerActivityLogContent(slug: slug, bottomInset: padBottom),
      );
    },
  );
}

class OwnerActivityLogContent extends ConsumerWidget {
  const OwnerActivityLogContent({
    super.key,
    required this.slug,
    required this.bottomInset,
  });

  final String slug;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(appointmentsProvider(slug));
    final movesAsync = ref.watch(stockMovementsProvider(slug));
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registo da loja',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1D21),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atendimentos concluídos (com ou sem cliente) e movimentos que alteram produtos '
            '(vendas, consumo nos serviços, retirada para o studio…).',
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A), height: 1.35),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: apptsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Text('Erro ao carregar agendamentos: $e', style: const TextStyle(color: Colors.red)),
              data: (allAppts) {
                return movesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Erro ao carregar estoque: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (moves) => _UnifiedLogList(
                    appts: allAppts.where((a) => a.status == 'completed').toList(),
                    moves: moves,
                    dateFmt: df,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine {
  const _LogLine({required this.when, required this.title, required this.detail});
  final DateTime when;
  final String title;
  final String detail;
}

class _UnifiedLogList extends StatelessWidget {
  const _UnifiedLogList({
    required this.appts,
    required this.moves,
    required this.dateFmt,
  });

  final List<Appointment> appts;
  final List<StockMovement> moves;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final lines = <_LogLine>[];

    final sortedAppts = List<Appointment>.from(appts)
      ..sort((a, b) {
        final tb = b.completedAt ?? b.dateTime;
        final ta = a.completedAt ?? a.dateTime;
        return tb.compareTo(ta);
      });
    for (final a in sortedAppts.take(80)) {
      final when = a.completedAt ?? a.dateTime;
      final tipo = a.walkIn ? 'Atendimento avulso' : 'Agendamento concluído';
      lines.add(
        _LogLine(
          when: when,
          title: tipo,
          detail: '${a.clientName}: ${a.serviceName}',
        ),
      );
    }

    for (final m in moves.take(100)) {
      lines.add(
        _LogLine(
          when: m.date,
          title: _movementTitle(m.type),
          detail: _movementDetail(m),
        ),
      );
    }

    lines.sort((x, y) => y.when.compareTo(x.when));

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'Ainda sem registos. Conclua um atendimento na Agenda ou registre uma venda no Estoque.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280), height: 1.35),
        ),
      );
    }

    return ListView.separated(
      itemCount: lines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final l = lines[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          title: Text(
            l.title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            l.detail,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A), height: 1.3),
          ),
          trailing: Text(
            dateFmt.format(l.when),
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF9CA3AF)),
          ),
        );
      },
    );
  }

  static String _movementTitle(String type) {
    switch (type) {
      case 'sale':
        return 'Venda de produto';
      case 'service_use':
        return 'Baixa por serviço';
      case 'transfer_to_studio':
        return 'Retirada para o studio (+100%)';
      case 'purchase':
        return 'Entrada / compra';
      case 'adjustment':
        return 'Ajuste de estoque';
      default:
        return 'Movimento: $type';
    }
  }

  static String _movementDetail(StockMovement m) {
    final qty = m.quantity.abs();
    final rq = (m.reason ?? '').trim();
    if (rq.isNotEmpty) return '$rq (${m.quantity >= 0 ? '+' : '-'}${_fmtQty(qty)})';
    return 'Produto ${m.productId} (${m.quantity >= 0 ? '+' : '-'}${_fmtQty(qty)})';
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
