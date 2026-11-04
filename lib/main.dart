import 'package:flutter/material.dart';

import 'models/appointment.dart';
import 'services/calendar_service.dart';

void main() => runApp(const AgendaApp());

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key, this.service});

  /// Permite injetar um serviço falso nos testes.
  final CalendarService? service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compromissos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: HomePage(service: service ?? CalendarService(DeviceCalendarGateway())),
    );
  }
}

enum UiState { idle, loading, denied, empty, error, success }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.service});
  final CalendarService service;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UiState _state = UiState.idle;
  List<Appointment> _items = const [];
  String _error = '';

  Future<void> _query() async {
    setState(() => _state = UiState.loading);
    try {
      final r = await widget.service.fetch();
      if (!mounted) return;
      setState(() {
        switch (r.status) {
          case QueryStatus.denied:
            _state = UiState.denied;
          case QueryStatus.empty:
            _state = UiState.empty;
          case QueryStatus.success:
            _items = r.appointments;
            _state = UiState.success;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _state = UiState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _state == UiState.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Compromissos (próximos 7 dias)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : _query,
                icon: const Icon(Icons.event),
                label: const Text('Consultar compromissos'),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case UiState.idle:
        return const _Message(
          icon: Icons.calendar_month,
          text:
              'Toque em "Consultar compromissos" para listar os eventos de hoje e dos próximos 6 dias.',
        );
      case UiState.loading:
        return const Center(child: CircularProgressIndicator());
      case UiState.denied:
        return const _Message(
          icon: Icons.lock,
          text:
              'Acesso ao calendário negado. Autorize a permissão e toque em "Consultar compromissos" novamente '
              '(se necessário, habilite nas configurações do aplicativo).',
        );
      case UiState.empty:
        return const _Message(
          icon: Icons.event_busy,
          text: 'Nenhum compromisso nos próximos 7 dias.',
        );
      case UiState.error:
        return _Message(
          icon: Icons.error_outline,
          text: 'Falha ao consultar o calendário: $_error',
        );
      case UiState.success:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => AppointmentCard(item: _items[i]),
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

String _two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Texto de período: início/fim com data e horário, ou "Dia inteiro".
String periodText(Appointment a) {
  if (a.allDay) {
    final same = a.start.year == a.end.year &&
        a.start.month == a.end.month &&
        a.start.day == a.end.day;
    return same
        ? '${fmtDate(a.start)} · Dia inteiro'
        : '${fmtDate(a.start)} a ${fmtDate(a.end)} · Dia inteiro';
  }
  return 'Início: ${fmtDate(a.start)} ${fmtTime(a.start)}\n'
      'Fim: ${fmtDate(a.end)} ${fmtTime(a.end)}';
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.item});
  final Appointment item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title, style: t.titleMedium)),
                if (item.allDay)
                  const Chip(
                    label: Text('Dia inteiro'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _row(Icons.calendar_today, 'Calendário: ${item.calendarName}'),
            _row(Icons.schedule, periodText(item)),
            if (item.location != null) _row(Icons.place, 'Local: ${item.location}'),
            if (item.description != null)
              _row(Icons.notes, 'Descrição: ${item.description}'),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
