# Todas as telas do sistema – Resumo para layout no Figma

Este documento lista **todas as telas** do app (dono do negócio, cliente e funcionário) com descrição objetiva do que cada uma faz, para montagem do layout no Figma.

---

## Índice por tipo de usuário

1. **Sistema / Auth (qualquer usuário)** – Splash, Login, Cadastro, Admin  
2. **Dono do negócio (Dashboard)** – Dashboard principal + Configurações + Assinatura  
3. **Cliente (página pública do estabelecimento)** – Início, Agenda, Fidelidade, Perfil, Cadastro, Login, Completar perfil  
4. **Funcionário** – Acesso (login) + Minha agenda  

---

## 1. Telas de sistema / autenticação

### 1.1 Splash (`/`)
- **O que faz:** Tela inicial do app. Exibe logo “Meu Negócio” e ícone de tesoura em fundo em gradiente (cor primária). Um loading roda por ~800 ms enquanto decide para onde enviar:
  - Se a URL tiver `?slug=xxx` → redireciona para a página pública do estabelecimento `/b/xxx`.
  - Se o usuário estiver logado (Firebase) → vai para `/dashboard`.
  - Caso contrário → vai para `/login`.
- **Elementos visuais:** Ícone grande, título “Meu Negócio”, indicador de carregamento circular.

### 1.2 Login do dono (`/login`)
- **O que faz:** Login para o **dono do negócio** (e-mail + senha). Usado para acessar o dashboard. Mensagens de erro do Firebase são traduzidas (usuário não encontrado, senha incorreta, etc.). Botão “Ainda não tem conta? Cadastre-se” leva para `/register`.
- **Elementos:** Logo “Meu Negócio”, subtítulo “Entre para gerenciar seu negócio”, card com campos E-mail e Senha, botão “Entrar”, link para cadastro.

### 1.3 Cadastro do dono (`/register`)
- **O que faz:** Criação de conta para o **dono do negócio** (e-mail, senha, confirmar senha). Após sucesso, redireciona para `/dashboard`. Validação de senha (mín. 6 caracteres, confirmação). Botão “Já tem conta? Entrar” leva para `/login`.
- **Elementos:** Ícone de pessoa, título “Criar conta”, subtítulo “Preencha os dados para se cadastrar”, campos E-mail, Senha, Confirmar senha, botão “Cadastrar”, link para login.

### 1.4 Painel Admin (`/admin`)
- **O que faz:** Painel **restrito a UIDs configurados como admin**. Lista todas as barbearias/salões que usam o sistema (nome, slug, data de cadastro, fim do trial, status da assinatura). Botão “Atualizar” recarrega a lista. Se o usuário não for admin, mostra “Acesso negado” ou “Você não tem acesso ao painel admin” com botão “Voltar ao dashboard”.
- **Elementos:** AppBar “Painel do app” (fundo escuro), botão voltar, ícone refresh, lista de cards por negócio (ícone loja, nome, slug, datas, status).

---

## 2. Telas do dono do negócio (Dashboard)

Todas sob `/dashboard` (e subrotas). O dashboard é uma **única página com abas** (BottomNavigationBar) + duas subpáginas em tela cheia (Configurações e Assinatura).

### 2.1 Dashboard principal (`/dashboard`)

Uma **tela com 6 abas** no rodapé. O AppBar mostra o título da aba atual e ações: Admin (se for admin), Configurações, Sair.

#### Aba **Início**
- **O que faz:** Boas-vindas (“Bem-vindo ao Dashboard”), e-mail logado, card com link do negócio para compartilhar. Se não houver negócio vinculado, mostra card para “Vincular ou criar negócio”. Se houver negócio, mostra banner de trial/assinatura (dias restantes, aviso de expiração, botão Assinar) e resumo do negócio.
- **Elementos:** Card de boas-vindas, banner condicional (trial/assinatura), card do negócio ou “Vincular negócio”.

#### Aba **Agenda**
- **O que faz:** Calendário (TableCalendar) e lista de agendamentos do dia. O dono vê todos os agendamentos do estabelecimento; pode filtrar por data, ver status (agendado, confirmado, realizado, cancelado) e gerenciar horários.
- **Elementos:** Calendário, lista de agendamentos com horário, cliente, serviço, funcionário, ações.

#### Aba **Serviços**
- **O que faz:** CRUD de serviços (nome, duração, preço, descrição). Lista de serviços em cards ou lista; botão adicionar; editar/remover.
- **Elementos:** Lista de serviços, FAB ou botão “Adicionar serviço”, formulário/modal para criar/editar.

#### Aba **Clientes**
- **O que faz:** Lista de clientes do estabelecimento (nome, WhatsApp, data de nascimento, etc.). Busca e visualização/edição de dados do cliente.
- **Elementos:** Lista/busca de clientes, cards ou linhas por cliente.

#### Aba **Estoque**
- **O que faz:** Gestão de estoque (produtos, entradas/saídas, movimentações). Aba separada (widget `DashboardEstoqueTab`).
- **Elementos:** Lista de produtos, movimentações, botões para entrada/saída.

