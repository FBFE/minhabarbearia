# Configuração: Painel Admin e Stripe

## Painel Admin (dono do app)

Acesso ao painel **`/admin`** (Cloud Function `getAdminDashboard`), por ordem:

1. **E-mail:** conta em Firebase Auth com e-mail `fabianoeugenio96@gmail.com` (Google).
2. **Firestore (opcional):** documento `app_config/config`, campo `adminUids` (array de UIDs). Quando existir e tiver entradas, esses UIDs também são admin.
3. **Fallback no código:** lista `ADMIN_UID_LEGACY` em `functions/index.js` (UIDs legados, incl. conta recriada no Auth).

Para recriar conta e manter admin sem alterar código, basta usar o **mesmo Google** com esse e-mail — ou acrescente o novo UID em `adminUids` no Firestore / em `ADMIN_UID_LEGACY` no código.

**No app:** o dashboard também trata `fabianoeugenio96@gmail.com` como admin no cliente (ícone escudo), além da API.

**Deploy** após alterar `functions/index.js`:

```bash
firebase deploy --only functions
```

---

## Trial e assinatura (já implementado no app)

- **Novo cadastro:** o dono da barbearia ganha **20 dias grátis** (trial). Os campos `trialEndsAt` e `subscriptionStatus: 'trial'` são definidos na criação do negócio.
- **Aviso:** 5 dias antes do fim do trial, aparece um banner no dashboard pedindo para assinar.
- **Após o trial:** se não assinar, o banner fica vermelho ("Seu acesso expirou") e o botão "Assinar" leva à página de assinatura (Stripe em configuração).

---

## Stripe (integração pronta)

A página **Assinar** (`/dashboard/assinar`) chama a Cloud Function **createCheckoutSession** e abre o Stripe Checkout. Para ativar:

### 1. Chave secreta no Firebase

No terminal, na pasta do projeto (minhabarbearia):

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
```

Quando pedir, cole a **Chave secreta** do Stripe (Dashboard Stripe → Desenvolvedores → Chaves da API → Chave secreta, começa com `sk_live_...`).

### 2. IDs no app (Stripe)

No projeto Flutter, abra **`lib/src/config/stripe_config.dart`**:

- **stripeMonthlyPriceId**: ID do **preço** da assinatura mensal (começa com `price_...`, ex.: R$ 29,90/mês). Esse ID deve ser o **ativado** e **padrão** do produto no Dashboard Stripe.

### Erro 403 no `firebase functions:secrets:set` (permissão)

O Google Cloud exige **permissão no projeto** `flow-studio-10` (por ex. **Owner**, **Editor** ou **Secret Manager Admin** + **Cloud Functions Admin**). O comando `firebase functions:secrets:set NOME` **não** recebe o valor na linha de comando: ele abre o editor para colar o segredo. O `we_...` que aparece no Stripe é o **ID do destino**, não o nome do segredo (use `STRIPE_WEBHOOK_SECRET` ou outro nome que o código espere). Se não tiver acesso ao Firebase/GCP, peça a um dono do projeto **ou** use só o webhook no **Supabase** (seção abaixo), com segredos no **Dashboard do Supabase**, sem depender do `firebase` CLI.

---

### 3. Webhook no **Supabase** (quando a URL for `...supabase.co/functions/v1/stripe-webhook`)

Se o Stripe aponta para o Supabase (como o seu), o segredo `whsec_...` fica no **Supabase** (não no Firebase):

- **Project Settings → Edge Functions → Secrets** (ou `supabase secrets set`):
  - `STRIPE_WEBHOOK_SECRET` = o **Segredo de assinatura** do **mesmo** endpoint que você vê no Stripe (começa com `whsec_`).
  - `FIREBASE_PROJECT_ID` = `flow-studio-10` (ou o id do seu projeto Firebase).
  - `GOOGLE_SERVICE_ACCOUNT` = JSON completo (uma linha) de uma **conta de serviço** do Google com permissão de leitura/escrita no **Firestore** (ex.: no GCP: IAM → criar chave JSON; função: **Cloud Datastore User** no projeto, ou crie a chave em Firebase Console → Contas de serviço).
  - `STRIPE_SECRET_KEY` = chave `sk_...` (recomendado para o fallback buscar a assinatura no Stripe se o Firestore ainda não tiver `slug`).

Código de referência no repositório: `supabase/functions/stripe-webhook/index.ts`. Deploy (com [Supabase CLI](https://supabase.com/docs/guides/cli)):

```bash
supabase link --project-ref SEU_REF
supabase secrets set --env-file supabase/.env
supabase functions deploy stripe-webhook
```

A URL pública fica: `https://<ref>.supabase.co/functions/v1/stripe-webhook` (deve bater com o que está no painel do Stripe). **Não** commite o `whsec` no Git. Se ele foi exposto, **gire** o segredo no Stripe (novo endpoint / novo whsec) e atualize o Supabase.

**Escolha um único destino** no Stripe: ou a função do **Firebase** (`stripeWebhook` na `us-central1`) **ou** a do **Supabase**. Os dois ativos com o mesmo fluxo duplicam atualizações (geralmente inofensivo, porém confuso em logs).

