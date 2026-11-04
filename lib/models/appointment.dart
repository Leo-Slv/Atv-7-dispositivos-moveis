/// Compromisso já normalizado para exibição na UI.
class Appointment {
  const Appointment({
    required this.title,
    required this.calendarName,
    required this.start,
    required this.end,
    required this.allDay,
    this.location,
    this.description,
  });

  final String title;
  final String calendarName;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;
  final String? description;
}
