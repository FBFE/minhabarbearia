# Minha Barbearia

Sistema de agendamento para barbearias desenvolvido em Flutter Web, com suporte a tema dinâmico via Firestore.

## Tecnologias

- **Flutter** 3.24+
- **Riverpod** 2.0+ (State Management)
- **GoRouter** (Rotas)
- **Firebase** (Auth, Firestore, Storage)

## Estrutura do Projeto

```
lib/
├── main.dart
└── src/
    ├── config/          # Configurações (Firebase, Router)
    ├── core/            # Models, Providers, lógica compartilhada
    │   ├── models/
    │   └── providers/
    ├── features/        # Features da aplicação
    │   ├── auth/
    │   ├── splash/
    │   └── public_booking/
    └── shared/          # Widgets e utilitários compartilhados
```

## Setup Firebase

### 1. Instalar FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 2. Configurar Firebase no projeto

```bash
cd minhabarbearia
dart run flutterfire configure
```

O comando irá:
- Criar/vincular um projeto Firebase
- Gerar o arquivo `lib/firebase_options.dart`
- Configurar as plataformas (Web, Android, iOS)

### 3. Configurar o Firebase Console

#### 3.1 Authentication
1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Selecione seu projeto
3. Vá em **Authentication** → **Sign-in method**
4. Habilite **E-mail/Senha**

#### 3.2 Firestore
1. Vá em **Firestore Database** → **Criar banco**
2. Escolha o modo de produção e localização
3. Crie a coleção `barber_shops` com documentos no formato:

```json
{
  "name": "Corte Legal",
  "slug": "cortelegal-mt",
  "logoUrl": "https://exemplo.com/logo.png",
  "primaryColor": 4280391411,
  "secondaryColor": 4283467747,
  "createdAt": "2025-01-01T00:00:00.000Z",
  "updatedAt": "2025-01-01T00:00:00.000Z"
}
```

**Nota sobre cores:** Use o valor inteiro da cor (ex: `0xFF1A1A2E` = 4280391411)

#### 3.3 Storage
1. Vá em **Storage** → **Começar**
2. Configure as regras conforme necessário

### 4. Regras de Segurança Firestore (exemplo)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /barber_shops/{shopId} {
      allow read: if true;  // Público pode ler
      allow write: if request.auth != null;
    }
  }
}
```

## Executando o Projeto

```bash
# Dependências
flutter pub get

# Web (Chrome)
flutter run -d chrome

# Build para produção
flutter build web
```

## Rotas

| Rota | Descrição |
|------|-----------|
| `/` | Splash - redireciona para Login ou página pública |
| `/login` | Tela de login |
| `/b/:slug` | Página pública de agendamento (ex: `/b/cortelegal-mt`) |

## URL com Slug

Para acessar diretamente uma barbearia pública:

```
https://seuapp.com/?slug=cortelegal-mt
```

O Splash detecta o parâmetro e redireciona para `/b/cortelegal-mt`.

## Model BarberShop

| Campo | Tipo | Descrição |
|-------|------|-----------|
| name | String | Nome da barbearia |
| slug | String | Identificador único na URL |
| logoUrl | String? | URL do logo |
| primaryColor | int | Cor primária (tema) |
| secondaryColor | int | Cor secundária (tema) |

## Regenerar código (opcional)

Se alterar modelos com `@JsonSerializable`:

```bash
dart run build_runner build --delete-conflicting-outputs
```
