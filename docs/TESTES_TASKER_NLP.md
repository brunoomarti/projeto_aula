# Testes do package `tasker_nlp` (Tasker)

Este guia descreve como **testar manualmente** e **automaticamente** o package interno **`tasker_nlp`** — NLP em português usado pelo magic input (texto e voz) do app.

---

## 1. O package e onde ele entra no app

| Item | Detalhe |
|------|---------|
| **Package** | `packages/tasker_nlp/` (dependência local no `pubspec.yaml`) |
| **Função** | Interpretar frases em PT-BR e extrair título, data, hora, local, lista de recados e ícone |
| **Integração no app** | `MagicTaskBuilder`, `MagicTaskInput`, sugestão de ícone em `NewTaskPage`, resolução de local em `resolve_place_location.dart` |

### Módulos do package

| Módulo | Arquivo | Responsabilidade |
|--------|---------|------------------|
| `extract_when_pt_br` | `lib/src/extract_when_pt_br.dart` | Data, hora e título |
| `extract_place_pt_br` | `lib/src/extract_place_pt_br.dart` | Locais e expressões coloquiais |
| `extract_errand_list_pt_br` | `lib/src/extract_errand_list_pt_br.dart` | Listas de compras e ações |
| `infer_task_icon_pt_br` | `lib/src/infer_task_icon_pt_br.dart` | Ícone e cor sugeridos |
| `gemini_magic_task_parser` | `lib/src/gemini_magic_task_parser.dart` | Parser híbrido (Gemini + refinamento local) |
| `nlp_date_utils` | `lib/src/nlp_date_utils.dart` | Utilitários de data relativa |

---

## 2. Pré-requisitos

- [ ] Flutter SDK instalado (Dart 3.11+)
- [ ] Dependências: `flutter pub get` na raiz do projeto
- [ ] Para testes manuais no app: `flutter run` (login opcional para salvar tarefa)
- [ ] **Gemini (opcional):** `GEMINI_API_KEY` no `.env` — sem chave, o app usa só NLP local

---

## 3. Como testar manualmente (no app)

Use o **magic input** na home (campo de texto livre ou microfone).

### 3.1 Data e hora (`extract_when_pt_br`)

| # | Frase de teste | Resultado esperado | ✓ |
|---|----------------|-------------------|---|
| 1 | `Levar meu pet ao veterinário amanhã` | Título com “pet/veterinário”; data = amanhã; sem hora | ☐ |
| 2 | `Reunião com Ana quinta às 14h` | Título “Reunião…”; data na quinta; hora `14:00` | ☐ |
| 3 | `Enviar relatório hoje às 18h` | Data = hoje; hora `18:00` | ☐ |
| 4 | `dentista 2 e meia da tarde` | Hora `14:30`; título “Dentista” | ☐ |
| 5 | `reunião dia 29 as 14h` | Data dia 29 do mês; hora `14:00` | ☐ |

### 3.2 Local (`extract_place_pt_br`)

| # | Frase de teste | Resultado esperado | ✓ |
|---|----------------|-------------------|---|
| 6 | `aula no IFES hoje às 19 horas` | Título sem “IFES” redundante; local resolvido (se Places configurado) | ☐ |
| 7 | `ir ao shopping vitória 18h` | Local “shopping vitória”; hora `18:00` | ☐ |
| 8 | `ir na rua comprar um tênis branco` | **Sem** geocodificar “rua”; título de compra única | ☐ |
| 9 | `fazer mercado hoje à tarde` | Mercado genérico — **sem** local geocodificado | ☐ |

### 3.3 Lista de recados (`extract_errand_list_pt_br`)

| # | Frase de teste | Resultado esperado | ✓ |
|---|----------------|-------------------|---|
| 10 | `comprar feijão arroz e macarrão amanhã` | Título “Lista de compras”; descrição com itens em bullet | ☐ |
| 11 | `ir no supermercado comprar mamão banana e açúcar` | Título “Comprar no Supermercado”; lista na descrição | ☐ |
| 12 | `comprar camisa do brasil amanhã` | **Não** vira lista; título único com “camisa” e “brasil” | ☐ |

### 3.4 Ícone sugerido (`infer_task_icon_pt_br`)

