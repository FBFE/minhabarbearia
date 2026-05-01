# Conectar o app ao novo projeto Firebase

## Opção 1 – FlutterFire (recomendado)

1. **Instale o FlutterFire CLI globalmente** (só uma vez):
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. **Na pasta do projeto**, rode:
   ```bash
   flutterfire configure
   ```
   (Se der "comando não encontrado", use: `dart run flutterfire configure` após `dart pub global activate flutterfire_cli` e confira se o PATH inclui o cache do Dart/pub.)

3. **Selecione o novo projeto** na lista (use as setas e Enter).

4. O comando vai:
   - Gerar/atualizar o arquivo `lib/firebase_options.dart` com os dados do novo projeto
   - Atualizar o `.firebaserc` para o projeto escolhido (se aplicável)

5. **Defina o projeto padrão do Firebase CLI** (para deploy):
   ```bash
   firebase use <ID_DO_NOVO_PROJETO>
   ```
   Exemplo: `firebase use meunegocio2026`

---

## Opção 2 – Manual

1. No **Firebase Console** do **novo** projeto:
   - Configurações do projeto (engrenagem) → **Seus apps**
   - Se não tiver app Web, clique em **</>** (Web) e registre (ex.: nome "minhabarbearia-web")
   - Copie o objeto de configuração (apiKey, appId, projectId, authDomain, storageBucket, etc.)

2. No projeto Flutter, edite **`lib/firebase_options.dart`** e troque os valores pelos do novo projeto:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `authDomain`
   - `storageBucket`

3. No terminal, aponte o Firebase CLI para o novo projeto:
   ```bash
   firebase use <ID_DO_NOVO_PROJETO>
   ```

4. No **novo** projeto, ative os mesmos serviços do antigo:
   - **Authentication** (métodos que você usa, ex.: E-mail/senha)
   - **Firestore Database**
   - **Storage**
   - **Hosting**

5. Publicar regras e fazer deploy quando quiser:
   ```bash
   firebase deploy --only firestore:rules,storage
   flutter build web
   firebase deploy --only hosting
   ```

---

## Depois de conectar

- O app passa a usar **só** o novo projeto (Auth, Firestore, Storage).
- O **Firestore e o Auth do novo projeto começam vazios**; não há cópia automática do projeto antigo.
- Para publicar no Hosting do novo projeto: `flutter build web` e `firebase deploy --only hosting`.
