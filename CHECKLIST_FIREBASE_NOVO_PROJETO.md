# Checklist: o que tinha no outro projeto e o que fazer no Flow Studio 10

Quando você respondeu **yes** no `flutterfire configure`, ele pode ter reutilizado o projeto antigo do `firebase.json`. Confira o que fazer no **novo** projeto.

---

## O que existia no projeto antigo (barber-agendamento-2026)

### No Firebase Console
1. **Authentication** – ativado, com **E-mail/senha** (login do dono e cadastro/login do cliente).
2. **Firestore Database** – banco criado; regras publicadas (`firestore.rules`).
3. **Storage** – ativado; regras para `logos/`, `backgrounds/`, `barbershops/{slug}/clients/` (`storage.rules`).
4. **Hosting** – app web publicado (`flutter build web` + `firebase deploy --only hosting`).
5. **Cloud Messaging** – ativado; **Certificados push da Web** (par de chaves VAPID) configurado.
6. **App Web** – um app **</>** registrado, que gera o **apiKey** e **appId** usados no `firebase_options.dart`.

### No projeto Flutter
- `lib/firebase_options.dart` – projectId, apiKey, appId, authDomain, storageBucket, messagingSenderId.
- `lib/src/core/providers/fcm_provider.dart` – constante **kFcmVapidKey** com a chave pública VAPID.
- `.firebaserc` – projeto padrão para `firebase deploy`.
- `firestore.rules` e `storage.rules` – publicados no projeto com `firebase deploy`.

---

## O que fazer no Flow Studio 10 (novo projeto)

### 1. Firebase Console (flow-studio-10)

| Item | Onde | Ação |
|------|------|------|
| **Authentication** | Build → Authentication | Ativar; em “Sign-in method”, ativar **E-mail/senha**. |
| **Firestore** | Build → Firestore Database | Criar banco (produção ou teste); depois publicar as regras (passo 3 abaixo). |
| **Storage** | Build → Storage | Ativar; depois publicar as regras (passo 3 abaixo). |
| **Hosting** | Build → Hosting | Só precisa existir; o deploy é feito pelo CLI. |
| **Cloud Messaging** | Configurações do projeto → Cloud Messaging | Já está; **Certificados push da Web** você já adicionou (chave no app está em `fcm_provider.dart`). |
| **App Web** | Configurações do projeto → Seus apps | Se **não** tiver app **</>**, clique em **Adicionar app** → **Web**. Copie **apiKey** e **appId** e cole no `lib/firebase_options.dart` (substituir `COLE_AQUI_...`). |

### 2. Completar `firebase_options.dart`

O arquivo já tem **projectId**, **authDomain**, **storageBucket** e **messagingSenderId** para **flow-studio-10**.  
Falta só:

- **apiKey**
- **appId**

**Opção A:** No Console do **Flow Studio 10** → Configurações do projeto → Seus apps → app Web → copiar **apiKey** e **appId** e colar no `lib/firebase_options.dart` (no lugar de `COLE_AQUI_API_KEY_DO_APP_WEB` e `COLE_AQUI_APP_ID_DO_APP_WEB`).

**Opção B:** Rodar de novo no terminal:
```bash
flutterfire configure
```
Quando perguntar se quer reutilizar o `firebase.json`, responder **n** (não) e escolher o projeto **Flow Studio 10** (flow-studio-10). Assim o FlutterFire gera o `firebase_options.dart` com apiKey e appId do novo projeto.

### 3. Publicar regras e fazer deploy

No terminal, na pasta do projeto:

```bash
firebase use flow-studio-10
firebase deploy --only firestore:rules,storage
flutter build web
firebase deploy --only hosting
```

---

## Resumo rápido

- **No outro projeto você tinha:** Auth (e-mail/senha), Firestore, Storage, Hosting, Cloud Messaging, app Web e regras publicadas.
- **No Flow Studio 10:** ativar os mesmos serviços, garantir que existe **app Web** e preencher **apiKey** e **appId** no `firebase_options.dart`, depois publicar regras e fazer deploy como acima.
