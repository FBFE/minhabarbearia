# MinhaBarbearia / Meu Negócio — detalhamento completo para layout no Figma

Documento de referência com **rotas, fluxos, campos, textos, estados, dados e regras** do aplicativo (Flutter Web + Firebase) para criação de um novo visual no Figma.

**Plataforma alvo hoje:** Web (PWA).  
**Nome de produto no app:** “Meu Negócio”.

---

## 1. Perfis e papéis

| Papel | Quem | Onde acessa |
|------|------|-------------|
| **Dono** | Criou conta `/login` ou `/register` (e-mail/senha ou Google) | `/dashboard` |
| **Admin do app** | UID na lista de admins no Firestore (`app_config` / regra do projeto) | `/admin` |
| **Cliente** | Sem ser “dono do app”; identifica-se por WhatsApp+data nasc. ou e-mail/senha (ou Google) no link do negócio | `/b/{slug}/*` |
| **Funcionário** | E-mail cadastrado em `barbershops/{slug}/staff` | `/b/{slug}/funcionario` |

**Autenticação Firebase (dono, opcionalmente cliente/func.):** e-mail e senha; **Google (popup, só web)** nas telas de dono, cliente (login) e funcionário.

---

## 2. Mapa de URLs (rotas)

| Rota | Nome lógico |
|------|-------------|
| `/` | Splash |
| `/login` | Login dono |
| `/register` | Cadastro dono |
| `/admin` | Painel global (só admin) |
| `/dashboard` | Dashboard dono (6 abas) |
| `/dashboard/settings` | Configurações do negócio |
| `/dashboard/assinar` | Assinatura (Stripe) |
| `/b/{slug}` | Página pública: agendamento (início) |
| `/b/{slug}/agenda` | Agenda do cliente |
| `/b/{slug}/fidelidade` | Fidelidade |
| `/b/{slug}/perfil` | Perfil do cliente |
| `/b/{slug}/cadastro` | Cadastro do cliente no negócio |
| `/b/{slug}/login` | Login do cliente (conta nesse negócio) |
| `/b/{slug}/complete-profile` | Completar perfil pós Google (dados + LGPD) |
| `/b/{slug}/funcionario` | Acesso funcionário (Google) |
| `/b/{slug}/funcionario/agenda` | Minha agenda (staff) |

**Regra de redirect:** acesso a `/b/{slug}` com `?ref=...` (indicação) redireciona para `/b/{slug}/cadastro?ref=...` para pré-preencher “quem indicou”.

**Regra geral de auth:** se estiver logado (dono) e acessar `/login` ou `/register` → vai para `/dashboard`. Sem login, `/dashboard` e `/admin` → `/login`.

---

## 3. Sistema de design (referência do código atual)

- **Fonte:** Poppins (Google Fonts).
- **Tema dono padrão (sem negócio carregado no tema):** roxo (`#9333EA`), fundos claro, cards com borda cinza (`#E5E7EB`), input fundo (`#F3F3F5`), radius ~10px.
- **Página pública do negócio:** **cores vêm do Firestore** (primária e secundária do `BarberShop`) — ao desenhar no Figma, prever **tema claro** + **barras e botões** aplicando a cor do negócio.
- **Dashboard dono (layout recente):** AppBar branca, borda inferior, fundo de conteúdo cinza muito claro (`#F9FAFB`); destaque de item na bottom bar com cor primária (roxo do negócio ou reserva no tema padrão).

---

## 4. Tela: Splash (`/`)

**Comportamento:** ~800 ms; depois:
- se URL tiver `?slug=xxx` → `/b/xxx`
- se usuário autenticado → `/dashboard`
- senão → `/login`

**Conteúdo visual:** fundo em gradiente roxo/rosa/roxos; círculo com ícone de tesoura; título “Meu Negócio”; indicador de carregamento.

---

## 5. Autenticação do dono

### 5.1 Login (`/login`)

**Headline:** “Meu Negócio”  
**Subtítulo:** “Entre para gerenciar seu negócio”

