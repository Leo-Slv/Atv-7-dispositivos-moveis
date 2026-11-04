# Spec — Consulta aos compromissos do calendário (Aula 7)

Fonte: "Aula 7 – Permissões e acesso a recursos do dispositivo" (Prof. Arley).

## Objetivo
App Flutter que consulta o calendário do dispositivo e lista os compromissos de
hoje e dos próximos 6 dias (janela de 7 dias).

## Requisitos (inegociáveis)
| # | Requisito |
|---|-----------|
| R1 | Solicitar a permissão de acesso ao calendário em tempo de execução |
| R2 | Botão "Consultar compromissos" |
| R3 | Consultar TODOS os calendários disponíveis no dispositivo |
| R4 | Listar compromissos em ordem cronológica |
| R5 | Exibir por compromisso: título, calendário, data e horário de início e fim, local, descrição |
| R6 | Identificar compromissos de dia inteiro |
| R7 | Indicador de carregamento durante a consulta |
| R8 | Informar: sem compromissos / acesso negado / falha na consulta |
| R9 | Usar o pacote `device_calendar` |
| R10 | Configurar permissões necessárias no Android (READ_CALENDAR, WRITE_CALENDAR) |

## Fluxo
1. Usuário toca em "Consultar compromissos".
2. App verifica permissão (`hasPermissions`); se ausente, solicita (`requestPermissions`).
3. Negada -> estado `denied` (mensagem + botão para tentar novamente).
4. Concedida -> estado `loading`; `retrieveCalendars` e, para cada calendário,
   `retrieveEvents` entre 00:00 de hoje e 00:00 do dia +7.
5. Eventos unificados, ordenados por início; vazio -> estado `empty`; exceção/
   `isSuccess == false` -> estado `error`; senão `success`.

## Estados da UI
`idle`, `loading`, `denied`, `empty`, `error`, `success`.

## Arquitetura
- `lib/models/appointment.dart` — modelo de compromisso (dados prontos para a UI)
- `lib/services/calendar_service.dart` — acesso ao `device_calendar`, ordenação, janela de datas
- `lib/main.dart` — UI e máquina de estados
- `test/` — testes de unidade (ordenação, janela de 7 dias, dia inteiro) e de widget

## Ambiente
Sem Flutter instalado no host: tudo via Docker (`ghcr.io/cirruslabs/flutter:stable`),
orquestrado por `docker-compose.yml` / `Makefile`-like scripts (`scripts/`).
Commits sem co-autor.
