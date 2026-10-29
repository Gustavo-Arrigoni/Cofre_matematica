# Configuração do Supabase — O Cofre Desaparecido

## 1. Escolha o projeto

O projeto já criado para esta aplicação chama-se **O Cofre Desaparecido** e tem o identificador `syiolmvnaxmgrplwbssg`. Abra [o painel do projeto](https://supabase.com/dashboard/project/syiolmvnaxmgrplwbssg). Se ele aparecer em sua conta, o banco, as funções e as políticas RLS **já estão instalados**; vá direto à etapa 2. Não execute `schema.sql` de novo nesse projeto.

Se quiser usar um projeto Supabase novo, crie-o em sua conta, abra **SQL Editor**, cole o conteúdo completo de `supabase/schema.sql` e execute **uma única vez em um projeto vazio**. O arquivo cria as tabelas, relações, políticas de acesso, validação no banco e as sete pistas. Depois, em **Project Settings > API Keys**, copie a URL do projeto e a **publishable key** para `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://SEU-PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_SUA_CHAVE
```

Nunca coloque `secret`/`service_role` nessas variáveis `NEXT_PUBLIC_` ou no código do navegador. Reinicie `npm run dev` após alterar `.env.local`.

## 2. Configure as URLs de autenticação

No painel do projeto, abra **Authentication > URL Configuration**:

- **Site URL:** use o endereço da versão que será a principal para a turma. Para o site já publicado: `https://o-cofre-desaparecido.arrigoni-senai.chatgpt.site`. Se publicar na Vercel, mude para o domínio definitivo da Vercel.
- **Redirect URLs:** adicione separadamente `http://localhost:3000/caso` e `http://localhost:3000/recuperar` para desenvolvimento local.
- Adicione também `https://o-cofre-desaparecido.arrigoni-senai.chatgpt.site/caso` e `https://o-cofre-desaparecido.arrigoni-senai.chatgpt.site/recuperar` para a versão publicada. Se usar a Vercel, acrescente os dois caminhos no seu domínio da Vercel.

O cadastro redireciona para `/caso`; a recuperação de senha redireciona para `/recuperar`. As URLs precisam estar na lista permitida. O site publicado neste momento tem acesso privado; para disponibilizá-lo à turma, publique a versão final em um endereço acessível aos alunos (por exemplo, sua Vercel) e atualize as URLs.

## 3. Configure o envio de e-mails antes de cadastrar a turma

Em **Authentication > SMTP Settings**, configure um serviço SMTP de sua escolha: endereço do servidor, porta, usuário, senha, remetente e nome do remetente. Deixe a **confirmação de e-mail** ativada em **Authentication > Providers > Email**.

O envio padrão do Supabase é limitado e pode recusar destinatários que não façam parte da equipe do projeto. Para vários alunos, configure SMTP próprio. Verifique também **Authentication > Rate Limits** e ajuste os limites do seu provedor conforme o tamanho da turma. As credenciais de SMTP ficam apenas no painel do Supabase, nunca em `.env.local` do front-end.

## 4. Crie e habilite o professor

Após configurar os e-mails, entre no site, clique em **Criar conta de aluno**, cadastre o e-mail que será do professor e confirme a mensagem recebida. A conta nasce como `ALUNO` por segurança. No **SQL Editor** do Supabase, execute o comando abaixo, trocando o e-mail pelo e-mail exato da conta:

```sql
update public.usuarios
set perfil = 'PROFESSOR'
where lower(email) = lower('professor@escola.com')
returning id, nome, email, perfil;
```

Confirme que o resultado mostra **uma linha** com `PROFESSOR`. Saia da conta no site e entre novamente. A rota `/professor` abrirá o painel. Não altere `user_metadata` para tentar dar permissão: o perfil autorizado fica na tabela `public.usuarios`.

## 5. Cadastre alunos e organize turmas

1. Cada aluno cria uma conta no site, confirma o e-mail e faz login.
2. O professor acessa **Turmas > Criar** e digita o nome da turma.
3. Em **Adicionar aluno**, escolhe a turma e informa o e-mail exato do aluno já cadastrado.
4. O professor pode acompanhar progresso, erros, acertos e tentativas dos alunos matriculados em suas turmas.

O progresso e as tentativas ficam salvos no PostgreSQL após logout. As tabelas de respostas corretas estão no schema `private`; políticas RLS restringem tentativas e progresso ao aluno ou ao professor de sua turma.

## 6. Confira o banco

No **SQL Editor**, execute:

```sql
select count(*) as desafios from public.desafios;
select count(*) as evidencias from public.evidencias;
```

Ambos devem mostrar **7**. Faça uma tentativa incorreta e outra correta no primeiro desafio, saia e entre novamente; o progresso e o histórico devem continuar. Depois teste o painel com a conta do professor.

## 7. Publicar a versão editada na Vercel

Importe a pasta/repositório como projeto **Next.js** na Vercel. Em **Environment Variables**, configure `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` com os mesmos valores de `.env.local`. Publique, copie o domínio final e inclua os caminhos `/caso` e `/recuperar` em **Authentication > URL Configuration** no Supabase. Defina esse domínio como **Site URL** se for a versão principal. Não envie `.env.local` ao Git.

Se um aluno não receber confirmação ou recuperação de senha, confira primeiro **Authentication > Logs**, a configuração SMTP e a lista de Redirect URLs.

## 8. Se o login falhar

- **"Não foi possível conectar" / "Failed to fetch":** confira se o projeto Supabase está **ativo** no painel. Projetos gratuitos podem ficar pausados. Confira também as duas variáveis `NEXT_PUBLIC_` em `.env.local`, reinicie `npm run dev` e teste sem bloqueadores de rede. A chave deve ser a **publishable key** do mesmo projeto da URL.
- **"Seu e-mail ainda não foi confirmado":** abra o link recebido ou clique em **Reenviar e-mail de confirmação** na tela de login. Confira a caixa de spam. Se o link abrir `localhost` ou outro domínio incorreto, ajuste **Authentication > URL Configuration** conforme a etapa 2 e solicite um novo e-mail.
- **"E-mail ou senha incorretos":** confirme a digitação; use **Esqueci minha senha** se necessário. A recuperação também depende das URLs e do envio de e-mails configurados nas etapas 2 e 3.
