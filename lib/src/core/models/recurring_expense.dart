import 'package:cloud_firestore/cloud_firestore.dart';

/// Despesa fixa mensal (aluguel, software, etc.) até o dono desativar.
/// Subcoleção: barbershops/{slug}/recurring_expenses
class RecurringExpense {
  final String id;
  final String description;
  final double amount;
  final bool active;
  final DateTime? createdAt;

  const RecurringExpense({
    required this.id,
    required this.description,
    required this.amount,
    this.active = true,
    this.createdAt,
  });

  factory RecurringExpense.fromFirestore(String id, Map<String, dynamic> data) {
    return RecurringExpense(
      id: id,
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'description': description,
        'amount': amount,
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