**Formulário (card branco, borda leve):**
- Campo **E-mail** (hint: `seu@email.com`)
- Campo **Senha** (mascarada)
- Link **“Esqueci minha senha”** (abre diálogo: e-mail, botões Cancelar / Enviar link — reset Firebase)
- Botão primário **“Entrar”**
- Divisória **“ou”**
- Botão contorno **“Continuar com Google”** (ícone estilo Google / `g_mobiledata` no código) — *só web ativa; no layout pode ser botão padrão “Continuar com Google”*

**Rodapé:** “Ainda não tem conta? Cadastre-se” → `/register`

**Após sucesso (e-mail ou Google):** `/dashboard`

### 5.2 Cadastro dono (`/register`)

**Título:** “Criar conta”  
**Subtítulo:** “Preencha os dados para se cadastrar”

**Campos:** E-mail, Senha, Confirmar senha.  
**Botão:** “Cadastrar”  
**ou +** “Cadastrar com Google” (mesmo padrão do login).  
**Rodapé:** “Já tem conta? Entrar” → `/login`

**Regra:** senha mín. 6 caracteres; confirmação deve coincidir.

---

## 6. Dashboard do dono (`/dashboard`)

**Estrutura:** uma tela com **barra superior** (título = nome da aba atual; ações: **Admin** se permitido, **Configurações**, **Sair**) + **conteúdo** + **bottom navigation** fixa (6 itens).

**Abas (rótulos e função resumida):**

| Aba | Título AppBar | Função |
|-----|----------------|--------|
| Início | Início | Resumo, link do negócio, trial/assinatura, vincular negócio se vazio |
| Agenda | Agenda | Calendário + lista de agendamentos do dia/negócio |
| Serviços | Serviços | CRUD de serviços, categorias, imagem, consumo de estoque |
| Clientes | Clientes | Lista e gestão de clientes |
| Estoque | Estoque | Produtos, movimentações, baixas |
| Relatórios | Relatórios | DRE, gráficos receita x despesas, lucro |

### 6.1 Aba Início

- **Boas-vindas** (“Bem-vindo ao Dashboard”)
- Exibe e-mail do usuário logado
- Se **já houver** `BarberShop` vinculado: banner de **período de teste** ou aviso de **assinatura** (dias restantes, expirado, CTA “Assinar” / “Continuar”); resumo e link público do negócio
- Se **não houver** negócio: fluxo de **vincular/criar** negócio (nome, slug, etc., conforme implementação do card)

*Trial padrão no código de criação do negócio:* **20 dias**; status `subscriptionStatus` pode ser: `trial` | `active` | `past_due` | `canceled` | `none`.

### 6.2 Aba Serviços (detalhe para Figma do modal/sheet)

Campos típicos de serviço:
- Nome, **Preço (R$)**, **Duração (min)** (5–240)
- **Imagem** (foto do corte) — escolher arquivo, preview
- **Detalhes / descrição** (opcional)
- **Categoria** (dropdown): *Cortes, Barba, Manicure, Pedicure, Sobrancelhas, Cílios, Outros*
- **Produtos consumidos** (vinculados ao estoque): produto, quantidade ou “uso no studio (%)” — texto explicativo no app sobre baixa ao concluir atendimento

Ações: **Adicionar serviço**, editar, salvar, excluir (conforme UI).

### 6.3 Aba Agenda (dono)

- Seletor de data (**TableCalendar**)
- Cards de agendamento: horário, cliente, serviço(s), profissional, status (`pending` / `confirmed` / `completed` / `canceled`)
- Ações de confirmação, cancelamento, conclusão (conforme implementação)

### 6.4 Aba Clientes

- Lista com busca; dados: nome, WhatsApp, nascimento, e-mail, CPF, pontos, indicação, etc.

### 6.5 Aba Estoque

- Produtos, entradas/saídas, “retirar para uso no studio”, movimentos ligados a serviços

### 6.6 Aba Relatórios (DRE)

- **DRE mês corrente:** receita serviços, receita produtos, receita total, CMV, lucro bruto, despesas operacionais, lucro líquido, variação mês anterior, projeção (média 3 meses) onde aplicável
- **Gráfico:** Receita x Despesas por mês
- **Gráfico:** Lucro líquido ao longo dos meses
- Botão **+ Adicionar despesa** (despesa operacional mês corrente: descrição, valor)
- Cores/estilos: destaque verde/vermelho em métricas; gráficos com legenda (Receita / Despesas), eixo de tempo abreviado (ex. `out/25` em pt-BR)