#### Aba **Relatórios**
- **O que faz:** DRE e relatórios financeiros (aba `DashboardDreTab`).
- **Elementos:** Gráficos/tabelas de receita, despesas, resumo.

**Bottom nav (sempre visível no dashboard):** Início | Agenda | Serviços | Clientes | Estoque | Relatórios (ícones + labels).

### 2.2 Configurações do negócio (`/dashboard/settings`)
- **O que faz:** Formulário para editar dados do estabelecimento: nome, slug, cores (primária/secundária), logo, imagem de fundo. Salvamento no Firestore.
- **Elementos:** AppBar “Configurações”, botão voltar, formulário (nome, slug, pickers de cor, upload de logo e fundo).

### 2.3 Assinatura (`/dashboard/assinar`)
- **O que faz:** Página de assinatura mensal (Stripe). Texto explicando “Assinatura mensal” e “Cobrança automática no cartão todo mês”. Botão que chama a Cloud Function e redireciona para o checkout do Stripe. Aviso de que o pagamento é processado pelo Stripe.
- **Elementos:** AppBar “Assinatura”, título “Continuar usando o app”, card da opção “Assinatura mensal” com ícone e botão de ação, texto de rodapé sobre Stripe.

---

## 3. Telas do cliente (página pública do estabelecimento)

Todas sob `/b/:slug` (ex.: `/b/minhabarbearia`). O cliente acessa pelo link do estabelecimento. Há um **shell com bottom nav** em várias telas (Início, Agenda, Fidelidade, Perfil).

### 3.1 Página inicial / Agendamento (`/b/:slug`)
- **O que faz:** Página principal do estabelecimento para o cliente. Mostra nome do negócio, tipo (barbearia/salão), “Agende seu horário”, horário de funcionamento. **Fluxo de agendamento:**  
  1) Verificação por WhatsApp + data de nascimento (cliente já cadastrado) ou cadastro novo.  
  2) Escolha de serviço(s) – carrinho com múltiplos serviços.  
  3) Escolha de profissional (opcional).  
  4) Escolha de data e horário (slots disponíveis).  
  5) Código promocional (opcional).  
  6) Confirmação e criação do agendamento.  
- **Elementos:** AppBar com nome do negócio, corpo com formulário (verificação/cadastro, lista de serviços, seleção de staff, calendário, slots, cupom, botão confirmar). Sem bottom nav nesta tela (é a “Início” do fluxo).

### 3.2 Agenda do cliente (`/b/:slug/agenda`)
- **O que faz:** Lista de agendamentos do cliente (com login/cadastro verificado). Separa “Agendados” (futuros) e “Histórico”. Para cada agendamento: status (barra de progresso Agendado → Confirmado → Realizado), dados do serviço e horário, ações (reagendar, cancelar, avaliar). Se não houver agendamentos, CTA “Agendar”. Se o cliente não estiver verificado, mostra tela “Verifique seu cadastro” com botão “Ir para página inicial”.
- **Elementos:** AppBar (nome do negócio + “Acompanhe seus agendamentos”), lista de cards de agendamento, botão “Agendar” no estado vazio, ou tela de “Verifique seu cadastro”.

### 3.3 Fidelidade (`/b/:slug/fidelidade`)
- **O que faz:** Cartão de fidelidade: selos circulares (ex.: 10 selos), progresso, texto dinâmico (“Complete e ganhe” ou “Selos de fidelidade” conforme estilo do negócio). Quando atinge a meta de pontos, mostra QR code do cupom e possibilidade de resgate. Botão “Agendar”. Exige cliente verificado; senão mostra “Verifique seu cadastro” com link para a página inicial.
- **Elementos:** AppBar (nome + subtítulo de fidelidade), selos circulares, texto de progresso, QR do cupom (quando elegível), botão “Agendar”.

### 3.4 Perfil do cliente (`/b/:slug/perfil`)
- **O que faz:** Dados do cliente (avatar com inicial, nome, WhatsApp, data de nascimento, endereço, pontos, selos, total de agendamentos). Botão “Agendar horário”. Seção “O que você já fez aqui” (histórico de atendimentos). Exige cliente verificado.
- **Elementos:** AppBar com nome do negócio, card de perfil (avatar, nome, dados em linhas com ícones), botão “Agendar horário”, lista de histórico.

### 3.5 Cadastro do cliente (`/b/:slug/cadastro`)
- **O que faz:** Cadastro completo do cliente no estabelecimento: nome, data de nascimento, telefone/WhatsApp, e-mail, CPF (opcional), senha, “Quem te indicou?” (pré-preenchido se vier `?ref=` no link). Checkbox LGPD (obrigatório). Opção de estilo do cartão fidelidade (masculino/feminino). Após sucesso, redireciona para a página do estabelecimento ou perfil.
- **Elementos:** Formulário com todos os campos, checkbox LGPD, botão “Cadastrar”, link “Já tem conta? Entrar” para `/b/:slug/login`.