| # | Frase de teste | Ícone esperado (aprox.) | ✓ |
|---|----------------|-------------------------|---|
| 13 | `Treino de futebol sábado às 9h` | Esporte (`ball_sports`) | ☐ |
| 14 | `Ir à academia às 07:30` | Academia (`gym`) | ☐ |
| 15 | `culto na igreja domingo às 19h` | Fé (`faith`) | ☐ |

### 3.5 Gemini híbrido (opcional)

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 16 | Com API | Com `GEMINI_API_KEY`, frase complexa: `reunião de negócios na sapion amanhã duas da tarde` | Título, data, hora `14:00`, local Sapion | ☐ |
| 17 | Sem API | Remova `GEMINI_API_KEY` e reinicie | Magic input continua com NLP local | ☐ |

### 3.6 Sugestão de ícone no formulário

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 18 | Nova tarefa | Criar tarefa → passo “Detalhes” → digite título “Consulta dentista quinta” | Ícone sugerido automaticamente (ex.: saúde/trabalho conforme regras) | ☐ |

**Evidências:** prints ou gravação de tela do magic input e da tarefa criada (título, data, hora, local, ícone, lista).

---

## 4. Testes automatizados

### 4.1 Testes unitários do package (94 testes)

Executam **sem Flutter** — apenas Dart:

```bash
dart test packages/tasker_nlp
```

| Arquivo | Módulo coberto | Exemplos de cenários |
|---------|----------------|----------------------|
| `test/extract_when_pt_br_test.dart` | Data/hora/título | “amanhã”, “quinta 14h”, “2 e meia da tarde”, “dia 29” |
| `test/extract_place_pt_br_test.dart` | Locais | IFES, shopping, rua coloquial, supermercado genérico |
| `test/extract_errand_list_pt_br_test.dart` | Listas | Supermercado + frutas, ações na rua, produto único |
| `test/infer_task_icon_pt_br_test.dart` | Ícones | Veterinário, academia, futebol, igreja, lazer |
| `test/gemini_magic_task_parser_test.dart` | Gemini + refinamento | JSON markdown, horários coloquiais, listas, Detran |

### 4.2 Testes de integração no app (usa `tasker_nlp` via `MagicTaskBuilder`)

Requer Flutter:

```bash
flutter test test/tasker_nlp/
flutter test test/magic_task_builder_errand_test.dart
flutter test test/resolve_place_location_test.dart
```

| Arquivo | O que cobre |
|---------|-------------|
| `test/tasker_nlp/magic_task_builder_integration_test.dart` | Pipeline completo: texto → `Task` (título, data, hora, ícone, lista) |
| `test/magic_task_builder_errand_test.dart` | Listas de compras e falsos positivos |
| `test/resolve_place_location_test.dart` | Escolha de sugestão Places a partir de `ExtractPlaceResult` |
| `test/apis/gemini_rest_test.dart` | Chamada REST Gemini + parsing (mock HTTP) |

### 4.3 Executar tudo relacionado ao NLP

```bash
dart test packages/tasker_nlp
flutter test test/tasker_nlp/ test/magic_task_builder_errand_test.dart test/resolve_place_location_test.dart test/apis/gemini_rest_test.dart
```

---

## 5. Solução de problemas

| Sintoma | Verificação |
|---------|-------------|
| Magic input não interpreta data | Conferir frase em PT-BR; ver testes em `extract_when_pt_br_test.dart` |
| Local errado ou ausente | `GOOGLE_PLACES_API_KEY` no `.env`; ver seção 3.2 |
| “Ir na rua” virou endereço | Comportamento esperado: expressão coloquial ignorada (teste #8) |
| Gemini não usado | `GEMINI_API_KEY` ausente → NLP local (teste #17) |
| Testes do package falham | `cd packages/tasker_nlp && dart pub get && dart test` |

---

## 6. Resumo para entrega

> O projeto inclui o package Dart **`tasker_nlp`** (`packages/tasker_nlp/`). A documentação de **testes manuais** está neste arquivo (seção 3); os **testes automatizados** cobrem cada módulo do package (`dart test packages/tasker_nlp`, 94 testes) e a integração no app via `MagicTaskBuilder` (`flutter test test/tasker_nlp/` e arquivos relacionados na seção 4).
