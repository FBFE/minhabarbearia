import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appointment.dart';
import '../models/barber_shop.dart';
import '../models/client.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../models/staff.dart';
import '../models/stock_movement.dart';
import '../models/voucher.dart';
import '../models/review.dart';
import '../models/recurring_expense.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';

/// Coleção no Firestore: barbershops (doc id = slug).
const String barbershopsCollection = 'barbershops';

/// Negócio do usuário logado (query por ownerUid).
final barberShopProvider = FutureProvider<BarberShop?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final firestore = ref.watch(firestoreProvider);
  final query = await firestore
      .collection(barbershopsCollection)
      .where('ownerUid', isEqualTo: user.uid)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return null;
  return BarberShop.fromFirestore(query.docs.first);
});

/// Histórico de pagamentos e reembolsos (`billingEvents` no Firestore).
final billingEventsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('billingEvents')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => {
                'id': d.id,
                ...d.data(),
              },
            )
            .toList(),
      );
});

/// Negócio público por slug (doc id = slug) — atualiza em tempo real (fundo da página, etc.).
final barberShopBySlugProvider =
    StreamProvider.family<BarberShop?, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return BarberShop.fromFirestore(doc);
  });
});

/// Serviços do negócio (subcoleção barbershops/{slug}/services).
final servicesProvider =
    StreamProvider.family<List<Service>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('services')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Service.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Parâmetros para appointments do dia (opcional: filtrar por staffId).
typedef AppointmentsForDayParams = ({String slug, DateTime date, String? staffId});

/// Appointments do dia para um negócio (para calcular slots livres) — **stream** para
/// horários atualizarem em tempo real quando o dono ou outro cliente agenda.
/// Se [staffId] for passado, só considera agendamentos daquele funcionário.
final appointmentsForDayProvider =
    StreamProvider.family<List<Map<String, dynamic>>, AppointmentsForDayParams>(
  (ref, params) {
    final firestore = ref.watch(firestoreProvider);
    final startOfDay = DateTime(params.date.year, params.date.month, params.date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return firestore
        .collection('appointments')
        .where('barberShopId', isEqualTo: params.slug)
        .snapshots()
        .map((snap) {
      final list = <Map<String, dynamic>>[];
      final staffId = params.staffId;
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        if (status == 'canceled') continue;
        final dt = (data['dateTime'] as Timestamp?)?.toDate();
        if (dt == null || dt.isBefore(startOfDay) || !dt.isBefore(endOfDay)) continue;
        if (staffId != null) {
          final aptStaffId = data['staffId'] as String?;
          if (aptStaffId != staffId) continue;
        }
        var dur = (data['durationMinutes'] as int?) ?? 30;
        final rawServices = data['services'] as List<dynamic>?;
        if (rawServices != null && rawServices.isNotEmpty) {
          var sum = 0;
          for (final e in rawServices) {
            if (e is Map<String, dynamic> && e['durationMinutes'] != null) {
              sum += (e['durationMinutes'] as num).toInt();
            }
          }
          if (sum > 0) dur = sum;
        }
        void addBlock(DateTime start, int minutes) {
          list.add({'dateTime': start, 'durationMinutes': minutes});
        }

        addBlock(dt, dur);
        final prop = data['proposedDateTime'] as Timestamp?;
        if (prop != null) {
          final pdt = prop.toDate();
          if (!pdt.isBefore(startOfDay) && pdt.isBefore(endOfDay)) {
            addBlock(pdt, dur);
          }
        }
      }
      return list;
    });
  },
);

/// Cliente (doc em barbershops/{slug}/clients) em tempo real — pontos, visitas, etc.
/// [clientId] vazio: stream vazio (para `ref.listen` seguro no shell sem cliente).
final clientInShopByIdStreamProvider =
    StreamProvider.family<Client?, ({String slug, String clientId})>(
  (ref, params) {
    if (params.clientId.isEmpty) {
      return const Stream<Client?>.empty();
    }
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('clients')
        .doc(params.clientId)
        .snapshots()
        .map((s) {
      if (!s.exists || s.data() == null) {
        return null;
      }
      return Client.fromFirestore(s.id, s.data()!);
    });
  },
);

/// Funcionários do negócio (subcoleção barbershops/{slug}/staff).
final staffProvider =
    StreamProvider.family<List<Staff>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('staff')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Staff.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Avaliações do negócio (subcoleção barbershops/{slug}/reviews).
final reviewsProvider =
    StreamProvider.family<List<Review>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('reviews')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Review.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Cliente por WhatsApp + Data de Nascimento (busca em barbershops/{slug}/clients).
final clientByPhoneAndDobProvider =
    FutureProvider.family<Client?, ({String slug, String phone, String dob})>(
  (ref, params) async {
    final firestore = ref.watch(firestoreProvider);
    final snap = await firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('clients')
        .where('whatsapp', isEqualTo: params.phone)
        .where('dateOfBirth', isEqualTo: params.dob)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Client.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  },
);