### 3.6 Login do cliente (`/b/:slug/login`)
- **O que faz:** Login do cliente por e-mail e senha **nesse estabelecimento**. Valida se o e-mail está cadastrado como cliente do slug; se não, mostra mensagem e opção de ir para cadastro. Após sucesso, pode mostrar diálogo “Salvar como app” (PWA) e redireciona para `/b/:slug/perfil`.
- **Elementos:** Campos E-mail e Senha, botão “Entrar”, link para cadastro.

### 3.7 Completar perfil (`/b/:slug/complete-profile`)
- **O que faz:** Usado após **login com Google** (cliente novo no estabelecimento). Preenche nome (pré-preenchido), data de nascimento, telefone, CPF (opcional), LGPD e estilo do cartão fidelidade. Cria/atualiza o documento do cliente no Firestore e associa ao auth UID. Não é uma tela de login; é só completar dados.
- **Elementos:** Formulário (nome, nascimento, telefone, CPF, checkbox LGPD, estilo do cartão), botão “Salvar” ou “Continuar”.

**Bottom nav (cliente)** – aparece em Início, Agenda, Fidelidade e Perfil: **Início** | **Agenda** | **Fidelidade** | **Perfil**.

---

## 4. Telas do funcionário

### 4.1 Acesso funcionário (`/b/:slug/funcionario`)
- **O que faz:** Login do **funcionário** com **Google**. Verifica se o e-mail está na lista de funcionários do estabelecimento. Se sim, salva o estado “staff” e redireciona para `/b/:slug/funcionario/agenda`. Se não, mostra mensagem e diálogo “Deseja ir para a página de agendamento como cliente?” (ir para `/b/:slug`).
- **Elementos:** AppBar com nome do negócio, card/botão “Entrar com Google”, estado de loading.

### 4.2 Minha agenda (`/b/:slug/funcionario/agenda`)
- **O que faz:** Lista de agendamentos **do funcionário** (horários marcados com ele). Separa “Próximos” e “Realizados”. Cada item mostra dados do agendamento (cliente, serviço, data/hora). Se não estiver logado como staff, mostra prompt para fazer login (link para `/b/:slug/funcionario`). Layout dentro do **StaffShellPage**: AppBar com nome do negócio e botão “Sair”.
- **Elementos:** AppBar “Minha agenda” (ou nome do negócio), título “Horários com você”, subtítulo com nome do funcionário e quantidade de agendados, listas “Próximos” e “Realizados”, ou estado vazio “Nenhum horário marcado com você”.

**Shell funcionário:** Sem bottom nav; apenas AppBar com título e botão Sair.

---

## 5. Resumo rápido para Figma (checklist de telas)

| # | Rota / contexto        | Nome sugerido no Figma     | Resumo em uma linha |
|---|------------------------|----------------------------|----------------------|
| 1 | `/`                    | Splash                     | Tela inicial com logo e redirecionamento. |
| 2 | `/login`               | Login dono                 | E-mail + senha para dashboard. |
| 3 | `/register`            | Cadastro dono              | Criar conta dono (e-mail, senha). |
| 4 | `/admin`               | Painel admin               | Lista de negócios (só admin). |
| 5 | `/dashboard`           | Dashboard (6 abas)         | Início, Agenda, Serviços, Clientes, Estoque, Relatórios. |
| 6 | `/dashboard/settings` | Configurações negócio      | Nome, slug, cores, logo, fundo. |
| 7 | `/dashboard/assinar`   | Assinatura                 | Assinatura mensal Stripe. |
| 8 | `/b/:slug`             | Cliente – Início/Agendar  | Agendamento (verificação, serviços, staff, data, slot). |
| 9 | `/b/:slug/agenda`      | Cliente – Agenda           | Meus agendamentos (agendados + histórico). |
| 10| `/b/:slug/fidelidade`  | Cliente – Fidelidade       | Cartão de selos e QR cupom. |
| 11| `/b/:slug/perfil`      | Cliente – Perfil           | Dados do cliente e histórico. |
| 12| `/b/:slug/cadastro`    | Cliente – Cadastro         | Formulário cadastro + LGPD. |
| 13| `/b/:slug/login`       | Cliente – Login            | E-mail + senha do cliente. |
| 14| `/b/:slug/complete-profile` | Cliente – Completar perfil | Completar dados após Google. |
| 15| `/b/:slug/funcionario` | Funcionário – Acesso       | Entrar com Google (staff). |
| 16| `/b/:slug/funcionario/agenda` | Funcionário – Minha agenda | Horários com o funcionário. |

**Componentes reutilizáveis sugeridos:**  
- Bottom nav do cliente (Início, Agenda, Fidelidade, Perfil).  
- AppBar genérica (com título e cores do negócio).  
- Card de agendamento (status, dados, ações).  
- Formulários de campo (e-mail, senha, telefone, data).

---

*Documento gerado a partir do código em `lib/src/config/app_router.dart` e das páginas em `lib/src/features/*/presentation/*_page.dart`.*
