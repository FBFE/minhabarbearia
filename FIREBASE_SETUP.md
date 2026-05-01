# Conexão Firebase - barber-agendamento-2026

## Erro "API key not valid"

Se aparecer o erro `api-key-not-valid` ou `invalid-api-key`, regenere as credenciais:

```bash
dart pub global activate flutterfire_cli
cd e:\SISTEMAS-FLUTTER\minhabarbearia
flutterfire configure
```

1. Selecione o projeto **barber-agendamento-2026**
2. Marque a plataforma **Web**
3. O arquivo `lib/firebase_options.dart` será atualizado automaticamente

---

## Opção 1: Automática (recomendado)

Instale o FlutterFire CLI (uma vez) e execute:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

1. Faça login com a conta Google vinculada ao Firebase
2. Selecione o projeto **barber-agendamento-2026**
3. Marque a plataforma **Web**
4. O arquivo `lib/firebase_options.dart` será gerado com as credenciais corretas

---

## Opção 2: Manual

### Passo 1: Adicionar o app Web no Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Selecione o projeto **barber-agendamento-2026**
3. Clique no ícone de **Web** (</>) em "Adicione um app" ou em "Project Overview"
4. Dê um apelido (ex: "minhabarbearia-web") e marque **Firebase Hosting** se for publicar
5. Clique em **Registrar app**
6. Copie o objeto `firebaseConfig` exibido:

```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "barber-agendamento-2026.firebaseapp.com",
  projectId: "barber-agendamento-2026",
  storageBucket: "barber-agendamento-2026.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123def456"
};
```

### Passo 2: Preencher firebase_options.dart

Abra `lib/firebase_options.dart` e substitua os placeholders pelos valores do `firebaseConfig`:

| Placeholder | Substituir por |
|-------------|----------------|
| `COLE_SUA_API_KEY_AQUI` | `apiKey` |
| `COLE_SEU_APP_ID_AQUI` | `appId` |
| `COLE_MESSAGING_SENDER_ID_AQUI` | `messagingSenderId` |
| `projectId` | Já preenchido com `barber-agendamento-2026` |
| `authDomain` | Já preenchido |
| `storageBucket` | Já preenchido |

---

## Domínios autorizados (Web)

Para o app rodar em **localhost** ou **127.0.0.1**:

1. No Firebase: **Authentication** → **Settings** (Configurações) → aba **Authorized domains** (Domínios autorizados).
2. Confirme que existem:
   - `localhost`
   - `127.0.0.1`
3. Se estiver faltando, clique em **Add domain** e adicione `127.0.0.1` (o `localhost` costuma vir por padrão).

Sem isso, o login/cadastro pode falhar com erro de domínio não autorizado.

---

## Inicialização (já configurada)

O `main.dart` já inicializa o Firebase antes de rodar o app:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(...);
}
```

## Provider de autenticação

Para checar se o usuário está logado:

```dart
class MeuWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    if (isLoggedIn) {
      return Text('Logado');
    }
    return Text('Não logado');
  }
}
```

Ou use `currentUserProvider` para obter o `User`:

```dart
final user = ref.watch(currentUserProvider);
// user != null → logado
// user?.email, user?.uid, etc.
```