/// Cliente por UID do Firebase Auth (doc id = authUid em barbershops/{slug}/clients).
final clientByAuthUidProvider =
    FutureProvider.family<Client?, ({String slug, String authUid})>(
  (ref, params) async {
    if (params.authUid.isEmpty) return null;
    final firestore = ref.watch(firestoreProvider);
    final doc = await firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('clients')
        .doc(params.authUid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return Client.fromFirestore(doc.id, doc.data()!);
  },
);

/// Quantidade de clientes que um dado cliente indicou (referredByWhatsapp == whatsapp).
final referralCountProvider =
    FutureProvider.family<int, ({String slug, String whatsapp})>(
  (ref, params) async {
    final firestore = ref.watch(firestoreProvider);
    final snap = await firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('clients')
        .where('referredByWhatsapp', isEqualTo: params.whatsapp)
        .count()
        .get();

    return snap.count ?? 0;
  },
);

/// Clientes do negócio (subcoleção barbershops/{slug}/clients).
final clientsProvider =
    StreamProvider.family<List<Client>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('clients')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Client.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Voucher por código (barbershops/{slug}/vouchers onde code == código, ativo e não expirado).
final voucherByCodeProvider =
    FutureProvider.family<Voucher?, ({String slug, String code})>(
  (ref, params) async {
    final code = params.code.trim().toUpperCase();
    if (code.isEmpty) return null;

    final firestore = ref.watch(firestoreProvider);
    final snap = await firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('vouchers')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final v = Voucher.fromFirestore(snap.docs.first.id, snap.docs.first.data());
    return v.isValid ? v : null;
  },
);

/// Vouchers disponíveis para um cliente (gerados por pontos, não usados).
final vouchersForClientProvider =
    FutureProvider.family<List<Voucher>, ({String slug, String clientWhatsapp})>(
  (ref, params) async {
    final firestore = ref.watch(firestoreProvider);
    final snap = await firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('vouchers')
        .where('clientWhatsapp', isEqualTo: params.clientWhatsapp)
        .where('generatedFromPoints', isEqualTo: true)
        .get();

    final list = snap.docs
        .map((doc) => Voucher.fromFirestore(doc.id, doc.data()))
        .where((v) => v.isAvailableFor(params.clientWhatsapp))
        .toList();
    return list;
  },
);

/// Lista de vouchers do negócio (dashboard).
final vouchersProvider =
    StreamProvider.family<List<Voucher>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('vouchers')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Voucher.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Agendamentos do negócio (collection appointments).
final appointmentsProvider =
    StreamProvider.family<List<Appointment>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('appointments')
      .where('barberShopId', isEqualTo: slug)
      .orderBy('dateTime', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Appointment.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Cliente verificado na página pública (para navegação agenda/fidelidade/perfil).
/// Definido quando o cliente verifica cadastro em /b/:slug.
final currentPublicClientProvider =
    StateProvider<({String slug, Client client})?>((ref) => null);

/// Funcionário logado na página pública (para ver agenda de horários com ele).
/// Definido quando o funcionário entra em /b/:slug/funcionario com Google.
final currentStaffProvider =
    StateProvider<({String slug, Staff staff})?>((ref) => null);

/// Agendamentos de um cliente no negócio (filtra por clientWhatsapp).
final appointmentsForClientProvider =
    StreamProvider.family<List<Appointment>, ({String slug, String clientWhatsapp})>(
  (ref, params) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('appointments')
        .where('barberShopId', isEqualTo: params.slug)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromFirestore(doc.id, doc.data()))
            .where((a) => a.clientWhatsapp == params.clientWhatsapp)
            .toList());
  },
);

/// Produtos do estoque (subcoleção barbershops/{slug}/products).
final productsProvider =
    StreamProvider.family<List<Product>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('products')
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((doc) => Product.fromFirestore(doc.id, doc.data()))
            .toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });
});

/// Movimentações de estoque (subcoleção barbershops/{slug}/stock_movements).
final stockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('stock_movements')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => StockMovement.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Despesas operacionais (subcoleção barbershops/{slug}/expenses) de um mês.
final expensesProvider =
    StreamProvider.family<List<Expense>, ({String slug, int year, int month})>(
  (ref, params) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection(barbershopsCollection)
        .doc(params.slug)
        .collection('expenses')
        .where('year', isEqualTo: params.year)
        .where('month', isEqualTo: params.month)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Expense.fromFirestore(doc.id, doc.data()))
            .toList());
  },
);

/// Todas as despesas do negócio (para DRE - filtrar por mês no cliente).
final allExpensesProvider =
    StreamProvider.family<List<Expense>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('expenses')
      .snapshots()
      .map((snap) => snap.docs
            .map((doc) => Expense.fromFirestore(doc.id, doc.data()))
            .toList());
});

/// Despesas fixas mensais (até desativar) — aluguel, contas, etc.
final recurringExpensesProvider =
    StreamProvider.family<List<RecurringExpense>, String>((ref, slug) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(barbershopsCollection)
      .doc(slug)
      .collection('recurring_expenses')
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => RecurringExpense.fromFirestore(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.description.toLowerCase().compareTo(b.description.toLowerCase()));
    return list;
  });
});
