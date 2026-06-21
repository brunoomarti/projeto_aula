# Testes das APIs REST externas (Tasker)

Este guia descreve como **testar manualmente** e **automaticamente** o consumo das APIs REST usadas pelo app.

---

## 1. APIs REST consumidas

| API | Protocolo | Uso no app | Código principal |
|-----|-----------|------------|------------------|
| **Supabase (PostgREST)** | REST | Tarefas, perfil, conquistas, combo | `*_supabase_repository.dart` |
| **Google Places (New)** | REST | Autocomplete e detalhes de lugares | `lib/core/services/geocode_service.dart` |
| **Google Geocoding** | REST | Endereço a partir de coordenadas | `GeocodeService.getAddressCached` |
| **Google Gemini** | REST | Magic input (opcional) | `packages/tasker_nlp/.../gemini_magic_task_parser.dart` |

Chaves no `.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_PLACES_API_KEY`, `GEMINI_API_KEY` (opcional).

---

## 2. Pré-requisitos

- [ ] `.env` preenchido (copie de `.env.example`)
- [ ] Google Cloud: **Places API (New)** e **Geocoding API** habilitadas na mesma chave
- [ ] Supabase com migrations aplicadas (ver `docs/CONFIGURACAO_FIREBASE_SUPABASE.md`)
- [ ] App rodando: `flutter run`

---

## 3. Como testar manualmente

### 3.1 Google Places + Geocoding

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 1 | Autocomplete | Criar/editar tarefa → campo de endereço → digite ≥ 3 caracteres (ex.: "Extra") | Lista de sugestões aparece | ☐ |
| 2 | Detalhes + mapa | Selecione uma sugestão com estabelecimento | Mapa centraliza; nome do local no card | ☐ |
| 3 | Reverse geocode | Tarefa com pin no mapa (sem endereço digitado) | Card exibe endereço legível (Geocoding API) | ☐ |
| 4 | Sem chave | Remova `GOOGLE_PLACES_API_KEY` do `.env` e reinicie | Autocomplete vazio; app não quebra | ☐ |

**Verificação no Google Cloud Console:** APIs & Services → Dashboard → picos de uso em Places e Geocoding após os testes.

### 3.2 Google Gemini (opcional)

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 5 | Magic input | Com `GEMINI_API_KEY` no `.env`, use frase complexa no magic input (ex.: "reunião na sapion amanhã 14h") | Tarefa criada com título, data e local interpretados | ☐ |
| 6 | Sem chave | Sem `GEMINI_API_KEY` | App usa NLP local; magic input continua funcionando | ☐ |

### 3.3 Supabase (PostgREST)

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 7 | Sync tarefas | Logado → crie tarefa na home | Linha em Supabase → Table Editor → `tasks` | ☐ |
| 8 | Sync perfil | Edite nome no perfil | Linha atualizada em `profiles` | ☐ |
| 9 | RLS | Logado como usuário A | Só vê/edita linhas com `user_id` = seu Firebase UID | ☐ |

**Verificação:** Supabase Dashboard → **Table Editor** ou **Logs** (requisições REST `GET`/`POST`/`PATCH`).

---

## 4. Testes automatizados

Os testes usam **`MockClient`** (`package:http/testing.dart`) — **não** consomem quota real das APIs.

```bash
# Google Places + Geocoding (REST)
flutter test test/apis/geocode_service_test.dart

# Contrato JSON PostgREST (Supabase)
flutter test test/apis/supabase_rest_contract_test.dart

# Todas as APIs REST
flutter test test/apis/
```

| Arquivo | O que cobre |
|---------|-------------|
| `test/apis/geocode_service_test.dart` | POST autocomplete, GET place details, GET reverse geocode, erros HTTP |
| `test/apis/supabase_rest_contract_test.dart` | Payload JSON `tasks` e `profiles` (PostgREST) |
| `test/apis/gemini_rest_test.dart` | POST Gemini, parsing de resposta, erros HTTP |

Testes de **Firebase Auth**: `flutter test test/auth/` (SDK, não REST).

---

## 5. Solução de problemas

| Sintoma | Verificação |
|---------|-------------|
| Autocomplete vazio | `GOOGLE_PLACES_API_KEY` no `.env`; Places API (New) habilitada |
| HTTP 403 no Places | Billing ativo no Google Cloud; APIs habilitadas |
| Endereço não aparece no card | Geocoding API habilitada na mesma chave |
| Gemini não responde | `GEMINI_API_KEY`; modelo `gemini-2.5-flash` disponível |
| Supabase permission denied | Login Firebase ativo; migrations e RLS (`002_firebase_third_party.sql`) |
| Tabelas vazias | Usuário logado; conferir `user_id` = Firebase UID |

---

## 6. Resumo para entrega

> O app consome APIs RESTful externas (Supabase PostgREST, Google Places/Geocoding e, opcionalmente, Gemini). A documentação de testes manuais está neste arquivo (seção 3); os testes automatizados estão em `test/apis/`, executáveis conforme seção 4.