### 6.7 Configurações (`/dashboard/settings`)

Formulário do negócio (nome, slug, cores primária/secundária, **logo**, **fundo** da landing, horário abertura/fechamento, tipos de negócio, fidelidade, indicação, `singleAttendant` — “só o dono atende” vs. tem funcionários, etc.).  
**AppBar:** “Configurações” + voltar.

### 6.8 Assinatura (`/dashboard/assinar`)

- Título: continuar usando o app, assinatura mensal via **Stripe**
- Card “Assinatura mensal” com CTA (abre checkout externo)
- Texto lembrete sobre Stripe e trial

### 6.9 Admin (`/admin`)

- Lista de **todos os negócios** (nome, slug, datas, status assinatura)
- Só acessa quem for admin; senão mensagem de acesso negado e voltar ao dashboard

---

## 7. Experiência do cliente (página pública) — `slug` do negócio

Todas as telas abaixo (exceto funcionário) usam, em geral, **shell com bottom nav** (quando implementado no shell): **Início | Agenda | Fidelidade | Perfil** — item ativo na cor **primária do negócio**.

### 7.1 Início = fluxo de agendamento (`/b/{slug}`)

**AppBar:** nome do negócio (cor de fundo = primária do negócio)

**Cabeçalho da página (corpo):**
- Nome do negócio (título)
- Tipo de negócio (label humanizada a partir de `businessTypes` — barbershop, beauty_salon, etc.)
- “Agende seu horário”
- **Funcionamento:** `openTime` às `closeTime` (ex. 9h–19h)

**Fluxos internos (máquina de estados resumida):**

1. **Identificação do cliente (WhatsApp + data nasc. dd/mm/aaaa)**  
   - Botão **“Verificar cliente”**; se achar, preenche session e avança  
   - Se não achar, mensagem e modo **novo cadastro** (campos: nome, WhatsApp, nasc. obrigatório, endereço opc., “quem te indicou?” WhatsApp opcional, etc.)

2. **Alternativas no topo (quando aplicável):** atalhos **“Cadastrar”** (rota cadastro) e **“Entrar”** (rota login cliente) para quem tem conta e-mail.

3. **Carrinho de serviços:**  
   - Escolhe serviço em dropdown, **“Adicionar ao carrinho”**; lista do carrinho com nome, preço, duração  
   - Categorias e descrição podem aparecer no card de seleção

4. **Profissional:** dropdown (se houver `staff` e `singleAttendant` falso) — ou só dono

5. **Data e hora:** calendário + slots; validações (mín. um serviço, horário futuro, slot selecionado)

6. **Cupom (opcional):** campo “código promocional”, **Aplicar**; feedback de válido/inválido/já usado

7. **Confirmação e gravação** do agendamento; pode haver CTA de **notificações** (FCM/permission)

8. **Pós-confirmar / convite:** ações “Compartilhar convite (WhatsApp)”, “Copiar link” (link com `?ref=`), para programa de indicação

**Regras de negócio (importante no copy/visual):**  
- Desconto de **10%** no **mês de aniversário** (com base na data de nascimento), quando aplicável no total.

**Estados vazios / erro:** negócio não encontrado, carregando, retry.

### 7.2 Cadastro cliente (`/b/{slug}/cadastro`)

**Campos (entre outros no código):** Nome, Data nascimento, WhatsApp, E-mail, CPF opc., Senha, Confirmar senha, **LGPD** obrigatório, **quem te indicou** (pré-preenchido com `?ref=`), estilo de cartão fidelidade (masculino/feminino).  
**Ação final:** cria `Client` + Auth; snackbars de sucesso/erro.

### 7.3 Login cliente (`/b/{slug}/login`)

E-mail + senha; valida se existe cliente nesse `slug` com mesmo auth.  
Sucesso: pode oferecer **PWA “Salvar como app”**; depois **Perfil** (`/b/{slug}/perfil`).

### 7.4 Completar perfil Google (`/b/{slug}/complete-profile`)

