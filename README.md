# Minha Cartela v0.9.1 — GitHub Pages + Supabase + voz personalizada

Esta versão foi preparada para teste em dois celulares e acrescenta gravação da própria voz no cadastro do medicamento.

## O que ela faz

- cartela diária por manhã / vespertino / noturno;
- medicamento fica verde após `Tomei`;
- proteção contra confirmação duplicada;
- alarme repetitivo com `Tomei` e `Adiar`;
- três tipos de aviso por medicamento:
  - **Voz automática**: fala dose + medicamento;
  - **Modo privado**: fala apenas `Hora do medicamento`;
  - **Minha voz gravada**: reproduz a gravação feita no cadastro;
- conta separada para paciente e cuidador;
- sincronização em tempo real pelo Supabase;
- conteúdo da cartela criptografado no navegador com AES-GCM antes de ser enviado ao Supabase;
- convite de cuidador de uso único.

## Como funciona a gravação personalizada

1. No cadastro, escolha **Minha voz gravada — reproduz uma gravação**.
2. Toque em **Iniciar gravação**.
3. Autorize o microfone quando o navegador pedir.
4. Fale a mensagem, por exemplo: `Mãe, está na hora de tomar um comprimido de Olmesartana.`
5. Toque em **Parar**.
6. Use **Ouvir** para conferir.
7. Cadastre o medicamento.

A gravação é salva no **IndexedDB do navegador do próprio aparelho**. Ela não é enviada ao Supabase nesta versão. Ao excluir o medicamento, a gravação local correspondente também é apagada.

### Consequência importante

O cuidador recebe e visualiza o estado da cartela em tempo real, mas não recebe o arquivo da voz gravada. Para o alarme com voz personalizada tocar no celular do paciente, a gravação precisa ter sido feita ou estar salva nesse aparelho.

## Limitação importante do HTML

O alarme falado funciona para teste enquanto a página está aberta. Navegadores de celular podem suspender JavaScript e áudio quando a tela é bloqueada ou quando a página fica em segundo plano. A futura versão nativa Android/iPhone deverá implementar o alarme com APIs nativas.

A gravação por microfone requer um contexto seguro. O GitHub Pages usa HTTPS, portanto é apropriado para o teste. Abra a página no Chrome, Samsung Internet ou Safari atualizado e autorize o microfone somente quando for gravar.

## 1 — Criar o repositório no GitHub

1. Entre em `github.com`.
2. Clique em **New repository**.
3. Sugestão de nome: `minha-cartela`.
4. Para usar GitHub Pages gratuitamente, deixe o repositório **Public**.
5. Crie o repositório.
6. Faça upload destes arquivos na raiz:
   - `index.html`
   - `supabase-setup.sql`
   - `README.md`
7. Faça o commit.

## 2 — Ativar o GitHub Pages

1. No repositório, abra **Settings**.
2. Na lateral, abra **Pages**.
3. Em **Build and deployment**, escolha **Deploy from a branch**.
4. Branch: `main`.
5. Pasta: `/ (root)`.
6. Clique em **Save**.
7. Aguarde o endereço `https://SEU-USUARIO.github.io/minha-cartela/` aparecer.
8. Mantenha **Enforce HTTPS** ativado, se a opção aparecer.

## 3 — Preparar o Supabase

1. Crie o projeto no Supabase.
2. Abra **SQL Editor**.
3. Copie todo o conteúdo de `supabase-setup.sql`.
4. Cole no SQL Editor e execute uma vez.
5. Nas configurações/API do projeto, copie:
   - **Project URL**;
   - **Publishable key** ou chave `anon` legada.
6. **Nunca** coloque a `service_role` no HTML ou GitHub.

## 4 — Contas do paciente e cuidador

Para o teste, cada celular usa uma conta diferente:

- celular do paciente: conta do paciente;
- celular do cuidador: conta do cuidador.

Depois de publicar no GitHub Pages, é recomendável configurar no Supabase Auth a **Site URL** com o endereço do GitHub Pages.

## 5 — Configurar o paciente

1. Abra o GitHub Pages no navegador.
2. Vá em **Conta e sincronização**.
3. Informe Project URL e Publishable/anon key.
4. Crie a conta ou entre.
5. Toque em **Sou paciente: criar vínculo**.
6. Envie o convite completo ao cuidador por um canal de confiança.
7. Cadastre os medicamentos e escolha o tipo de voz de cada um.
8. Quando marcar `Tomei`, a cartela é sincronizada automaticamente.

## 6 — Configurar o cuidador

1. Abra o mesmo GitHub Pages no segundo celular.
2. Informe a mesma Project URL e Publishable/anon key.
3. Entre na conta do cuidador.
4. Cole o convite em **Sou cuidador: convite recebido**.
5. Toque em **Aceitar convite**.
6. Selecione o vínculo.
7. Abra a aba **Cuidador**.

## 7 — Testar o alarme

1. Vá em **Alarme falado**.
2. Toque em **Ativar voz neste aparelho**.
3. Escolha um medicamento.
4. Toque em **Testar agora**.
5. Teste `TOMEI` e `ADIAR`.
6. Depois use **Ativar horários**.

Se o medicamento estiver em modo **Minha voz gravada**, o app reproduz o áudio salvo localmente. Se a gravação tiver sido apagada do navegador, o app usa um aviso privado como alternativa.

## Privacidade

O GitHub hospeda somente os arquivos públicos do aplicativo. Não coloque informações pessoais, medicamentos, senhas ou chaves secretas diretamente nos arquivos do repositório.

A cartela sincronizada é criptografada no navegador antes de ir ao Supabase. A gravação de voz personalizada não é sincronizada nesta versão e permanece no armazenamento local do navegador.

Esta é uma versão de protótipo/teste, não uma solução clínica certificada.
