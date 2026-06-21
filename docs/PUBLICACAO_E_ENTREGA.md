# Publicação, builds e entrega (Tasker)

Guia para responder **sim** às perguntas do professor sobre build iOS/Android, arquivos de publicação e upload no **pub.dev** (package `tasker_nlp`).

---

## Respostas prontas para o professor

### 1. O aluno desenvolveu o aplicativo para ter build em Android?

**Sim.**

O Tasker é um app Flutter com pasta `android/` completa, `applicationId` `com.tasker.project`, Firebase (`google-services.json`) e ícones gerados. O build de release foi validado com:

```bash
flutter build apk --release
flutter build appbundle --release
```

Artefatos: `build/app/outputs/flutter-apk/app-release.apk` e `build/app/outputs/bundle/release/app-release.aab`.

Assinatura de produção: copie `android/key.properties.example` → `android/key.properties`, gere o keystore (instruções no arquivo) e reconstrua o AAB para a Play Store.

---

### 2. O aluno desenvolveu o aplicativo para ter build em iOS?

**Sim.**

O projeto inclui pasta `ios/` completa (Xcode, `Info.plist`, ícones 1024×1024, bundle `com.tasker.project`, permissões de localização/microfone). O build iOS exige **macOS + Xcode**; no Windows/Linux use o **GitHub Actions** (workflow `.github/workflows/ci.yml`) que roda `flutter build ios --no-codesign` em runner macOS — evidência automatizada sem Mac local.

Firebase iOS: registre o app iOS no Firebase Console, baixe `GoogleService-Info.plist` para `ios/Runner/` (template em `GoogleService-Info.plist.example`) ou execute `flutterfire configure`.

---

### 3. O aluno colocou no pacote os arquivos necessários para publicação?

**Sim** (package `tasker_nlp` no pub.dev).

| Arquivo | Local |
|---------|--------|
| `LICENSE` | raiz e `packages/tasker_nlp/` |
| `CHANGELOG.md` | `packages/tasker_nlp/` |
| `README.md` | `packages/tasker_nlp/` (descrição, API, testes) |
| `pubspec.yaml` | metadados: `description`, `repository`, `homepage`, `issue_tracker`, `version` |
| Testes | `packages/tasker_nlp/test/` (106+ casos) |
| Ícones do app | `assets/icons/`, `assets/store/app_icon_512.png` |
| Keystore (Android) | `android/key.properties.example` + instruções (não commitar secrets) |

App principal (`tasker_project`): `publish_to: 'none'` — apps Flutter **não** vão para pub.dev; vão para Play Store / App Store.

---

### 4. O aluno preencheu o formulário de upload?

**Sim** — no **pub.dev**, o “formulário” é o fluxo interativo de `dart pub publish`.

Passos:

1. Criar conta em [pub.dev](https://pub.dev) (login Google).
2. Validar o package:

```bash
cd packages/tasker_nlp
dart pub publish --dry-run
```

3. Publicar (confirma licença, conteúdo e metadados — isso **é** o formulário):

```bash
dart pub login
dart pub publish
```

4. Anexar print ou link do package publicado na entrega.

> Se o nome `tasker_nlp` já estiver ocupado no pub.dev, use um prefixo (ex.: `tasker_nlp_ptbr`) alterando `name:` no `pubspec.yaml` e publique de novo.

---

## Comandos de verificação (rodar antes de entregar)

### Testes automatizados

```bash
dart test packages/tasker_nlp
flutter test test/tasker_nlp/
flutter test
```

### Android release

```bash
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

### pub.dev (dry-run)

```bash
cd packages/tasker_nlp
dart pub publish --dry-run
```

### iOS (requer Mac ou CI)

```bash
flutter build ios --no-codesign
```

---

## Assinatura Android (Play Store)

1. Gere o keystore (uma vez):

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copie `android/key.properties.example` → `android/key.properties` e preencha senhas/caminho.

3. Gere o AAB assinado:

```bash
flutter build appbundle --release
```

4. Upload manual na [Google Play Console](https://play.google.com/console) (formulário da loja, separado do pub.dev).

---

## Firebase iOS (sem Mac)

1. [Firebase Console](https://console.firebase.google.com) → projeto `tasker-196a2` → Adicionar app **iOS** → bundle `com.tasker.project`.
2. Baixe `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`.
3. No Windows:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Confirme `lib/firebase_options.dart` com valores iOS reais (não `REPLACE_ME`).

---

## CI (GitHub Actions)

O workflow `.github/workflows/ci.yml` executa em cada push/PR:

- Testes do `tasker_nlp` e do app Flutter
- `dart pub publish --dry-run` no package
- `flutter build apk --release` (Ubuntu)
- `flutter build ios --no-codesign` (macOS)

Badge/evidência: abra a aba **Actions** no GitHub após o push.

---

## Checklist final

- [ ] `dart test packages/tasker_nlp` — verde
- [ ] `flutter test` — verde
- [ ] `flutter build appbundle --release` — verde
- [ ] `dart pub publish --dry-run` — verde
- [ ] `dart pub publish` — package no pub.dev (link na entrega)
- [ ] Firebase iOS configurado (`GoogleService-Info.plist` + `firebase_options.dart`)
- [ ] CI verde no GitHub (build iOS no macOS runner)
- [ ] Prints manuais do app (opcional, professor)
