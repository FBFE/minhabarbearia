# Cloud Functions – Minha Barbearia

- **onAppointmentCreated:** ao criar um agendamento em `appointments/{id}`, envia push para:
  - Dono: `barbershops/{slug}.ownerFcmTokens` (array)
  - Cliente: `barbershops/{slug}/clients/{clientId}.fcmTokens` (array)
- **sendAppointmentReminders:** a cada 5 min, busca agendamentos entre 25 e 35 min à frente, envia lembrete ao cliente e marca `reminderSent: true`.

## Pré-requisitos

- Projeto no **plano Blaze**
- Node.js 18+

## Índice Firestore (lembretes)

Se o Firestore pedir índice para a query de lembretes, crie um índice composto em `appointments`:
- `dateTime` (Ascending)
- `status` (Ascending)

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```
