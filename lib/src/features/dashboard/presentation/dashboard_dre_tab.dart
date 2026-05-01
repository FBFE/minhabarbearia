import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/barber_shop.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/expense.dart';
import '../../../core/models/recurring_expense.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/providers/firebase_providers.dart';

const _revGreen = Color(0xFF16A34A);
const _expRed = Color(0xFFDC2626);
const _accentColor = _revGreen;
const _kpiOrange = Color(0xFFEA580C);
const _cardBorder = Color(0xFFE5E7EB);
const _textMuted = Color(0xFF5C636A);
const _textPrimary = Color(0xFF1A1D21);

/// Dados agregados de um mês para DRE.
class MonthDreData {
  final int year;
  final int month;
  double revenueServices = 0;
  double revenueProducts = 0;
  double cmv = 0; // custo produtos vendidos/usados
  double expenses = 0;
  /// Compras de estoque (entrada) no mês — investimento, não “despesa” do DRE.
  double stockInvestments = 0;
  /// Pagamentos da assinatura do app (Stripe) no mês — investimento operacional.
  double subscriptionSaaS = 0;

  MonthDreData(this.year, this.month);

  double get totalRevenue => revenueServices + revenueProducts;
  double get grossProfit => totalRevenue - cmv;
  double get netProfit => grossProfit - expenses;
}

/// Aba Relatórios / DRE do dashboard.
class DashboardDreTab extends ConsumerWidget {
  const DashboardDreTab({super.key, this.barberShop});

  final BarberShop? barberShop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (barberShop == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Crie ou vincule seu negócio para ver o painel financeiro.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C636A),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _DreContent(slug: barberShop!.slug, primaryColor: barberShop!.primaryColorAsColor),
    );
  }
}

class _DreContent extends ConsumerWidget {
  final String slug;
  final Color primaryColor;

