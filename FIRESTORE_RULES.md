# Regras do Firestore

No Firebase Console → **Firestore Database** → **Regras**.

## Opção 1 – Só logado (dashboard; página pública não funciona)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Opção 2 – Testes (página pública + agendamento funcionando)

Para `/b/:slug` carregar e visitantes poderem agendar:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /barbershops/{slug} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /appointments/{id} {
      allow create: if true;
      allow read, update, delete: if request.auth != null;
    }
  }
}
```

Use a opção 2 só em ambiente de teste. Depois ajuste conforme LGPD e segurança.
