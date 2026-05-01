import 'package:cloud_firestore/cloud_firestore.dart';

/// Avaliação do cliente após atendimento (subcoleção barbershops/{slug}/reviews).
class Review {
  final String id;
  final String appointmentId;
  final String? clientId;
  final String? staffId;
  /// Nota de 0 a 5 (estrelas).
  final int rating;
  final String? comment;
  final String? suggestion;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.appointmentId,
    this.clientId,
    this.staffId,
    this.rating = 0,
    this.comment,
    this.suggestion,
    this.createdAt,
  });

  factory Review.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return Review(
      id: id,
      appointmentId: data['appointmentId'] as String? ?? '',
      clientId: data['clientId'] as String?,
      staffId: data['staffId'] as String?,
      rating: data['rating'] as int? ?? 0,
      comment: data['comment'] as String?,
      suggestion: data['suggestion'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'appointmentId': appointmentId,
        if (clientId != null) 'clientId': clientId,
        if (staffId != null) 'staffId': staffId,
        'rating': rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        if (suggestion != null && suggestion!.isNotEmpty) 'suggestion': suggestion,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
