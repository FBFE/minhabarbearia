import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/appointment.dart';
import '../../../core/models/barber_shop.dart';
import '../../../core/models/client.dart';
import '../../../core/providers/barber_shop_providers.dart';
import '../../../core/utils/client_appointment_callables.dart';
import '../../../core/providers/firebase_providers.dart';
import 'public_shop_hero_header.dart';

/// Minha Agenda: lista de agendamentos com progress bar (Agendado → Confirmado → Realizado).
class ClientAgendaPage extends ConsumerWidget {
  const ClientAgendaPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(currentPublicClientProvider);
    final barberShopAsync = ref.watch(barberShopBySlugProvider(slug));
    if (clientState == null || clientState.slug != slug) {
      return _VerifyFirstView(slug: slug);
    }
    final client = clientState.client;
    final appointmentsAsync = ref.watch(appointmentsForClientProvider((
      slug: slug,
      clientWhatsapp: client.whatsapp,
    )));
    final reviewsAsync = ref.watch(reviewsProvider(slug));
    final reviewedIds = reviewsAsync.valueOrNull?.map((r) => r.appointmentId).toSet() ?? {};
    return barberShopAsync.when(
      data: (shop) {
        if (shop == null) return const Scaffold(body: Center(child: Text('Negócio não encontrado')));
        final primary = shop.primaryColorAsColor;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: appointmentsAsync.when(
            data: (list) {
              final now = DateTime.now();
              final agendados = list.where((a) {
                if (a.status == 'canceled' || a.status == 'completed') return false;
                if (a.proposedDateTime != null) return true;
                return a.dateTime.isAfter(now);
              }).toList();
              agendados.sort((a, b) => a.dateTime.compareTo(b.dateTime));
              final historico = list.where((a) {
                if (a.status == 'canceled' || a.status == 'completed') return true;
                if (a.proposedDateTime != null) return false;
                return !a.dateTime.isAfter(now);
              }).toList();
              historico.sort((a, b) => b.dateTime.compareTo(a.dateTime));

              Future<void> refreshAgenda() async {
                ref.invalidate(
                  appointmentsForClientProvider((
                    slug: slug,
                    clientWhatsapp: client.whatsapp,
                  )),
                );
                ref.invalidate(reviewsProvider(slug));
                ref.invalidate(clientInShopByIdStreamProvider((
                  slug: slug,
                  clientId: client.id,
                )));
              }

              Widget listOrEmpty(
                String emptyMsg,
                List<Appointment> items, {
                bool showActions = false,
                bool? Function(Appointment)? reviewedFor,
              }) {
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: refreshAgenda,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                emptyMsg,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF5C636A),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: refreshAgenda,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: items.map((a) {
                      return _AppointmentCard(
                        isUpcoming: showActions,
                        appointment: a,
                        barberShop: shop,
                        slug: slug,
                        client: client,
                        clientId: client.id,
                        alreadyReviewed: reviewedFor?.call(a) ?? false,
                        onReview: () => _showReviewDialog(context, ref, slug, client.id, a),
                        onCancel: showActions
                            ? () => _cancelAppointment(context, ref, a.id, slug, client.whatsapp)
                            : null,
                        onReschedule: showActions
                            ? () {
                                context.go('/b/$slug/agendar');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Escolha o novo horário na página de agendamento.'),
                                  ),
                                );
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                );
              }

              if (agendados.isEmpty && historico.isEmpty) {
                return Column(
                  children: [
                    PublicShopHeroHeader(shop: shop, primary: primary, height: 180, overlayOnly: true),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: refreshAgenda,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 64,
                                    color: const Color(0xFF5C636A),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum agendamento',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: const Color(0xFF5C636A),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: () => context.go('/b/$slug/agendar'),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Agendar'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PublicShopHeroHeader(shop: shop, primary: primary, height: 180, overlayOnly: true),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua Agenda',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1D21),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Acompanhe seus horários',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: const Color(0xFF5C636A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5E5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
                          labelColor: const Color(0xFF1A1D21),
                          unselectedLabelColor: const Color(0xFF5C636A),
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          tabs: const [
                            Tab(text: 'Próximos'),
                            Tab(text: 'Histórico'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          listOrEmpty('Nada agendado à frente.', agendados, showActions: true),
                          listOrEmpty(
                            'Nenhum histórico ainda.',
                            historico,
                            showActions: false,
                            reviewedFor: (a) => reviewedIds.contains(a.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: primary)),
            error: (e, _) => Center(
              child: Text('Erro: $e', style: const TextStyle(color: Color(0xFF5C636A))),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(child: CircularProgressIndicator(color: const Color(0xFFFF4081))),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
    );
  }
}

class _VerifyFirstView extends StatelessWidget {
  const _VerifyFirstView({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_rounded, size: 64, color: const Color(0xFF5C636A)),
              const SizedBox(height: 16),
              Text(
                'Verifique seu cadastro',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1D21)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Na página de agendamento, use Entrar ou Cadastrar e faça login com sua conta Google (versão web do link).',
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5C636A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/b/$slug/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Entrar com Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/b/$slug/agendar'),
                child: Text('Ir para página inicial', style: GoogleFonts.poppins(color: const Color(0xFF5C636A))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _cancelAppointment(BuildContext context, WidgetRef ref, String appointmentId, String slug, String clientWhatsapp) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancelar agendamento?'),
      content: const Text('O agendamento será cancelado. Você pode fazer um novo na página de agendamento.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Sim, cancelar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('appointments').doc(appointmentId).update({
      'status': 'canceled',
      'canceledBy': 'client',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(appointmentsForClientProvider((slug: slug, clientWhatsapp: clientWhatsapp)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento cancelado.'), backgroundColor: Colors.orange),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }
}

void _showReviewDialog(BuildContext context, WidgetRef ref, String slug, String clientId, Appointment appointment) {
  int rating = 0;
  final commentController = TextEditingController();
  final suggestionController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Avaliar atendimento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Como foi seu atendimento? (opcional)', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < rating ? Icons.star : Icons.star_border, size: 36, color: Colors.amber),
                  onPressed: () => setState(() => rating = i + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: suggestionController,
                decoration: const InputDecoration(
                  labelText: 'Sugestão de melhoria (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final firestore = ref.read(firestoreProvider);
              await firestore.collection(barbershopsCollection).doc(slug).collection('reviews').add({
                'appointmentId': appointment.id,
                'clientId': clientId,
                if (appointment.staffId != null) 'staffId': appointment.staffId,
                'rating': rating,
                if (commentController.text.trim().isNotEmpty) 'comment': commentController.text.trim(),
                if (suggestionController.text.trim().isNotEmpty) 'suggestion': suggestionController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              ref.invalidate(reviewsProvider(slug));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Obrigado pela avaliação!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({
    required this.isUpcoming,
    required this.appointment,
    required this.barberShop,
    required this.slug,
    required this.client,
    required this.clientId,
    required this.alreadyReviewed,
    required this.onReview,
    this.onCancel,
    this.onReschedule,
  });
  final bool isUpcoming;
  final Appointment appointment;
  final BarberShop barberShop;
  final String slug;
  final Client client;
  final String clientId;
  final bool alreadyReviewed;
  final VoidCallback onReview;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  static const _border = Color(0xFFE5E5E5);

  String _dow3(DateTime d) {
    const w = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return w[(d.weekday - 1) % 7];
  }

  String _formatDuration(int m) {
    if (m >= 60) {
      final h = m ~/ 60;
      final r = m % 60;
      if (r == 0) return '${h}h';
      return '${h}h ${r}min';
    }
    return '$m min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = barberShop.primaryColorAsColor;
    final timeStr = DateFormat('HH:mm').format(appointment.dateTime);
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final price = appointment.bookedRevenue;
    if (!isUpcoming) {
      final prof = (appointment.staffName != null && appointment.staffName!.trim().isNotEmpty)
          ? 'Com ${appointment.staffName!.trim()}'
          : '';
      Color badgeBg;
      Color badgeFg;
      String badgeText;
      if (appointment.status == 'canceled') {
        badgeBg = const Color(0xFFFFEBEE);
        badgeFg = const Color(0xFFC62828);
        badgeText = 'Cancelado';
      } else if (appointment.status == 'completed') {
        badgeBg = const Color(0xFFE6F4EA);
        badgeFg = const Color(0xFF34A853);
        badgeText = 'Realizado';
      } else {
        badgeBg = primary.withValues(alpha: 0.12);
        badgeFg = primary;
        badgeText = 'Concluído';
      }
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appointment.serviceName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1D21),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reservado para: ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(appointment.originalDateTime ?? appointment.dateTime)}',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
              ),
              if (appointment.status == 'completed' && appointment.completedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Realizado em: ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(appointment.completedAt!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1D21),
                    ),
                  ),
                ),
              if (appointment.status != 'completed' &&
                  appointment.status != 'canceled' &&
                  appointment.completedAt == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Horário previsto no calendário: ${DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(appointment.dateTime)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8E9399)),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: _border),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeFg,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (prof.isNotEmpty)
                    Text(
                      prof,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF5C636A),
                      ),
                    ),
                ],
              ),
              if (appointment.status == 'completed') ...[
                const SizedBox(height: 8),
                alreadyReviewed
                    ? Text(
                        'Avaliação enviada.',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF34A853)),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onReview,
                          icon: const Icon(Icons.star_border_rounded, size: 18),
                          label: const Text('Avaliar atendimento'),
                        ),
                      ),
              ],
            ],
          ),
        ),
      );
    }

    // Próximos
    final statusUpcoming = appointment.proposedDateTime != null
        ? 'SUGESTÃO'
        : (appointment.status == 'confirmed' ? 'CONFIRMADO' : 'AGENDADO');
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dow3(appointment.dateTime),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      Text(
                        '${appointment.dateTime.day}',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barberShop.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: const Color(0xFF5C636A)),
                          const SizedBox(width: 4),
                          Text(
                            '$timeStr (${_formatDuration(appointment.durationMinutes)})',
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5C636A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusUpcoming,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: _border),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.content_cut_rounded, size: 20, color: const Color(0xFF5C636A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appointment.serviceName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1D21),
                    ),
                  ),
                ),
                Text(
                  money.format(price),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1D21),
                  ),
                ),
              ],
            ),
            if (appointment.proposedDateTime != null) ...[
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nova sugestão de horário',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat("dd/MM/yyyy 'às' HH:mm", "pt_BR").format(appointment.proposedDateTime!),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1D21),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (client.authUid != null &&
                          client.authUid!.isNotEmpty &&
                          client.authUid == FirebaseAuth.instance.currentUser?.uid) ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  try {
                                    await clientRespondToAppointmentProposal(
                                      appointmentId: appointment.id,
                                      accept: true,
                                    );
                                    ref.invalidate(appointmentsForClientProvider((
                                      slug: slug,
                                      clientWhatsapp: client.whatsapp,
                                    )));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Horário confirmado!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Não foi possível confirmar: $e'),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Confirmar horário'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await clientRespondToAppointmentProposal(
                                      appointmentId: appointment.id,
                                      accept: false,
                                    );
                                    ref.invalidate(appointmentsForClientProvider((
                                      slug: slug,
                                      clientWhatsapp: client.whatsapp,
                                    )));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Sugestão recusada. Seu horário atual mantém-se.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro: $e'),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Recusar'),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          'Associe sua conta Google (Perfil ou login) para confirmar ou recusar aqui.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5C636A), height: 1.35),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (onCancel != null && onReschedule != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onReschedule,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Reagendar',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1D21),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onCancel,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
