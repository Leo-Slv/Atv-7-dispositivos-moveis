# Agenda de Compromissos (Aula 7 — Permissões e recursos do dispositivo)

App Flutter que consulta o calendário do dispositivo e lista os compromissos de
hoje e dos próximos 6 dias (7 dias), usando o pacote `device_calendar`.
Veja os requisitos em [SPEC.md](SPEC.md).

## Atendimento aos requisitos
| Requisito | Onde |
|---|---|
| Solicitar permissão do calendário | `CalendarService.fetch` (`hasPermission` → `requestPermission`) |
| Botão "Consultar compromissos" | `lib/main.dart` |
| Todos os calendários | `CalendarService.fetch` percorre `calendars()` |
| Ordem cronológica | ordenação por início em `CalendarService.fetch` |
| Título, calendário, início/fim, local, descrição | `AppointmentCard` |
| Dia inteiro | chip "Dia inteiro" + período por data |
| Indicador de carregamento | `CircularProgressIndicator` (estado `loading`) |
| Vazio / negado / falha | estados `empty`, `denied`, `error` |
| Permissões Android | `READ_CALENDAR` e `WRITE_CALENDAR` em `AndroidManifest.xml` |

## Executar (somente Docker — Flutter não é instalado no host)
```bash
docker compose run --rm flutter sh -c "flutter pub get && flutter analyze && flutter test"
docker compose run --rm flutter sh -c "flutter build apk --debug"
```
O APK é gerado em `build/app/outputs/flutter-apk/app-debug.apk`; instale em um
dispositivo/emulador Android com eventos no calendário (`adb install`).
