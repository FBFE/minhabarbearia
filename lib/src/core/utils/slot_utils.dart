/// Horário de funcionamento (hardcoded).
const int slotStartHour = 9;
const int slotEndHour = 19;
const int slotStepMinutes = 30;

/// Gera slots de horário como strings HH:mm para um dia.
/// [open] e [close] no formato "HH:mm" (ex: "09:00", "19:00").
List<String> generateTimeSlots(
  DateTime date,
  String open,
  String close, {
  int slotMinutes = 30,
}) {
  final openParts = open.split(':');
  final closeParts = close.split(':');
  final startH = int.tryParse(openParts.first) ?? 9;
  final startM = openParts.length > 1 ? (int.tryParse(openParts[1]) ?? 0) : 0;
  final endH = int.tryParse(closeParts.first) ?? 19;
  final endM = closeParts.length > 1 ? (int.tryParse(closeParts[1]) ?? 0) : 0;

  final slots = <String>[];
  var h = startH;
  var m = startM;
  while (h < endH || (h == endH && m < endM)) {
    slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    m += slotMinutes;
    if (m >= 60) {
      m -= 60;
      h++;
    }
  }
  return slots;
}

/// Gera slots de horário para um dia. Se [openTime]/[closeTime] forem passados ("HH:mm"), usa esses horários.
List<DateTime> generateSlotsForDay(
  DateTime day, {
  String? openTime,
  String? closeTime,
}) {
  int startH = slotStartHour;
  int endH = slotEndHour;
  if (openTime != null || closeTime != null) {
    final open = openTime ?? '09:00';
    final close = closeTime ?? '19:00';
    final op = open.split(':');
    final cl = close.split(':');
    startH = int.tryParse(op.first) ?? 9;
    endH = int.tryParse(cl.first) ?? 19;
  }
  final slots = <DateTime>[];
  for (var h = startH; h < endH; h++) {
    for (var m = 0; m < 60; m += slotStepMinutes) {
      slots.add(DateTime(day.year, day.month, day.day, h, m));
    }
  }
  return slots;
}

/// Retorna os slots que estão livres. [openTime]/[closeTime] no formato "HH:mm" (do negócio).
List<DateTime> freeSlots({
  required DateTime day,
  required int serviceDurationMinutes,
  required List<Map<String, dynamic>> appointments,
  String? openTime,
  String? closeTime,
}) {
  final allSlots = generateSlotsForDay(day, openTime: openTime, closeTime: closeTime);
  int endHour = slotEndHour;
  if (closeTime != null) {
    final cl = closeTime.split(':');
    endHour = int.tryParse(cl.first) ?? 19;
  }
  final now = DateTime.now();
  return allSlots.where((slot) {
    if (slot.isBefore(now)) return false;
    final slotEnd = slot.add(Duration(minutes: serviceDurationMinutes));
    if (slotEnd.hour > endHour || (slotEnd.hour == endHour && slotEnd.minute > 0)) {
      return false;
    }
    for (final a in appointments) {
      final start = a['dateTime'] as DateTime?;
      final dur = a['durationMinutes'] as int? ?? 30;
      if (start == null) continue;
      final end = start.add(Duration(minutes: dur));
      final overlaps = slot.isBefore(end) && slotEnd.isAfter(start);
      if (overlaps) return false;
    }
    return true;
  }).toList();
}
