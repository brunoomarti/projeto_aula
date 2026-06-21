# Tasker

App de tarefas em Flutter (pacote Dart: `tasker_project`). Autenticação via **Firebase Auth**; tarefas, perfil e conquistas sincronizados no **Supabase**.

## Identificadores

| Plataforma | Valor |
|------------|--------|
| Nome exibido | **Tasker** |
| Pacote Dart | `tasker_project` |
| Android / iOS | `com.tasker.project` |

## Funcionalidades

- Login e cadastro (Firebase: e-mail/senha e Google)
- Home com lista de tarefas do dia (sync Supabase)
- Magic input com NLP, voz e geolocalização
- Criação de tarefas com mapa opcional
- Perfil com avatar (Supabase Storage)
- Conquistas e gamificação

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.11+)
- Projeto Firebase configurado (`firebase_options.dart`, `google-services.json` no Android)
- Projeto Supabase com migrations aplicadas (ver documentação abaixo)

## Configuração e testes (Firebase)

Guia completo de setup, integração Firebase + Supabase e **roteiro de testes manuais** da autenticação:

→ **[docs/CONFIGURACAO_FIREBASE_SUPABASE.md](docs/CONFIGURACAO_FIREBASE_SUPABASE.md)** (seção 5: checklist de testes)

## APIs REST externas

Supabase (PostgREST), Google Places/Geocoding e Gemini — documentação de **testes manuais e automatizados**:

→ **[docs/TESTES_APIS_EXTERNAS.md](docs/TESTES_APIS_EXTERNAS.md)**

## Package interno `tasker_nlp`

NLP em português (magic input) — documentação de **testes manuais e automatizados**:

→ **[docs/TESTES_TASKER_NLP.md](docs/TESTES_TASKER_NLP.md)**

## Executar

```bash
# Copie .env.example para .env e preencha as variáveis
flutter pub get
flutter run
```

Após adicionar plugins nativos (`geolocator`, `shared_preferences`, `speech_to_text`), use **restart completo** (`flutter run`), não apenas hot reload.

## Testes automatizados

```bash
flutter test test/auth/    # Firebase Auth
flutter test test/apis/    # APIs REST (Places, Geocoding, Supabase, Gemini)
flutter test test/tasker_nlp/  # Integração app ↔ tasker_nlp
dart test packages/tasker_nlp  # Unitários do package NLP (94 testes)
flutter test               # demais módulos
```

Validação manual: `docs/CONFIGURACAO_FIREBASE_SUPABASE.md` (Firebase), `docs/TESTES_APIS_EXTERNAS.md` (APIs REST) e `docs/TESTES_TASKER_NLP.md` (package NLP).

## Publicação e entrega

Build Android/iOS, arquivos para pub.dev e respostas para o formulário de entrega:

→ **[docs/PUBLICACAO_E_ENTREGA.md](docs/PUBLICACAO_E_ENTREGA.md)**

## Estrutura

- `lib/features/` — módulos (home, tasks, profile)
- `lib/app/` — shell, tema
- `lib/core/` — serviços, layout, geocoding
- `packages/tasker_nlp/` — **package interno** de NLP em português (magic input)
