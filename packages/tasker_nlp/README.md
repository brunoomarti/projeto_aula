# tasker_nlp

Package interno do Tasker com NLP em português para o magic input.

## Módulos

- `extract_when_pt_br` — data, hora e título a partir de frases em PT-BR
- `extract_place_pt_br` — locais e geocodificação
- `extract_errand_list_pt_br` — listas de compras e recados
- `infer_task_icon_pt_br` — ícone e cor inferidos do texto
- `gemini_magic_task_parser` — parser híbrido via API Gemini

## Testes

```bash
cd packages/tasker_nlp
dart test
```
