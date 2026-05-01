import 'package:cloud_functions/cloud_functions.dart';

/// Resposta do cliente a um horário sugerido pelo dono (Cloud Function `clientRespondToAppointmentProposal`).
Future<void> clientRespondToAppointmentProposal({
  required String appointmentId,
  required bool accept,
}) async {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final callable = functions.httpsCallable('clientRespondToAppointmentProposal');
  await callable.call({
    'appointmentId': appointmentId,
    'accept': accept,
  });
}
