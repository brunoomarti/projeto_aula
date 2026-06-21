# Configuração Firebase + Supabase (Tasker)

Este guia configura **login** (Firebase Auth: e-mail/senha e Google) e **dados** (Supabase: perfil e tarefas). O Supabase usa **third-party Firebase**: o app envia o JWT do Firebase em cada requisição (`accessToken`), **sem** `signInWithIdToken`.

---

## 1. Variáveis de ambiente (`.env`)

Copie `.env.example` para `.env` e preencha:

| Variável | Onde obter |
|----------|------------|
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Supabase → Project Settings → API → `anon` `public` |
| `GOOGLE_WEB_CLIENT_ID` | Firebase → Authentication → Sign-in method → Google → **Web client ID** |
| `GOOGLE_PLACES_API_KEY` | (já existente) Google Cloud |
| `GEMINI_API_KEY` | (opcional) |

---

## 2. Supabase

### 2.1 Criar projeto

1. [supabase.com](https://supabase.com) → New project.
2. Anote URL e `anon` key no `.env`.

### 2.2 Tabelas e RLS

No **SQL Editor**, execute o arquivo:

1. `supabase/migrations/001_initial_schema.sql` (se projeto novo)
2. **`supabase/migrations/002_firebase_third_party.sql`** (obrigatório para Firebase)

O `002` ajusta IDs para texto (Firebase UID) e RLS com `auth.jwt() ->> 'sub'`.

### 2.3 Firebase como provedor third-party

1. Supabase Dashboard → **Authentication** → **Third-party auth** (não use “Custom OIDC” com nome `firebase`).
2. Adicione integração **Firebase**.
3. **Project ID**: `tasker-196a2` (Configurações do projeto Firebase → ID do projeto).
4. Doc: https://supabase.com/docs/guides/auth/third-party/firebase-auth

**Não** crie provider OIDC customizado chamado `firebase` — isso gera o erro *Custom OIDC provider 'firebase' not allowed*.

### 2.4 Bucket de avatares (fotos de perfil)

No **SQL Editor**, execute também:

- `supabase/migrations/006_avatars_storage.sql`

Isso cria o bucket **`avatars`** (público para leitura) com:

| Item | Valor |
|------|--------|
| Nome do bucket | `avatars` |
| Caminho dos arquivos | `{firebase_uid}/avatar.jpg` |
| Tamanho máximo | 5 MB |
| Tipos permitidos | JPEG, PNG, WebP |

**Conferir no Dashboard:** Storage → Buckets → deve aparecer `avatars` com acesso público.

**Políticas:** qualquer um pode **ver** as fotos (URL pública); só o dono (JWT Firebase `sub`) pode **enviar/atualizar/apagar** na pasta com o próprio UID.

Se o upload falhar com erro de permissão, confirme que o **Third-party Firebase** (§ 2.3) está ativo e que o `002` já foi executado.

---

## 3. Firebase

### 3.1 Projeto e Authentication

1. [Firebase Console](https://console.firebase.google.com) → Add project (ou use existente).
2. **Build** → **Authentication** → Get started.
3. Ative **E-mail/senha** e **Google**.

### 3.2 Registrar apps

- **Android**: package `com.tasker.project` (igual ao `applicationId` em `android/app/build.gradle.kts`).
- **iOS** (se for usar): bundle `com.tasker.project`.
- **Web** (opcional): para obter o Web Client ID do Google.

### 3.3 FlutterFire (obrigatório)

No terminal, na raiz do projeto:

```bash
dart pub global activate flutterfire_cli
dart run flutterfire_cli:flutterfire configure
```

Isso gera `lib/firebase_options.dart` com chaves reais (substitui os `REPLACE_ME`).

### 3.4 Android: `google-services.json`

1. Firebase → Project settings → Your apps → Android app.
2. Baixe `google-services.json`.
3. Coloque em: `android/app/google-services.json`

### 3.5 Android: SHA-1 (Google Sign-In)

No Firebase, adicione as impressões digitais do keystore de debug:

```bash
cd android
./gradlew signingReport
```

Copie **SHA-1** (e SHA-256) em Firebase → Android app → Add fingerprint.

### 3.6 `GOOGLE_WEB_CLIENT_ID`

Firebase → Authentication → Google → copie o **Web client ID** (formato `xxxxx.apps.googleusercontent.com`) para o `.env`.

---

## 4. Rodar o app

```bash
flutter pub get
flutter run
```

Fluxo esperado:

1. Tela de login (e-mail ou Google).
2. Firebase autentica → app chama `signInWithIdToken` no Supabase.
3. Tarefas e perfil vêm do Supabase (RLS por `auth.uid()`).
4. Na primeira conta, tarefas/nome salvos só no aparelho são migrados uma vez.

---

## 5. Solução de problemas

| Sintoma | Verificação |
|---------|-------------|
| `Firebase não configurado` | Rodar `flutterfire configure` |
| `Supabase não configurado` | `SUPABASE_URL` e `SUPABASE_ANON_KEY` no `.env` |
| `Custom OIDC provider 'firebase' not allowed` | Use **Third-party Firebase**, não OIDC custom; app atualizado para `accessToken` |
| Erro após login Firebase / RLS | Rode `002_firebase_third_party.sql`; Firebase habilitado no Supabase |
| Google Sign-In falha no Android | SHA-1 no Firebase + `GOOGLE_WEB_CLIENT_ID` no `.env` |
| `google-services.json` missing | Arquivo em `android/app/` |
| Tabelas inexistentes | Executar `001_initial_schema.sql` |
| RLS / permission denied | Usuário logado no Supabase? Políticas criadas? |

---

## 6. Arquitetura no código

```
LoginPage → AuthRepository (Firebase)
              → getIdToken()
              → Supabase.auth.signInWithIdToken(provider: firebase)
AuthGate → TaskStore.reload() → TaskSupabaseRepository
ProfilePage → ProfileSupabaseRepository
```

Logout: `FirebaseAuth.signOut()` + limpeza do `TaskStore`.
