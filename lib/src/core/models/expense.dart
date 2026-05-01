import 'package:cloud_firestore/cloud_firestore.dart';

/// Despesa operacional mensal (aluguel, salário, luz, etc.) para DRE.
/// Subcoleção barbershops/{slug}/expenses.
class Expense {
  final String id;
  final int year;
  final int month;
  final String description;
  final double amount;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.year,
    required this.month,
    required this.description,
    required this.amount,
    this.createdAt,
  });

  factory Expense.fromFirestore(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      year: data['year'] as int? ?? DateTime.now().year,
      month: data['month'] as int? ?? DateTime.now().month,
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'year': year,
        'month': month,
        'description': description,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
