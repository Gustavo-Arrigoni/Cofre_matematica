# O Cofre Desaparecido

Aplicação Next.js/React + TypeScript para o Projeto Integrador de Geometria Espacial. Inclui sete desafios, evidências, tentativas, progresso persistido e painel do professor.

## Abrir no VSCode (Windows / PowerShell)

1. Extraia o ZIP e abra a pasta `o-cofre-desaparecido-vscode` no VSCode.
2. Abra **Terminal > Novo Terminal** e execute:

```powershell
node -v
Copy-Item .env.example .env.local
npm ci
npm run dev
```

Use Node.js 22.13 ou superior. Acesse `http://localhost:3000`. Para parar o servidor, pressione `Ctrl+C`. Depois de alterar o código, salve o arquivo; o navegador atualiza automaticamente.

No macOS/Linux, substitua `Copy-Item .env.example .env.local` por `cp .env.example .env.local`.

## Personalizar o visual

Edite `app/heist-theme.css` para ajustar a paleta, a navegação superior, os cards, a hero e as animações. A imagem de fundo está em `public/vault-heist.webp`. O texto da hero fica em `components/investigation-app.tsx`. As alterações visuais não exigem mudanças no banco de dados.

## Modelos 3D

Os sete desafios do caso incluem modelos 3D interativos feitos com Three.js. Arraste o modelo para girar; use os botões para girar, ampliar, afastar ou restaurar a posição. Nos desafios de comparação, as abas alternam apenas a visualização e não enviam respostas. O código dos modelos fica em `components/geometry-scene.tsx` e seu estilo em `app/heist-theme.css`.

## Supabase

Leia [GUIA_SUPABASE.md](GUIA_SUPABASE.md) **antes de criar contas de alunos**. O arquivo `.env.example` aponta para o projeto Supabase já criado para esta aplicação. Se você preferir um projeto novo, troque as duas variáveis em `.env.local` e execute `supabase/schema.sql` **uma única vez em um banco vazio**. Não execute esse script de criação novamente no projeto que já está pronto, pois ele também insere as pistas iniciais.

A chave do arquivo `.env.example` é **publicável**. Não use a chave `secret` nem `service_role` no navegador. O `.env.local` está no `.gitignore`; ao publicar na Vercel, cadastre as duas variáveis de ambiente no painel da Vercel.

## Comandos

| Comando | Ação |
| --- | --- |
| `npm run dev` | Inicia o servidor local |
| `npm run build` | Compila para produção |
| `npm run start` | Executa a compilação pronta |
| `npm run typecheck` | Confere os tipos TypeScript |
| `npm run lint` | Verifica o código com ESLint |

## Pastas principais

- `app/`: rotas e CSS.
- `components/investigation-app.tsx`: telas e interações de aluno/professor.
- `components/ui/`: componentes de diálogo, botão e progresso.
- `lib/supabase.ts`: conexão com o Supabase.
- `supabase/schema.sql`: banco, RLS, funções de validação e sete desafios iniciais.

O gabarito fica no schema privado do banco. As funções SQL corrigem respostas e salvam tentativas; o código do navegador recebe apenas o resultado.
