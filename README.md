# tasker-flutter

App de tarefas em Flutter, inspirado no Tasker web. Armazena tarefas **somente no dispositivo** (sem nuvem).

## Funcionalidades

- Home com lista de tarefas do dia
- Criação de tarefas com geolocalização opcional
- Perfil local (nome no cabeçalho)
- Tarefas concluídas
- Dock inferior de navegação

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.11+)

## Executar

```bash
flutter pub get
flutter run
```

Após adicionar plugins nativos (`geolocator`, `shared_preferences`), use **restart completo** (`flutter run`), não apenas hot reload.

## Testes

```bash
flutter test
```

## Estrutura

- `lib/features/` — módulos (home, tasks, profile, dashboard)
- `lib/app/` — shell, tema e dock
- `tasker-main/` — referência web local (não versionada no Git)
