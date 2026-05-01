# Gerar a URL do site (deploy)

O **firebase.json** do projeto já está com os dois sites (app + Eugenio). Falta só criar o site no Firebase e rodar o deploy.

## 1. Criar o site "eugeniosoftware" no Firebase

1. Acesse [Console Firebase](https://console.firebase.google.com) e abra o projeto **flow-studio-10**.
2. No menu, vá em **Hosting**.
3. Clique em **Adicionar outro site** (ou "Add another site").
4. Quando pedir o **ID do site**, use exatamente: **eugeniosoftware**.
5. Confirme.

## 2. Fazer o deploy

No terminal, na pasta **minhabarbearia** (raiz do projeto):

```bash
firebase deploy --only hosting
```

Isso publica o app (build/web) e o site da Eugenio (eugenio-software-site).

## 3. URL do site

Depois do deploy, o site da Eugenio Software estará em:

**https://eugeniosoftware.web.app**

Use essa URL no Stripe e onde quiser divulgar.
