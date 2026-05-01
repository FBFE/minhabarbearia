# Eugenio Software - Site para Stripe

## Formspree (formulário de contato)

1. Acesse [formspree.io](https://formspree.io) e crie uma conta grátis.
2. Clique em **New form** e dê um nome (ex: "Eugenio Contato").
3. Copie o endpoint (algo como `https://formspree.io/f/xyzwabcd`).
4. No `index.html`, substitua `https://formspree.io/f/seu-id` pelo seu endpoint (troque apenas a parte `seu-id` pelo ID do Formspree).

## WhatsApp flutuante

No `index.html`, localize o link do botão WhatsApp e troque `5565999999999` pelo seu número com DDI (55), DDD e número, sem espaços. Exemplo: 5565991234567.

## Deploy no Firebase Hosting (projeto barber-agendamento-2026)

Execute no terminal, **na pasta do site**:

```bash
cd eugenio-software-site
firebase login
firebase use barber-agendamento-2026
firebase init hosting
```

Quando perguntar:
- **What do you want to use as your public directory?** → Digite: `.` (ponto, para usar a própria pasta atual como raiz do site)
- **Configure as a single-page app?** → N (No)
- **Set up automatic builds with GitHub?** → N (No)

Depois:

```bash
firebase deploy --only hosting
```

A URL será algo como: **https://barber-agendamento-2026.web.app** (ou o domínio do seu projeto).

Se o seu projeto Firebase for outro (ex: flow-studio-10), use `firebase use SEU_PROJECT_ID` em vez de barber-agendamento-2026.
