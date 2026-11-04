import 'package:device_calendar/device_calendar.dart';

import '../models/appointment.dart';

/// Resultado de falha de consulta (calendários ou eventos).
class CalendarQueryException implements Exception {
  CalendarQueryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Abstração fina sobre o plugin para permitir testes sem dispositivo.
abstract class CalendarGateway {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<List<CalendarSource>> calendars();
  Future<List<Appointment>> events(
    CalendarSource calendar,
    DateTime start,
    DateTime end,
  );
}

class CalendarSource {
  const CalendarSource({required this.id, required this.name});
  final String id;
  final String name;
}

/// Implementação real com o pacote `device_calendar`.
class DeviceCalendarGateway implements CalendarGateway {
  DeviceCalendarGateway([DeviceCalendarPlugin? plugin])
      : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  @override
  Future<bool> hasPermission() async {
    final r = await _plugin.hasPermissions();
    return r.isSuccess && (r.data ?? false);
  }

  @override
  Future<bool> requestPermission() async {
    final r = await _plugin.requestPermissions();
    return r.isSuccess && (r.data ?? false);
  }

  @override
  Future<List<CalendarSource>> calendars() async {
    final r = await _plugin.retrieveCalendars();
    if (!r.isSuccess) {
      throw CalendarQueryException(_errors(r.errors, 'Falha ao listar calendários.'));
    }
    return (r.data ?? [])
        .where((c) => c.id != null)
        .map((c) => CalendarSource(id: c.id!, name: c.name ?? 'Calendário'))
        .toList();
  }

  @override
  Future<List<Appointment>> events(
    CalendarSource calendar,
    DateTime start,
    DateTime end,
  ) async {
    final r = await _plugin.retrieveEvents(
      calendar.id,
      RetrieveEventsParams(startDate: start, endDate: end),
    );
    if (!r.isSuccess) {
      throw CalendarQueryException(
        _errors(r.errors, 'Falha ao ler eventos de "${calendar.name}".'),
      );
    }
    return (r.data ?? []).map((e) => _toAppointment(e, calendar.name)).toList();
  }

  static Appointment _toAppointment(Event e, String calendarName) {
    final allDay = e.allDay ?? false;
    DateTime conv(dynamic tz) {
      // Eventos de dia inteiro: usar os campos de calendário informados pelo
      // plugin; demais: converter o instante para o fuso local do aparelho.
      if (allDay) return DateTime(tz.year, tz.month, tz.day);
      return DateTime.fromMillisecondsSinceEpoch(tz.millisecondsSinceEpoch);
    }

    final start = e.start != null ? conv(e.start) : DateTime.now();
    var end = e.end != null ? conv(e.end) : start;
    // Fim de evento de dia inteiro costuma ser exclusivo (meia-noite seguinte).
    if (allDay && end.isAfter(start)) {
      end = end.subtract(const Duration(days: 1));
    }
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return Appointment(
      title: clean(e.title) ?? '(Sem título)',
      calendarName: calendarName,
      start: start,
      end: end,
      allDay: allDay,
      location: clean(e.location),
      description: clean(e.description),
    );
  }

  static String _errors(List<ResultError> errors, String fallback) =>
      errors.isEmpty ? fallback : errors.map((e) => e.errorMessage).join('; ');
}

enum QueryStatus { success, empty, denied }

class QueryResult {
  const QueryResult(this.status, [this.appointments = const []]);
  final QueryStatus status;
  final List<Appointment> appointments;
}

/// Regras de negócio: permissão, janela de 7 dias, todos os calendários e ordem.
class CalendarService {
  CalendarService(this._gateway, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final CalendarGateway _gateway;
  final DateTime Function() _now;

  /// Hoje 00:00 até 00:00 do 7º dia seguinte (hoje + 6 dias, inclusive).
  ({DateTime start, DateTime end}) window() {
    final n = _now();
    final start = DateTime(n.year, n.month, n.day);
    final end = DateTime(n.year, n.month, n.day + 7);
    return (start: start, end: end);
  }

  Future<QueryResult> fetch() async {
    var granted = await _gateway.hasPermission();
    if (!granted) granted = await _gateway.requestPermission();
    if (!granted) return const QueryResult(QueryStatus.denied);

    final w = window();
    final calendars = await _gateway.calendars();
    final all = <Appointment>[];
    if (calendars.isEmpty) {
      throw CalendarQueryException(
        'Nenhum calendário encontrado no dispositivo. Adicione uma conta '
        '(ex.: Google) ou crie um calendário no app de Agenda.',
      );
    }
    CalendarQueryException? lastError;
    var failed = 0;
    for (final c in calendars) {
      try {
        all.addAll(await _gateway.events(c, w.start, w.end));
      } catch (e) {
        // Um calendário com problema não deve esconder os demais.
        failed++;
        lastError = e is CalendarQueryException
            ? e
            : CalendarQueryException(e.toString());
      }
    }
    if (failed == calendars.length && lastError != null) throw lastError;
    // Garante que só entram eventos que intersectam a janela.
    final inWindow =
        all.where((a) => a.start.isBefore(w.end) && !a.end.isBefore(w.start))
        .toList()
          ..sort((a, b) {
            final c = a.start.compareTo(b.start);
            return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
    if (inWindow.isEmpty) return const QueryResult(QueryStatus.empty);
    return QueryResult(QueryStatus.success, inWindow);
  }
}