  const _DreContent({required this.slug, required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider(slug));
    final movementsAsync = ref.watch(stockMovementsProvider(slug));
    final now = DateTime.now();
    final allExpensesAsync = ref.watch(allExpensesProvider(slug));
    final billingAsync = ref.watch(billingEventsProvider(slug));
    final recurringAsync = ref.watch(recurringExpensesProvider(slug));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        appointmentsAsync.when(
          data: (appointments) {
            return movementsAsync.when(
              data: (movements) {
                return allExpensesAsync.when(
                  data: (expenses) {
                    return billingAsync.when(
                      data: (billing) {
                        return recurringAsync.when(
                          data: (recurring) {
                            final dreByMonth = _computeDreByMonth(
                              appointments,
                              movements,
                              expenses,
                              billing,
                              recurring,
                              now,
                              6,
                            );
                            return _DreChartsAndMetrics(
                              slug: slug,
                              primaryColor: primaryColor,
                              now: now,
                              dreByMonth: dreByMonth,
                              onAddExpense: () => _showAddExpense(context, ref),
                              onManageRecurring: () => _showRecurringManager(
                                context,
                                ref,
                                slug,
                                primaryColor,
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(color: _accentColor),
                            ),
                          ),
                          error: (e, _) => Text('Erro despesas fixas: $e', style: const TextStyle(color: Colors.red)),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: _accentColor),
                        ),
                      ),
                      error: (e, _) => Text('Erro faturas app: $e', style: const TextStyle(color: Colors.red)),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: _accentColor),
                    ),
                  ),
                  error: (e, _) => Text('Erro despesas: $e', style: const TextStyle(color: Colors.red)),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _accentColor),
                ),
              ),
              error: (e, _) => Text('Erro movimentações: $e', style: const TextStyle(color: Colors.red)),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _accentColor),
            ),
          ),
          error: (e, _) => Text('Erro agendamentos: $e', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  List<MonthDreData> _computeDreByMonth(
    List<Appointment> appointments,
    List<StockMovement> movements,
    List<Expense> expenses,
    List<Map<String, dynamic>> billingEvents,
    List<RecurringExpense> recurring,
    DateTime now,
    int monthsCount,
  ) {
    final list = <MonthDreData>[];
    for (var i = monthsCount - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      if (d.isBefore(DateTime(now.year, now.month - 12))) continue;
      list.add(MonthDreData(d.year, d.month));
    }
    final byKey = {for (final m in list) '${m.year}-${m.month}': m};

    for (final a in appointments) {
      if (a.status != 'completed') continue;
      final ad = a.dateTime.toLocal();
      if (ad.isBefore(DateTime(now.year, now.month - 12, 1))) continue;
      final key = '${ad.year}-${ad.month}';
      final data = byKey[key];
      if (data != null) {
        final price = a.bookedRevenue;
        if (price > 0) data.revenueServices += price;
      }
    }

    for (final m in movements) {
      final md = m.date.toLocal();
      final key = '${md.year}-${md.month}';
      final data = byKey[key];
      if (data == null) continue;
      if (m.type == 'sale') {
        data.revenueProducts += m.value;
        data.cmv += m.costValue ?? 0;
      } else if (m.type == 'service_use') {
        data.cmv += m.value;
      } else if (m.type == 'purchase') {
        data.stockInvestments += m.value;
      }
    }

    for (final e in expenses) {
      final key = '${e.year}-${e.month}';
      final data = byKey[key];
      if (data != null) data.expenses += e.amount;
    }

    for (final ev in billingEvents) {
      if (ev['type'] != 'payment') continue;
      final t = ev['createdAt'];
      if (t is! Timestamp) continue;
      final d = t.toDate().toLocal();
      if (d.isBefore(DateTime(now.year, now.month - 12, 1))) continue;
      final key = '${d.year}-${d.month}';
      final data = byKey[key];
      if (data == null) continue;
      final a = ev['amount'];
      int cents = 0;
      if (a is int) {
        cents = a;
      } else if (a is num) {
        cents = a.toInt();
      }
      if (cents > 0) {
        data.subscriptionSaaS += cents / 100.0;
      }
    }

    for (final data in list) {
      for (final r in recurring) {
        if (r.active && r.amount > 0) {
          data.expenses += r.amount;
        }
      }
    }

    return list;
  }

  void _showAddExpense(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddExpenseSheet(
        slug: slug,
        primaryColor: primaryColor,
        onSaved: () {
          ref.invalidate(expensesProvider((slug: slug, year: DateTime.now().year, month: DateTime.now().month)));
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

void _showRecurringManager(
  BuildContext context,
  WidgetRef ref,
  String slug,
  Color primaryColor,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _RecurringManagerSheet(
      slug: slug,
      primaryColor: primaryColor,
    ),
  );
}

String _dreFormatMoney(double v) =>
    NumberFormat.currency(locale: "pt_BR", symbol: "R\$").format(v);

/// Rótulo curto no eixo Y (evita overflow).
String _dreFormatAxisY(double v) {
  if (v >= 1e6) {
    return "R\$ ${(v / 1e6).toStringAsFixed(1)} mi";
  }
  if (v >= 1e3) {
    return "R\$ ${(v / 1e3).toStringAsFixed(1)} k";
  }
  return _dreFormatMoney(v);
}

String _dreShortMonthLabel(MonthDreData m) {
  final d = DateTime(m.year, m.month, 1);
  return DateFormat("MMM/yy", "pt_BR").format(d);
}

String _dreMonthTitle(MonthDreData m) {
  final d = DateTime(m.year, m.month, 1);
  return DateFormat("MMMM yyyy", "pt_BR").format(d);
}

double _dreBarMaxY(List<MonthDreData> list) {
  var m = 0.0;
  for (final d in list) {
    if (d.totalRevenue > m) m = d.totalRevenue;
    if (d.expenses > m) m = d.expenses;
  }
  m = m * 1.15 + 20;
  return m < 100 ? 100 : m;
}

String? _drePctChange(double current, double previous) {
  if (previous.abs() < 0.01) return null;
  final p = ((current - previous) / previous.abs()) * 100;
  return "${p >= 0 ? "+" : ""}${p.toStringAsFixed(0)}%";
}

class _DreChartsAndMetrics extends StatefulWidget {
  final String slug;
  final Color primaryColor;
  final DateTime now;
  final List<MonthDreData> dreByMonth;
  final VoidCallback onAddExpense;
  final VoidCallback onManageRecurring;

  const _DreChartsAndMetrics({
    required this.slug,
    required this.primaryColor,
    required this.now,
    required this.dreByMonth,
    required this.onAddExpense,
    required this.onManageRecurring,
  });

  @override
  State<_DreChartsAndMetrics> createState() => _DreChartsAndMetricsState();
}

class _DreChartsAndMetricsState extends State<_DreChartsAndMetrics> {
  late int _monthIndex;

  @override
  void initState() {
    super.initState();
    _monthIndex = widget.dreByMonth.isEmpty ? 0 : widget.dreByMonth.length - 1;
  }

  @override
  void didUpdateWidget(covariant _DreChartsAndMetrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dreByMonth.isEmpty) {
      _monthIndex = 0;
    } else if (widget.dreByMonth.length != oldWidget.dreByMonth.length ||
        _monthIndex >= widget.dreByMonth.length) {
      _monthIndex = widget.dreByMonth.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.dreByMonth;
    if (list.isEmpty) {
      return Text(
        "Nenhum dado no período.",
        style: GoogleFonts.poppins(color: _textMuted, fontSize: 14),
      );
    }
    final sel = list[_monthIndex];
    final prevM = _monthIndex > 0 ? list[_monthIndex - 1] : null;
    final barMaxY = _dreBarMaxY(list);
    final monthLabels = list.map((m) => _dreShortMonthLabel(m)).toList();
    final margin = sel.totalRevenue > 0.01 ? (sel.netProfit / sel.totalRevenue) * 100 : 0.0;

    final revDelta = prevM != null ? _drePctChange(sel.totalRevenue, prevM.totalRevenue) : null;
    final expDelta = prevM != null ? _drePctChange(sel.expenses, prevM.expenses) : null;

    final nowClock = widget.now;
    final isCurrentMonth =
        sel.year == nowClock.year && sel.month == nowClock.month;
    double? projectedNextMonthNet;
    if (isCurrentMonth && nowClock.day > 0) {
      final avgDaily = sel.netProfit / nowClock.day;
      final nextM = sel.month == 12 ? 1 : sel.month + 1;
      final nextY = sel.month == 12 ? sel.year + 1 : sel.year;
      final daysNext = DateTime(nextY, nextM + 1, 0).day;
      projectedNextMonthNet = avgDaily * daysNext;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, cc) {
            final narrow = cc.maxWidth < 420;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Relatórios",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Visão geral financeira",
                  style: GoogleFonts.poppins(fontSize: 14, color: _textMuted),
                ),
              ],
            );
            final controls = <Widget>[
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _monthIndex.clamp(0, list.length - 1),
                    style: GoogleFonts.poppins(fontSize: 12, color: _textPrimary),
                    items: List.generate(
                      list.length,
                      (i) {
                        final m = list[i];
                        final last = i == list.length - 1;
                        return DropdownMenuItem(
                          value: i,
                          child: Text(
                            last ? "Este mês — ${_dreMonthTitle(m)}" : _dreMonthTitle(m),
                            style: GoogleFonts.poppins(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        );
                      },
                    ),
                    onChanged: (v) {
                      if (v != null) setState(() => _monthIndex = v);
                    },
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onAddExpense,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text("Despesa", style: GoogleFonts.poppins(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onManageRecurring,
                icon: const Icon(Icons.event_repeat_rounded, size: 16),
                label: Text("Fixa mensal", style: GoogleFonts.poppins(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: _textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                ),
              ),
            ];
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ...controls,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: titleBlock),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: controls,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 520;
            final kpi = [
              _DreKpiCard(
                label: "Receita Bruta",
                labelColor: _revGreen,
                icon: Icons.attach_money_rounded,
                iconBg: const Color(0xFFDCFCE7),
                value: _dreFormatMoney(sel.totalRevenue),
                sub: revDelta != null ? "$revDelta vs mês anterior" : null,
                subColor: _revGreen,
                arrowUp: revDelta == null
                    ? null
                    : (sel.totalRevenue >= (prevM?.totalRevenue ?? 0)),
              ),
              _DreKpiCard(
                label: "Despesas",
                labelColor: _expRed,
                icon: Icons.account_balance_wallet_outlined,
                iconBg: const Color(0xFFFEE2E2),
                value: _dreFormatMoney(sel.expenses),
                sub: expDelta != null ? "$expDelta vs mês anterior" : null,
                subColor: _expRed,
                arrowUp: expDelta == null
                    ? null
                    : (sel.expenses >= (prevM?.expenses ?? 0)),
              ),
              _DreKpiCard(
                label: "Lucro Líquido",
                labelColor: _kpiOrange,
                icon: Icons.bar_chart_rounded,
                iconBg: const Color(0xFFFFEDD5),
                value: _dreFormatMoney(sel.netProfit),
                sub: "Margem de ${margin.toStringAsFixed(1)}%",
                subColor: _kpiOrange,
                useOrangeBorder: true,
              ),
            ];
            if (narrow) {
              return Column(
                children: [
                  for (var i = 0; i < kpi.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    kpi[i],
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < kpi.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: kpi[i]),
                ],
              ],
            );
          },
        ),
        if (sel.stockInvestments > 0.01) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              "Investimento em estoque (compras no mês): ${_dreFormatMoney(sel.stockInvestments)}",
              style: GoogleFonts.poppins(fontSize: 12, color: _textMuted, height: 1.3),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
          child: Text(
            "CMV (custo de produtos em serviços e vendas): ${_dreFormatMoney(sel.cmv)}",
            style: GoogleFonts.poppins(fontSize: 12, color: _textMuted, height: 1.3),
          ),
        ),
        if (sel.subscriptionSaaS > 0.01) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              "Investimento app (assinatura paga no mês): ${_dreFormatMoney(sel.subscriptionSaaS)}",
              style: GoogleFonts.poppins(fontSize: 12, color: _textMuted, height: 1.3),
            ),
          ),
        ],
        if (projectedNextMonthNet != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights_rounded, color: widget.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Projeção: mantendo a média diária de lucro deste mês (${nowClock.day} ${nowClock.day == 1 ? "dia" : "dias"}), '
                    'o lucro líquido estimado no próximo mês seria de ${_dreFormatMoney(projectedNextMonthNet)}.',
                    style: GoogleFonts.poppins(fontSize: 12, color: _textPrimary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _ChartCard(
          title: "Receita vs Despesas (Últimos 6 meses)",
          legend: const [
            _LegendItem(color: _revGreen, label: "Receita bruta"),
            _LegendItem(color: _expRed, label: "Despesas"),
          ],
          child: SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: barMaxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 200,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = list[group.x.toInt().clamp(0, list.length - 1)];
                      return BarTooltipItem(
                        'Receita: ${_dreFormatMoney(d.totalRevenue)}\nDespesas: ${_dreFormatMoney(d.expenses)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 64,
                      interval: barMaxY > 0 ? (barMaxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _dreFormatAxisY(v),
                            style: GoogleFonts.poppins(fontSize: 9, color: _textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (i, meta) {
                        final idx = i.toInt();
                        if (idx >= 0 && idx < monthLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 44,
                              child: Text(
                                monthLabels[idx],
                                style: GoogleFonts.poppins(fontSize: 9, color: _textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: barMaxY > 0 ? barMaxY / 4 : 1,
                  getDrawingHorizontalLine: (v) => FlLine(color: _cardBorder.withValues(alpha: 0.5), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < list.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: list[i].totalRevenue,
                          color: _revGreen,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: list[i].expenses,
                            color: _expRed.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ],
    );
  }
}

class _DreKpiCard extends StatelessWidget {
  const _DreKpiCard({
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.iconBg,
    required this.value,
    this.sub,
    this.subColor,
    this.arrowUp,
    this.useOrangeBorder = false,
  });

  final String label;
  final Color labelColor;
  final IconData icon;
  final Color iconBg;
  final String value;
  final String? sub;
  final Color? subColor;
  final bool? arrowUp;
  final bool useOrangeBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: useOrangeBorder ? _kpiOrange : _cardBorder,
          width: useOrangeBorder ? 1.5 : 1,
        ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: labelColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (arrowUp != null) ...[
                  Icon(
                    arrowUp! ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: subColor ?? _textMuted,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    sub!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: subColor ?? _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    this.legend = const [],
    required this.child,
  });

  final String title;
  final List<_LegendItem> legend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            child,
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < legend.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _LegendDot(color: legend[i].color),
                    const SizedBox(width: 6),
                    Text(
                      legend[i].label,
                      style: GoogleFonts.poppins(fontSize: 12, color: _textMuted),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
}

class _LegendDot extends StatelessWidget {
  final Color color;

  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String slug;
  final Color primaryColor;
  final VoidCallback onSaved;

  const _AddExpenseSheet({
    required this.slug,
    required this.primaryColor,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição da despesa')),
      );
      return;
    }
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor (R\$)')),
      );
      return;
    }
    final now = DateTime.now();
    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final expense = Expense(
        id: '',
        year: now.year,
        month: now.month,
        description: desc,
        amount: amount,
        createdAt: now,
      );
      await firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('expenses')
          .add(expense.toFirestore());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Despesa adicionada!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Adicionar despesa',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aluguel, salário, luz, etc. Será contabilizado no mês atual.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5C636A)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'Ex: Aluguel, Luz',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Valor (R\$)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    );
  }
}

class _RecurringManagerSheet extends ConsumerStatefulWidget {
  const _RecurringManagerSheet({
    required this.slug,
    required this.primaryColor,
  });
  final String slug;
  final Color primaryColor;

  @override
  ConsumerState<_RecurringManagerSheet> createState() => _RecurringManagerSheetState();
}

class _RecurringManagerSheetState extends ConsumerState<_RecurringManagerSheet> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição (ex: aluguel).')),
      );
      return;
    }
    final v = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor mensal (R\$).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final r = RecurringExpense(
        id: '',
        description: desc,
        amount: v,
        active: true,
      );
      await firestore
          .collection(barbershopsCollection)
          .doc(widget.slug)
          .collection('recurring_expenses')
          .add(r.toFirestore());
      ref.invalidate(recurringExpensesProvider(widget.slug));
      _desc.clear();
      _amount.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Despesa fixa adicionada.'), backgroundColor: Colors.green),
        );
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

  Future<void> _setActive(String id, bool active) async {
    final firestore = ref.read(firestoreProvider);
    await firestore
        .collection(barbershopsCollection)
        .doc(widget.slug)
        .collection('recurring_expenses')
        .doc(id)
        .update({'active': active});
    ref.invalidate(recurringExpensesProvider(widget.slug));
  }

  Future<void> _remove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover despesa fixa?'),
        content: const Text('Para de contabilizar nos próximos meses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final firestore = ref.read(firestoreProvider);
    await firestore
        .collection(barbershopsCollection)
        .doc(widget.slug)
        .collection('recurring_expenses')
        .doc(id)
        .delete();
    ref.invalidate(recurringExpensesProvider(widget.slug));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recurringExpensesProvider(widget.slug));
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Despesas fixas (mensal)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ex.: aluguel. O valor some automaticamente em todo mês do relatório até desativar ou excluir.',
              style: GoogleFonts.poppins(fontSize: 12, color: _textMuted, height: 1.3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Valor por mês (R\$)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _add,
              style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Incluir fixa'),
            ),
            const SizedBox(height: 20),
            Text(
              'Suas contas fixas',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            listAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Text(
                    'Nenhuma ainda — use o formulário acima.',
                    style: GoogleFonts.poppins(fontSize: 13, color: _textMuted),
                  );
                }
                return Column(
                  children: items.map((e) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          e.description,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          e.active
                              ? '${_dreFormatMoney(e.amount)} / mês (ativa)'
                              : 'Pausada — não entra no mês',
                          style: GoogleFonts.poppins(fontSize: 12, color: _textMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: e.active,
                              onChanged: (v) => _setActive(e.id, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: _expRed),
                              onPressed: () => _remove(e.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Erro: $e'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