Pós Google sem cadastro: nome, nasc., WhatsApp, CPF opt., **LGPD**, estilo fidelidade.

### 7.5 Agenda do cliente (`/b/{slug}/agenda`)

- Se **não** estiver com sessão de cliente: tela “Verifique seu cadastro” + CTA ir ao início
- **Agendados** (futuro) e **histórico**; cada card pode ter: status (progresso), reagendar, cancelar, avaliar  
- Estado vazio: ícone, “Nenhum agendamento”, botão agendar

### 7.6 Fidelidade (`/b/{slug}/fidelidade`)

- Cartão de **selos** (10), progresso, texto conforme `loyaltyCardStyle` (masculino: “Complete e ganhe” / feminino: variação de copy)
- **QR** do cupom quando atinge pontos necessários e regra de exibição
- CTA agendar

### 7.7 Perfil do cliente (`/b/{slug}/perfil`)

- Avatar letra, nome, WhatsApp, nasc., endereço, **pontos e selos**, total de agendamentos  
- Botão **“Agendar horário”**  
- Seção **“O que você já fez aqui”** (histórico de atendimentos)

---

## 8. Funcionário

### 8.1 Acesso (`/b/{slug}/funcionario`)

- Título explicando entrar com o **e-mail** cadastrado pelo dono  
- Botão **“Entrar com Google”**  
- Se e-mail **não** for staff: mensagem e diálogo “ir como cliente?”

**Shell:** AppBar (nome do negócio ou título) + **Sair**; **sem** bottom bar de cliente

### 8.2 Minha agenda (`/b/{slug}/funcionario/agenda`)

- Lista **Próximos** e **Realizados** (agendamentos daquele `staffId`, não cancelados)  
- Título: “Horários com você”, contagem

---

## 9. Entidades de dados (para componentes e listas no Figma)

- **BarberShop:** `name`, `slug`, `ownerUid`, cores, `logoUrl`, `backgroundImageUrl`, horários, `businessTypes[]`, `themeStyle`, `loyaltyCardStyle`, fidelidade (pontos p/ cupom, tipo desconto voucher), `singleAttendant`, `referralPoints`, `trialEndsAt`, `subscriptionStatus`, Stripe ids…
- **Service:** `name`, `price`, `durationMinutes`, `imageUrl?`, `description?`, `category?`, `productConsumptions[]`…
- **Client:** `name`, `whatsapp`, `dateOfBirth` (dd/MM/yyyy), `address?`, `email?`, `cpf?`, `authUid?`, `loyaltyPoints`, `totalAppointments`, indicação…
- **Appointment:** múltiplos serviços em estrutura de itens, `dateTime`, `status`, `staffId?`, preço total, etc.
- **Staff:** `name`, `email`, `serviceIds[]`
- **Expense (DRE):** mês, descrição, valor

---

## 10. Checklist de telas para o Figma (alto nível)

- [ ] Splash  
- [ ] Login dono (e-mail + Google + esqueci senha)  
- [ ] Register dono (e-mail + Google)  
- [ ] Dashboard × 6 abas + estados (sem negócio / com negócio / trial)  
- [ ] Settings negócio  
- [ ] Assinatura  
- [ ] Admin lista  
- [ ] Pública: Home agendamento (todos os passos + carrinho + cupom + confirmação)  
- [ ] Cliente: Cadastro, Login, Complete profile, Agenda, Fidelidade, Perfil (incl. vazio / bloqueado)  
- [ ] Staff: Acesso, Agenda

---

## 11. Notas finais

- Todos os textos acima refletem o **comportamento atual** do repositório; microcopy de SnackBars e mensagens de erro podem ser revistos no Figma, mas a **estrutura de fluxo** é esta.  
- Para **marca e cores por estabelecimento**, desenhe **um tema base** (componentes) + **variação** com amostra de `primary`/`secondary` (ex. roxo e azul) para a página pública.  
- **Indicação:** link público com `?ref=` → cadastro com campo “quem te indicou”.

---

*Arquivo gerado a partir de `lib/src/config/app_router.dart`, modelos em `lib/src/core/models/`, e telas em `lib/src/features/`.*
