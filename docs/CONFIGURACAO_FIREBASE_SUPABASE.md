# Configuração e testes — Firebase + Supabase (Tasker)

Este guia cobre:

1. **Configuração** — login (Firebase Auth: e-mail/senha e Google) e dados (Supabase: perfil e tarefas).
2. **Testes** — roteiro manual para validar a autenticação Firebase (seção **5**).

O Supabase usa **third-party Firebase**: o app envia o JWT do Firebase em cada requisição (`accessToken`), **sem** `signInWithIdToken`.

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

Na primeira execução, o app exibe a tela de login. Após autenticar, a home abre com tarefas e perfil sincronizados via Supabase (JWT do Firebase enviado automaticamente em cada requisição).

Para validar a solução Firebase passo a passo, siga a **seção 5** abaixo.

---

## 5. Como testar a solução Firebase

Este roteiro cobre os cenários de autenticação implementados com **Firebase Auth** e a integração com o Supabase.

### 5.1 Pré-requisitos para testar

Antes de começar, confirme:

- [ ] Seções **1**, **2** e **3** deste guia concluídas (`.env`, migrations, Firebase third-party no Supabase).
- [ ] `lib/firebase_options.dart` configurado (sem `REPLACE_ME` na plataforma alvo).
- [ ] `android/app/google-services.json` presente (para Android).
- [ ] Dispositivo/emulador **com internet**.
- [ ] Para Google Sign-In no Android: SHA-1 cadastrado no Firebase e `GOOGLE_WEB_CLIENT_ID` no `.env`.
- [ ] E-mail de teste disponível (real ou descartável) para cadastro e recuperação de senha.

Execute o app:

```bash
flutter pub get
flutter run
```

**Resultado esperado na abertura:** tela **“Seja bem-vindo!”** com campos de login, botão **Entrar**, botão **Google** e opção **Criar uma conta**.

### 5.2 Checklist de testes

Marque cada item ao concluir. Use um e-mail de teste que você controla (ex.: `teste.tasker+1@gmail.com`).

| # | Cenário | Passos | Resultado esperado | ✓ |
|---|---------|--------|-------------------|---|
| 1 | **Cadastro (e-mail/senha)** | Toque em **Criar uma conta** → preencha nome, e-mail e senha (mín. 6 caracteres) → **Cadastrar** | App entra na home; usuário aparece em Firebase Console → **Authentication** → **Users** | ☐ |
| 2 | **Login (e-mail/senha)** | Saia da conta (Perfil → **Sair da conta**) → entre com o mesmo e-mail e senha | Login bem-sucedido; home carrega tarefas do usuário | ☐ |
| 3 | **Senha incorreta** | Na tela de login, use e-mail válido e senha errada → **Entrar** | Mensagem de erro; app permanece na tela de login | ☐ |
| 4 | **Login com Google** | Toque no botão **Google** → escolha conta Google | Login concluído; home abre; usuário listado no Firebase Console (provedor Google) | ☐ |
| 5 | **Recuperação de senha** | Na tela de login, informe o e-mail → **Esqueceu sua senha?** | Snackbar: *“Enviamos um link de recuperação…”*; e-mail recebido do Firebase | ☐ |
| 6 | **Sessão persistente** | Com usuário logado, feche o app completamente e abra de novo | App abre direto na home, sem pedir login novamente | ☐ |
| 7 | **Logout** | Perfil → **Sair da conta** → confirme | Volta à tela de login; dados do usuário anterior não aparecem | ☐ |
| 8 | **Firebase → Supabase** | Após login, crie uma tarefa na home → confira no Supabase Dashboard → **Table Editor** → `tasks` | Nova linha com `user_id` = Firebase UID (texto) do usuário logado | ☐ |
| 9 | **Perfil no Supabase** | Após primeiro login, abra **Table Editor** → `profiles` | Linha criada com o mesmo `id` (Firebase UID) e e-mail do usuário | ☐ |

> **Modo visitante:** o link *“Continuar sem login”* **não** usa Firebase — serve só para uso local. Os testes acima validam especificamente a solução Firebase.

### 5.3 Detalhamento dos cenários principais

#### Cadastro e login (e-mail/senha)

