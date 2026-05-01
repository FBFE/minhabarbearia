# Habilitar criação de conta no Firebase (Flow Studio 10)

Para o cadastro por **e-mail/senha** e **Google** funcionar:

## 1. Authentication → Sign-in method

1. Acesse o [Firebase Console](https://console.firebase.google.com) → projeto **Flow Studio 10**.
2. Vá em **Build** → **Authentication** → aba **Sign-in method**.
3. **E-mail/senha:** clique e ative **Ativar** (Enable) → Salvar.
4. **Google:** você já habilitou; mantenha ativo.

## 2. Domínios autorizados (se der erro de domínio)

1. Em **Authentication** → **Settings** (Configurações) → **Authorized domains**.
2. Confira se estão na lista:
   - `localhost` (para testar no seu PC)
   - `flow-studio-10.web.app`
   - `flow-studio-10.firebaseapp.com`
3. Se usar um domínio próprio (ex.: eugeniosoftware.com), adicione-o também.

Depois disso, os usuários podem:
- **Cadastrar** em “Cadastre-se” com nome, nascimento, contato, e-mail, CPF e senha.
- **Entrar com Google** na tela de login e, se for a primeira vez, completar o perfil (nome, nascimento, contato, CPF).
