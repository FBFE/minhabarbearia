# Conectar o app ao projeto Flow Studio 10

O app já está apontando para o projeto **flow-studio-10** (Firebase CLI e parte da configuração).  
Falta só preencher **apiKey** e **appId** no código.

## Opção A – Automático (recomendado)

No terminal, na pasta do projeto:

```bash
flutterfire configure
```

1. Se perguntar se quer reutilizar o `firebase.json`, responda **n** (não).
2. Escolha o projeto **Flow Studio 10** / **flow-studio-10** na lista.
3. O comando vai gerar o `lib/firebase_options.dart` com **apiKey** e **appId** corretos.

## Opção B – Manual (pelo Firebase Console)

1. Acesse o [Firebase Console](https://console.firebase.google.com) e abra o projeto **Flow Studio 10**.
2. Clique na **engrenagem** → **Configurações do projeto**.
3. Em **Seus apps**, se não existir app Web:
   - Clique em **</>** (Adicionar app Web).
   - Dê um nome (ex.: `minhabarbearia-web`) e registre.
4. Copie o **apiKey** e o **appId** do objeto `firebaseConfig` que aparecer.
5. Abra **`lib/firebase_options.dart`** e substitua:
   - `'COLE_AQUI_API_KEY_DO_APP_WEB'` → pelo **apiKey**.
   - `'COLE_AQUI_APP_ID_DO_APP_WEB'` → pelo **appId**.

---

## O que já foi configurado

- **.firebaserc** → projeto padrão: `flow-studio-10`
- **lib/firebase_options.dart** → `projectId`, `authDomain`, `storageBucket`, `messagingSenderId` já estão para **flow-studio-10**
- **Certificados push da Web** → chave VAPID do projeto Flow Studio 10 já está em **fcm_provider.dart** (par de chaves que você adicionou em 19/02/2026)

Depois de preencher apiKey e appId (Opção A ou B), rode o app e faça o deploy normalmente.