### 3b. Webhook no **Firebase** (passo a passo)

A função HTTP **`stripeWebhook`** está em `functions/index.js` (região `us-central1`, `invoker: 'public'`, corpo bruto JSON para o Stripe). Use **um** destino: se este estiver ativo, **remova** ou desative o endpoint duplicado no Supabase (ou vice-versa) para não confundir entregas.

#### A) Conta e permissão

1. `firebase login` (conta com acesso ao projeto `flow-studio-10`).
2. Se `firebase functions:secrets:set` retornar **403**, o usuário precisa de papel no **Google Cloud** do projeto, por ex. **Proprietário**, **Editor** ou **Secret Manager Admin** (definir segredos) e permissão de deploy (Cloud Build / Cloud Functions). Peça a um dono do projeto se necessário.

#### B) Definir segredos (nomes fixos, valores no editor)

No terminal, na raiz do repositório:

```bash
cd functions
firebase use flow-studio-10
```

Em seguida, **cada** comando abre o editor: cole o valor, salve, feche. **Não** coloque o segredo no nome do comando; o nome é o primeiro argumento abaixo.

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

- **STRIPE_SECRET_KEY**: chave secreta do Stripe (Dashboard → Desenvolvedores → Chaves da API) — `sk_live_...` (produção) ou `sk_test_...` (teste).
- **STRIPE_WEBHOOK_SECRET**: só depois de criar o endpoint no Stripe (passo D): no painel do endpoint, abra **Segredo de assinatura** (começa com `whsec_...`). Se ainda não tiver endpoint para a URL do Firebase, crie o endpoint com uma URL provisória, copie o `whsec`, defina o secret, depois ajuste a URL (ou crie o endpoint já com a URL do passo C).

#### C) Deploy e URL da função

```bash
cd ..
firebase deploy --only functions:stripeWebhook
```

(ou `firebase deploy --only functions` para publicar tudo.) No final do deploy, a URL fica no formato:

`https://us-central1-flow-studio-10.cloudfunctions.net/stripeWebhook`

**Importante (Gen2 / Cloud Run):** o código define `invoker: 'public'` para o Stripe poder fazer `POST` sem token. Se ainda receber 403, no [Google Cloud Console](https://console.cloud.google.com/) → **Cloud Run** → serviço `stripewebhook` (ou similar) → **Permissões** → verifique se **allUsers** tem **Cloud Run Invoker** (ou re-deploy com a opção pública; o Firebase geralmente aplica isso com `invoker: 'public'`).

#### D) No Stripe: criar o endpoint (desenvolvedor)

1. Dashboard Stripe (modo **Produção** ou **Teste** conforme as chaves).
2. **Desenvolvedores** → **Webhooks** → **Adicionar destino** (ou editar o existente).
3. **URL do endpoint** = a URL do passo C (exatamente, incluindo `https`, sem barra a mais no fim se o Stripe rejeitar).
4. Selecione os eventos (mínimo que o app trata):
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid` e/ou `invoice.payment_succeeded`
   - `invoice.payment_failed`
   - `refund.created` (reembolsos e histórico, se quiser rastrear no app)
5. Salve, abra o destino e copie o **Segredo de assinatura** (`whsec_...`).
6. Se ainda não tiver colado: `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET` e cole esse `whsec`, depois `firebase deploy --only functions:stripeWebhook` (para a revisão enxergar o novo segredo).

#### E) Conferir entregas

- Stripe → Webhooks → seu destino → **Entregas**: um envio de teste ou um pagamento real deve retornar **200** (e no Firebase: **Registros** da função `stripeWebhook` sem erro de assinatura).

**Teste local (opcional):** com [Stripe CLI](https://stripe.com/docs/stripe-cli): `stripe listen --forward-to https://us-central1-flow-studio-10.cloudfunctions.net/stripeWebhook` (use a **chave de encaminhamento** `whsec_...` do CLI no lugar do whsec de produção só para o ambiente de teste).

### 4. Confirmação após o Checkout (já no app)

Após o pagamento, o Stripe redireciona para `/dashboard/assinar?session_id=...&success=1`. O app chama a callable **`syncSubscriptionFromCheckout`**, que grava `stripeCustomerId`, `stripeSubscriptionId`, `subscriptionStatus: 'active'` e `plan: 'pro'` no documento `barbershops/{slug}`. A URL do site usa **caminho sem hash** (path) + rewrite no `firebase.json` para o PWA; faça `flutter build web` e deploy do **Hosting** com as rotas de SPA.

### 5. Deploy das functions

```bash
firebase deploy --only functions
```

Depois disso, ao clicar em "Assinatura mensal" na tela Assinar, o dono abre o Stripe Checkout; ao concluir, o retorno e/ou o webhook atualizam o Firestore.

---

## Desconto de aniversário (já implementado)

No mês de aniversário do **cliente** (data de nascimento cadastrada), é aplicado **10% de desconto** no total do agendamento. O valor já aparece na página de agendamento ("10% mês aniversário") e é salvo no appointment com `birthdayDiscountApplied: true`.
