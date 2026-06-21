# tasker_nlp

NLP em português (PT-BR) para interpretar texto livre e montar tarefas: título, data, hora, local, listas de compras e ícone inferido.

Desenvolvido como package interno do app [Tasker](https://github.com/brunoomarti/projeto_aula) e publicável no [pub.dev](https://pub.dev).

## Instalação

```yaml
dependencies:
  tasker_nlp: ^1.0.0
```

Ou dependência local (monorepo):

```yaml
dependencies:
  tasker_nlp:
    path: packages/tasker_nlp
```

## Uso

```dart
import 'package:tasker_nlp/tasker_nlp.dart';

final when = extractWhenPTBR('comprar pão amanhã às 18h');
final place = extractPlaceMentionPTBR('comprar pão na padaria do centro');
final icon = inferTaskIconPTBR('consulta médica');
```

## Módulos

| Export | Função |
|--------|--------|
| `extract_when_pt_br` | Data, hora, períodos do dia e título |
| `extract_place_pt_br` | Locais mencionados no texto |
| `extract_errand_list_pt_br` | Listas de compras e recados |
| `extract_action_title_pt_br` | Título de ação única |
| `infer_task_icon_pt_br` | Ícone e cor inferidos |
| `gemini_magic_task_parser` | Parser híbrido opcional (API Gemini) |

## Testes

```bash
cd packages/tasker_nlp
dart test
```

Guia completo (manual + automatizado): [TESTES_TASKER_NLP.md](https://github.com/brunoomarti/projeto_aula/blob/main/docs/TESTES_TASKER_NLP.md)

## Publicação (pub.dev)

Metadados exigidos: `LICENSE`, `CHANGELOG.md`, `README.md`, `pubspec.yaml` com `repository` e `description`.

Validar antes de publicar:

```bash
dart pub publish --dry-run
```

Publicar (fluxo interativo = “formulário de upload” do pub.dev):

```bash
dart pub login
dart pub publish
```

## Licença

MIT — veja [LICENSE](LICENSE).
