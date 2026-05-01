import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/barber_shop.dart';
import '../../../core/providers/barber_shop_providers.dart';

/// Agenda do funcionário: horários marcados com ele. Só exibe se estiver logado como staff.
class StaffAgendaPage extends ConsumerWidget {
  const StaffAgendaPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffState = ref.watch(currentStaffProvider);
    final barberShopAsync = ref.watch(barberShopBySlugProvider(slug));
    final appointmentsAsync = ref.watch(appointmentsProvider(slug));

    if (staffState == null || staffState.slug != slug) {
      return _LoginPrompt(slug: slug);
    }

    final staff = staffState.staff;

    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) {
          return const Center(child: Text('Negócio não encontrado'));
        }
        return appointmentsAsync.when(
          data: (allList) {
            final myList = allList
                .where((a) => a.staffId == staff.id && a.status != 'canceled')
                .toList();
            myList.sort((a, b) => a.dateTime.compareTo(b.dateTime));
            final now = DateTime.now();
            final proximos = myList.where((a) => a.dateTime.isAfter(now)).toList();
            final passados = myList.where((a) => !a.dateTime.isAfter(now)).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Horários com você',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${staff.name} • ${proximos.length} agendado(s)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF5C636A),
                  ),
                ),
                const SizedBox(height: 24),
                if (proximos.isEmpty && passados.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum horário marcado com você',
                          style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF5C636A)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (proximos.isNotEmpty) ...[
                    Text(
                      'Próximos',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D21),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...proximos.map((a) => _StaffAppointmentTile(appointment: a, shop: shop)),
                    const SizedBox(height: 24),
                  ],
                  if (passados.isNotEmpty) ...[
                    Text(
                      'Realizados',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...passados.map((a) => _StaffAppointmentTile(appointment: a, shop: shop)),
                  ],
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: primary),
            const SizedBox(height: 16),
            Text(
              'Área do funcionário',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Entre com o e-mail cadastrado pelo dono para ver os horários marcados com você.',
              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/b/$slug/funcionario'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Entrar como funcionário'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffAppointmentTile extends StatelessWidget {
  const _StaffAppointmentTile({required this.appointment, required this.shop});
  final Appointment appointment;
  final BarberShop shop;

  @override
  Widget build(BuildContext context) {
    final primary = shop.primaryColorAsColor;
    final dateStr = DateFormat('dd/MM').format(appointment.dateTime);
    final timeStr = DateFormat('HH:mm').format(appointment.dateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primary.withValues(alpha: 0.2),
          child: Text(
            timeStr.split(':').first,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
          ),
        ),
        title: Text(
          appointment.clientName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$dateStr às $timeStr • ${appointment.serviceName}',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(appointment.status).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusLabel(appointment.status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _statusColor(appointment.status),
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmado';
      case 'completed':
        return 'Realizado';
      case 'canceled':
        return 'Cancelado';
      default:
        return 'Agendado';
    }
  }
}
