# Tasker

App de tarefas em Flutter (pacote Dart: `tasker_project`). Armazena tarefas **somente no dispositivo** (sem nuvem).

## Identificadores

| Plataforma | Valor |
|------------|--------|
| Nome exibido | **Tasker** |
| Pacote Dart | `tasker_project` |
| Android / iOS | `com.tasker.project` |

## Funcionalidades

- Home com lista de tarefas do dia
- Magic input com NLP, voz e geolocalização
- Criação de tarefas com mapa opcional
- Perfil local (nome no cabeçalho)

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.11+)

## Executar

```bash
flutter pub get
flutter run
```

Após adicionar plugins nativos (`geolocator`, `shared_preferences`, `speech_to_text`), use **restart completo** (`flutter run`), não apenas hot reload.

## Testes

```bash
flutter test
```

## Estrutura

- `lib/features/` — módulos (home, tasks, profile)
- `lib/app/` — shell, tema
- `lib/core/` — NLP, serviços, layout
