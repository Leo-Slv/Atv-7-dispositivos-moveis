import 'package:agenda_compromissos/main.dart';
import 'package:agenda_compromissos/models/appointment.dart';
import 'package:agenda_compromissos/services/calendar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements CalendarGateway {
  FakeGateway({
    this.has = true,
    this.grant = true,
    this.cals = const [],
    this.byCal = const {},
    this.fail = false,
    this.delay = Duration.zero,
    this.failCals = const {},
  });
  bool has, grant, fail;
  Duration delay;
  Set<String> failCals;
  List<CalendarSource> cals;
  Map<String, List<Appointment>> byCal;
  int requested = 0;

  @override
  Future<bool> hasPermission() async => has;
  @override
  Future<bool> requestPermission() async {
    requested++;
    return grant;
  }

  @override
  Future<List<CalendarSource>> calendars() async {
    await Future<void>.delayed(delay);
    if (fail) throw CalendarQueryException('boom');
    return cals;
  }

  @override
  Future<List<Appointment>> events(
          CalendarSource c, DateTime s, DateTime e) async {
    if (failCals.contains(c.id)) throw CalendarQueryException('ruim ${c.id}');
    return byCal[c.id] ?? [];
  }
}

final now = DateTime(2026, 11, 3, 10, 0);

Appointment ap(String t, DateTime s,
        {Duration d = const Duration(hours: 1),
        bool allDay = false,
        String cal = 'A'}) =>
    Appointment(
        title: t,
        calendarName: cal,
        start: s,
        end: s.add(d),
        allDay: allDay,
        location: 'Sala 1',
        description: 'Desc $t');

CalendarService svc(FakeGateway g) => CalendarService(g, now: () => now);

void main() {
  test('janela cobre hoje e mais 6 dias (7 dias)', () {
    final w = svc(FakeGateway()).window();
    expect(w.start, DateTime(2026, 11, 3));
    expect(w.end, DateTime(2026, 11, 10));
    expect(w.end.difference(w.start).inDays, 7);
  });

  test('consulta todos os calendarios e ordena cronologicamente', () async {
    final g = FakeGateway(
      cals: const [
        CalendarSource(id: '1', name: 'A'),
        CalendarSource(id: '2', name: 'B')
      ],
      byCal: {
        '1': [ap('tarde', DateTime(2026, 11, 5, 15))],
        '2': [
          ap('manha', DateTime(2026, 11, 4, 9), cal: 'B'),
          ap('hoje', DateTime(2026, 11, 3, 11))
        ],
      },
    );
    final r = await svc(g).fetch();
    expect(r.status, QueryStatus.success);
    expect(r.appointments.map((a) => a.title), ['hoje', 'manha', 'tarde']);
  });

  test('ignora eventos fora da janela', () async {
    final g = FakeGateway(
      cals: const [CalendarSource(id: '1', name: 'A')],
      byCal: {
        '1': [ap('longe', DateTime(2026, 11, 20, 9))]
      },
    );
    expect((await svc(g).fetch()).status, QueryStatus.empty);
  });

  test('solicita permissao quando ausente e retorna denied se recusada',
      () async {
    final g = FakeGateway(has: false, grant: false);
    final r = await svc(g).fetch();
    expect(g.requested, 1);
    expect(r.status, QueryStatus.denied);
  });

  test('sem calendarios no aparelho lanca erro explicativo', () async {
    expect(svc(FakeGateway()).fetch(), throwsA(isA<CalendarQueryException>()));
  });

  test('falha em um calendario nao esconde os demais', () async {
    final g = FakeGateway(
      cals: const [CalendarSource(id: '1', name: 'A'), CalendarSource(id: '2', name: 'B')],
      failCals: {'1'},
      byCal: {'2': [ap('ok', DateTime(2026, 11, 4, 9))]},
    );
    final r = await svc(g).fetch();
    expect(r.appointments.map((a) => a.title), ['ok']);
  });

  testWidgets('estado inicial mostra o botao', (t) async {
    await t.pumpWidget(AgendaApp(service: svc(FakeGateway())));
    expect(find.text('Consultar compromissos'), findsOneWidget);
  });

  testWidgets('exibe carregamento, campos do compromisso e dia inteiro',
      (t) async {
    final g = FakeGateway(
      cals: const [CalendarSource(id: '1', name: 'Pessoal')],
      delay: const Duration(milliseconds: 50),
      byCal: {
        '1': [
          ap('Feriado', DateTime(2026, 11, 4),
              d: Duration.zero, allDay: true, cal: 'Pessoal'),
          ap('Reunião', DateTime(2026, 11, 3, 14, 30), cal: 'Pessoal'),
        ],
      },
    );
    await t.pumpWidget(AgendaApp(service: svc(g)));
    await t.tap(find.text('Consultar compromissos'));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Reunião'), findsOneWidget);
    expect(find.text('Calendário: Pessoal'), findsNWidgets(2));
    expect(find.textContaining('Início: 03/11/2026 14:30'), findsOneWidget);
    expect(find.textContaining('Fim: 03/11/2026 15:30'), findsOneWidget);
    expect(find.text('Local: Sala 1'), findsNWidgets(2));
    expect(find.text('Descrição: Desc Reunião'), findsOneWidget);
    expect(find.text('Dia inteiro'), findsOneWidget);
    expect(find.textContaining('04/11/2026 · Dia inteiro'), findsOneWidget);
  });

  testWidgets('mensagem para lista vazia', (t) async {
    await t.pumpWidget(AgendaApp(
        service: svc(FakeGateway(cals: const [CalendarSource(id: '1', name: 'A')]))));
    await t.tap(find.text('Consultar compromissos'));
    await t.pumpAndSettle();
    expect(find.text('Nenhum compromisso nos próximos 7 dias.'), findsOneWidget);
  });

  testWidgets('mensagem para acesso negado', (t) async {
    await t.pumpWidget(
        AgendaApp(service: svc(FakeGateway(has: false, grant: false))));
    await t.tap(find.text('Consultar compromissos'));
    await t.pumpAndSettle();
    expect(find.textContaining('Acesso ao calendário negado'), findsOneWidget);
  });

  testWidgets('mensagem para falha na consulta', (t) async {
    await t.pumpWidget(AgendaApp(service: svc(FakeGateway(fail: true))));
    await t.tap(find.text('Consultar compromissos'));
    await t.pumpAndSettle();
    expect(find.textContaining('Falha ao consultar o calendário: boom'),
        findsOneWidget);
  });
}