1. Abra o app → **Criar uma conta**.
2. Preencha **nome completo** (nome + sobrenome), **e-mail** e **senha** (mínimo 6 caracteres).
3. Toque **Cadastrar**.
4. **Verificação no Firebase:** [Firebase Console](https://console.firebase.google.com) → projeto `tasker-196a2` → **Build** → **Authentication** → **Users** → novo usuário com o e-mail cadastrado.
5. Saia (**Perfil** → **Sair da conta**) e faça login novamente com as mesmas credenciais.

#### Login com Google (Android)

1. Na tela de login, toque no botão **Google**.
2. Selecione uma conta Google autorizada.
3. **Verificação no Firebase:** usuário aparece em **Authentication** → **Users** com ícone Google.
4. Se falhar com erro de configuração, revise § 3.5 (SHA-1) e § 3.6 (`GOOGLE_WEB_CLIENT_ID`).

#### Recuperação de senha

1. Na tela de login, informe um e-mail já cadastrado.
2. Toque **Esqueceu sua senha?**
3. Confira a caixa de entrada (e spam) por e-mail do Firebase com link de redefinição.
4. Redefina a senha pelo link e teste o login com a nova senha (cenário 2).

#### Integração Firebase + Supabase

1. Faça login (e-mail ou Google).
2. Crie uma tarefa qualquer na home (ex.: “Teste Firebase”).
3. No [Supabase Dashboard](https://supabase.com/dashboard) → **Table Editor** → tabela **`tasks`**:
   - Deve existir a tarefa recém-criada.
   - Coluna **`user_id`** deve corresponder ao **UID** do usuário em Firebase Console → **Authentication** → **Users** → coluna **User UID**.
4. Em **`profiles`**, confira que o perfil foi criado/atualizado para o mesmo UID.

Isso confirma que o JWT do Firebase está sendo aceito pelo Supabase (third-party auth) e que as políticas RLS (`auth.jwt() ->> 'sub'`) funcionam.

#### Sessão e logout

1. **Sessão:** feche o app (remova dos recentes) e reabra — deve manter o usuário logado (token Firebase em cache).
2. **Logout:** **Perfil** → **Sair da conta** → confirme → tela de login reaparece.
3. Opcional: em Firebase Console, o usuário continua listado (logout é no dispositivo); ao logar de novo, a sessão é restabelecida.

### 5.4 Onde verificar cada camada

| O que validar | Onde conferir |
|---------------|---------------|
| Usuário autenticado | Firebase Console → Authentication → Users |
| UID do usuário | Firebase Console → Users → coluna **User UID** |
| Tarefas sincronizadas | Supabase → Table Editor → `tasks` |
| Perfil sincronizado | Supabase → Table Editor → `profiles` |
| Erros de auth no app | Snackbar na tela de login; log do terminal (`flutter run`) |
| Token rejeitado / RLS | Supabase → Logs; confira § 2.3 e migration `002` |

### 5.5 Testes automatizados (Firebase Auth)

Os testes abaixo cobrem login, cadastro, sessão, logout, recuperação de senha e integração com o perfil — usando mocks do Firebase (`firebase_auth_mocks`):

```bash
flutter test test/auth/
```

| Arquivo | O que cobre |
|---------|-------------|
| `test/auth/auth_repository_test.dart` | `AuthRepository` — sign-in, cadastro, reset, sign-out, token, avatar |
| `test/auth/auth_controller_test.dart` | `AuthController` — estados, login, cadastro, erros, visitante, logout |

Outros testes do projeto (NLP, tarefas, conquistas):

```bash
dart test packages/tasker_nlp
flutter test test/tasker_nlp/
```

Documentação de testes do package NLP: **`docs/TESTES_TASKER_NLP.md`**.

A validação em dispositivo real (Google Sign-In, e-mail real) permanece manual — seção 5.2.

---

## 6. Solução de problemas

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

## 7. Arquitetura no código

```
AuthPage → AuthController → AuthRepository (Firebase Auth)
                              → signIn / register / Google / reset / signOut
                              → getIdToken()
AppBootstrap → Supabase.initialize(accessToken: getIdToken)
AuthGate → TaskStore.reload() → TaskSupabaseRepository (RLS via JWT Firebase)
ProfilePage → ProfileSupabaseRepository + signOut
```

Logout: `FirebaseAuth.signOut()` + limpeza do `TaskStore`.

Arquivos principais:

| Arquivo | Responsabilidade |
|---------|------------------|
| `lib/features/auth/data/auth_repository.dart` | Chamadas ao Firebase Auth |
| `lib/core/bootstrap/app_bootstrap.dart` | Inicialização Firebase + Supabase com JWT |
| `lib/core/auth/firebase_user_id.dart` | UID do usuário logado |
| `supabase/migrations/002_firebase_third_party.sql` | RLS compatível com Firebase UID |
