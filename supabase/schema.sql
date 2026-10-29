-- O Cofre Desaparecido. Execute no SQL Editor de um projeto Supabase vazio.
create schema if not exists private;

create table if not exists public.usuarios (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null default 'Investigador',
  email text not null,
  perfil text not null default 'ALUNO' check (perfil in ('ALUNO','PROFESSOR')),
  created_at timestamptz not null default now()
);
create table if not exists public.turmas (
  id uuid primary key default gen_random_uuid(), nome text not null,
  professor_id uuid not null references public.usuarios(id), created_at timestamptz not null default now()
);
create table if not exists public.turma_alunos (
  id uuid primary key default gen_random_uuid(), turma_id uuid not null references public.turmas(id) on delete cascade,
  aluno_id uuid not null references public.usuarios(id) on delete cascade,
  unique(turma_id, aluno_id)
);
create table if not exists public.casos (
  id uuid primary key default gen_random_uuid(), titulo text not null,
  descricao text not null default '', narrativa text not null default '', ativo boolean not null default true
);
create table if not exists public.desafios (
  id uuid primary key default gen_random_uuid(), caso_id uuid not null references public.casos(id) on delete cascade,
  titulo text not null, descricao text not null default '', pergunta text not null,
  tipo text not null check (tipo in ('NUMERICA','MULTIPLA')),
  ordem integer not null check (ordem > 0), ativo boolean not null default true,
  unique(caso_id, ordem)
);
create table if not exists public.alternativas (
  id uuid primary key default gen_random_uuid(), desafio_id uuid not null references public.desafios(id) on delete cascade,
  texto text not null, ordem integer not null, unique(desafio_id, ordem)
);
create table if not exists private.gabaritos (
  desafio_id uuid primary key references public.desafios(id) on delete cascade,
  resposta text not null, tolerancia numeric not null default 0
);
create table if not exists public.evidencias (
  id uuid primary key default gen_random_uuid(), caso_id uuid not null references public.casos(id) on delete cascade,
  desafio_id uuid not null unique references public.desafios(id) on delete cascade,
  titulo text not null, descricao text not null, ordem integer not null
);
create table if not exists public.tentativas (
  id uuid primary key default gen_random_uuid(), aluno_id uuid not null references public.usuarios(id) on delete cascade,
  desafio_id uuid not null references public.desafios(id) on delete cascade,
  resposta text not null, correta boolean not null, created_at timestamptz not null default now()
);
create table if not exists public.progresso_casos (
  id uuid primary key default gen_random_uuid(), aluno_id uuid not null references public.usuarios(id) on delete cascade,
  caso_id uuid not null references public.casos(id) on delete cascade,
  desafio_atual integer not null default 1, percentual integer not null default 0,
  concluido boolean not null default false, updated_at timestamptz not null default now(),
  unique(aluno_id, caso_id)
);
create table if not exists private.solucoes (
  caso_id uuid primary key references public.casos(id) on delete cascade,
  veiculo text not null, suspeito text not null
);
create table if not exists public.conclusoes (
  id uuid primary key default gen_random_uuid(), aluno_id uuid not null references public.usuarios(id) on delete cascade,
  caso_id uuid not null references public.casos(id) on delete cascade,
  veiculo text not null, suspeito text not null, correta boolean not null,
  created_at timestamptz not null default now()
);

create or replace function private.is_professor() returns boolean
language sql security definer set search_path = '' stable as $$
  select exists(select 1 from public.usuarios where id = (select auth.uid()) and perfil = 'PROFESSOR')
$$;
create or replace function private.leciona(p_aluno uuid) returns boolean
language sql security definer set search_path = '' stable as $$
  select exists (select 1 from public.turmas t join public.turma_alunos a on a.turma_id=t.id
    where t.professor_id=(select auth.uid()) and a.aluno_id=p_aluno)
$$;
revoke all on function private.is_professor() from public;
revoke all on function private.leciona(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_professor() to authenticated;
grant execute on function private.leciona(uuid) to authenticated;

create or replace function private.new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.usuarios(id,nome,email,perfil)
  values(new.id,coalesce(nullif(new.raw_user_meta_data->>'nome',''),split_part(new.email,'@',1)),new.email,'ALUNO');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.new_user();

alter table public.usuarios enable row level security;
alter table public.turmas enable row level security;
alter table public.turma_alunos enable row level security;
alter table public.casos enable row level security;
alter table public.desafios enable row level security;
alter table public.alternativas enable row level security;
alter table public.evidencias enable row level security;
alter table public.tentativas enable row level security;
alter table public.progresso_casos enable row level security;
alter table public.conclusoes enable row level security;
alter table private.gabaritos enable row level security;
alter table private.solucoes enable row level security;

create policy usuarios_ler on public.usuarios for select to authenticated
using (id=(select auth.uid()) or private.leciona(id));
create policy turmas_professor on public.turmas for all to authenticated
using (professor_id=(select auth.uid()) and private.is_professor())
with check (professor_id=(select auth.uid()) and private.is_professor());
create policy alunos_turma_ler on public.turma_alunos for select to authenticated
using (aluno_id=(select auth.uid()) or exists(select 1 from public.turmas t where t.id=turma_id and t.professor_id=(select auth.uid())));
create policy alunos_turma_inserir on public.turma_alunos for insert to authenticated
with check (private.is_professor() and exists(select 1 from public.turmas t where t.id=turma_id and t.professor_id=(select auth.uid())));
create policy alunos_turma_excluir on public.turma_alunos for delete to authenticated
using (private.is_professor() and exists(select 1 from public.turmas t where t.id=turma_id and t.professor_id=(select auth.uid())));
create policy casos_ler on public.casos for select to authenticated using (ativo or private.is_professor());
create policy casos_professor on public.casos for all to authenticated using (private.is_professor()) with check (private.is_professor());
create policy desafios_ler on public.desafios for select to authenticated using ((ativo and exists(select 1 from public.casos c where c.id=caso_id and c.ativo)) or private.is_professor());
create policy desafios_professor on public.desafios for all to authenticated using (private.is_professor()) with check (private.is_professor());
create policy alternativas_ler on public.alternativas for select to authenticated using (exists(select 1 from public.desafios d where d.id=desafio_id and (d.ativo or private.is_professor())));
create policy alternativas_professor on public.alternativas for all to authenticated using (private.is_professor()) with check (private.is_professor());
create policy evidencias_ler on public.evidencias for select to authenticated using (
  private.is_professor() or exists(select 1 from public.tentativas t where t.desafio_id=desafio_id and t.aluno_id=(select auth.uid()) and t.correta)
);
create policy evidencias_professor on public.evidencias for all to authenticated using (private.is_professor()) with check (private.is_professor());
create policy tentativas_ler on public.tentativas for select to authenticated using (aluno_id=(select auth.uid()) or private.leciona(aluno_id));
create policy progresso_ler on public.progresso_casos for select to authenticated using (aluno_id=(select auth.uid()) or private.leciona(aluno_id));
create policy conclusoes_ler on public.conclusoes for select to authenticated using (aluno_id=(select auth.uid()) or private.leciona(aluno_id));

-- Exposição explícita: RLS continua sendo a camada de autorização por linha.
grant select on public.usuarios,public.casos,public.desafios,public.alternativas,public.evidencias,
  public.tentativas,public.progresso_casos,public.conclusoes to authenticated;
grant select,insert,update,delete on public.turmas,public.turma_alunos,public.desafios,
  public.alternativas,public.evidencias to authenticated;
revoke all on private.gabaritos,private.solucoes from anon,authenticated;

create or replace function public.responder_desafio(p_desafio uuid, p_resposta text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_d public.desafios%rowtype; v_g private.gabaritos%rowtype;
  v_proxima integer; v_acertou boolean; v_total integer; v_resolvidos integer; v_num numeric;
begin
  if v_uid is null then raise exception 'Faça login para responder.'; end if;
  select * into v_d from public.desafios where id=p_desafio and ativo;
  if not found then raise exception 'Desafio indisponível.'; end if;
  perform 1 from public.casos where id=v_d.caso_id and ativo;
  if not found then raise exception 'Caso indisponível.'; end if;
  select min(d.ordem) into v_proxima from public.desafios d where d.caso_id=v_d.caso_id and d.ativo
    and not exists(select 1 from public.tentativas t where t.desafio_id=d.id and t.aluno_id=v_uid and t.correta);
  if v_proxima is null or v_d.ordem <> v_proxima then raise exception 'Resolva os desafios na ordem indicada.'; end if;
  select * into v_g from private.gabaritos where desafio_id=p_desafio;
  if not found then raise exception 'Gabarito não configurado.'; end if;
  if v_d.tipo='NUMERICA' then
    begin v_num := replace(trim(p_resposta),',','.')::numeric;
    exception when others then v_num := null; end;
    v_acertou := v_num is not null and abs(v_num-v_g.resposta::numeric)<=v_g.tolerancia;
  else
    v_acertou := exists(select 1 from public.alternativas where desafio_id=p_desafio and id::text=p_resposta and id::text=v_g.resposta);
  end if;
  insert into public.tentativas(aluno_id,desafio_id,resposta,correta) values(v_uid,p_desafio,left(coalesce(p_resposta,''),200),v_acertou);
  select count(*) into v_total from public.desafios where caso_id=v_d.caso_id and ativo;
  select count(*) into v_resolvidos from public.desafios d where d.caso_id=v_d.caso_id and d.ativo
    and exists(select 1 from public.tentativas t where t.desafio_id=d.id and t.aluno_id=v_uid and t.correta);
  insert into public.progresso_casos(aluno_id,caso_id,desafio_atual,percentual,updated_at)
    values(v_uid,v_d.caso_id,coalesce(v_proxima,1)+(case when v_acertou then 1 else 0 end),round(v_resolvidos*100.0/greatest(v_total,1)),now())
    on conflict(aluno_id,caso_id) do update set desafio_atual=excluded.desafio_atual,percentual=excluded.percentual,updated_at=now();
  return jsonb_build_object('correta',v_acertou,'resolvidos',v_resolvidos,'total',v_total);
end $$;
revoke all on function public.responder_desafio(uuid,text) from public;
revoke all on function public.responder_desafio(uuid,text) from anon;
grant execute on function public.responder_desafio(uuid,text) to authenticated;

create or replace function public.finalizar_caso(p_caso uuid,p_veiculo text,p_suspeito text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_total integer; v_feitos integer; v_sol private.solucoes%rowtype; v_ok boolean;
begin
  if v_uid is null then raise exception 'Faça login para concluir.'; end if;
  select count(*) into v_total from public.desafios where caso_id=p_caso and ativo;
  select count(*) into v_feitos from public.desafios d where d.caso_id=p_caso and d.ativo
    and exists(select 1 from public.tentativas t where t.desafio_id=d.id and t.aluno_id=v_uid and t.correta);
  if v_total<5 or v_feitos<>v_total then raise exception 'Reúna todas as evidências antes de concluir.'; end if;
  select * into v_sol from private.solucoes where caso_id=p_caso;
  if not found then raise exception 'Solução não configurada.'; end if;
  v_ok := upper(trim(p_veiculo))=upper(v_sol.veiculo) and upper(trim(p_suspeito))=upper(v_sol.suspeito);
  insert into public.conclusoes(aluno_id,caso_id,veiculo,suspeito,correta) values(v_uid,p_caso,p_veiculo,p_suspeito,v_ok);
  if v_ok then update public.progresso_casos set concluido=true,percentual=100,updated_at=now() where aluno_id=v_uid and caso_id=p_caso; end if;
  return jsonb_build_object('correta',v_ok);
end $$;
revoke all on function public.finalizar_caso(uuid,text,text) from public;
revoke all on function public.finalizar_caso(uuid,text,text) from anon;
grant execute on function public.finalizar_caso(uuid,text,text) to authenticated;

create or replace function public.salvar_desafio(p_id uuid,p_caso uuid,p_titulo text,p_descricao text,p_pergunta text,
  p_tipo text,p_ordem integer,p_ativo boolean,p_resposta text,p_opcoes text[],p_evidencia_titulo text,p_evidencia_descricao text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_opcao text; v_i integer; v_resposta text;
begin
  if not private.is_professor() then raise exception 'Acesso restrito ao professor.'; end if;
  if p_tipo not in ('NUMERICA','MULTIPLA') or p_ordem<1 or p_titulo='' then raise exception 'Dados do desafio inválidos.'; end if;
  if p_id is null then
    insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem,ativo)
      values(p_caso,p_titulo,p_descricao,p_pergunta,p_tipo,p_ordem,p_ativo) returning id into v_id;
  else
    update public.desafios set titulo=p_titulo,descricao=p_descricao,pergunta=p_pergunta,tipo=p_tipo,ordem=p_ordem,ativo=p_ativo
      where id=p_id and caso_id=p_caso returning id into v_id;
    if v_id is null then raise exception 'Desafio não encontrado.'; end if;
  end if;
  if p_tipo='MULTIPLA' then
    if array_length(p_opcoes,1)<2 or p_resposta !~ '^[0-9]+$' or p_resposta::integer>array_length(p_opcoes,1) or p_resposta::integer<1 then
      raise exception 'Informe pelo menos duas alternativas e o número da correta.';
    end if;
    delete from public.alternativas where desafio_id=v_id;
    for v_i in 1..array_length(p_opcoes,1) loop
      insert into public.alternativas(desafio_id,texto,ordem) values(v_id,p_opcoes[v_i],v_i)
        returning id::text into v_opcao;
      if v_i=p_resposta::integer then v_resposta:=v_opcao; end if;
    end loop;
  else
    perform replace(p_resposta,',','.')::numeric;
    delete from public.alternativas where desafio_id=v_id;
    v_resposta:=replace(p_resposta,',','.');
  end if;
  insert into private.gabaritos(desafio_id,resposta) values(v_id,v_resposta)
    on conflict(desafio_id) do update set resposta=excluded.resposta;
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem)
    values(p_caso,v_id,p_evidencia_titulo,p_evidencia_descricao,p_ordem)
    on conflict(desafio_id) do update set titulo=excluded.titulo,descricao=excluded.descricao,ordem=excluded.ordem;
  return v_id;
end $$;
revoke all on function public.salvar_desafio(uuid,uuid,text,text,text,text,integer,boolean,text,text[],text,text) from public;
revoke all on function public.salvar_desafio(uuid,uuid,text,text,text,text,integer,boolean,text,text[],text,text) from anon;
grant execute on function public.salvar_desafio(uuid,uuid,text,text,text,text,integer,boolean,text,text[],text,text) to authenticated;

create or replace function public.buscar_aluno(p_email text) returns table(id uuid,nome text,email text)
language sql security definer set search_path = '' as $$
  select u.id,u.nome,u.email from public.usuarios u where private.is_professor() and u.perfil='ALUNO' and lower(u.email)=lower(trim(p_email)) limit 1
$$;
revoke all on function public.buscar_aluno(text) from public;
revoke all on function public.buscar_aluno(text) from anon;
grant execute on function public.buscar_aluno(text) to authenticated;

create or replace function public.trocar_ordem(p_a uuid,p_b uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_a public.desafios%rowtype; v_b public.desafios%rowtype; v_temp integer;
begin
  if not private.is_professor() then raise exception 'Acesso restrito ao professor.'; end if;
  select * into v_a from public.desafios where id=p_a for update;
  select * into v_b from public.desafios where id=p_b for update;
  if v_a.id is null or v_b.id is null or v_a.caso_id<>v_b.caso_id then raise exception 'Desafios incompatíveis.'; end if;
  select max(ordem)+1 into v_temp from public.desafios where caso_id=v_a.caso_id;
  update public.desafios set ordem=v_temp where id=p_a;
  update public.desafios set ordem=v_a.ordem where id=p_b;
  update public.desafios set ordem=v_b.ordem where id=p_a;
  update public.evidencias set ordem=v_b.ordem where desafio_id=p_a;
  update public.evidencias set ordem=v_a.ordem where desafio_id=p_b;
end $$;
revoke all on function public.trocar_ordem(uuid,uuid) from public,anon;
grant execute on function public.trocar_ordem(uuid,uuid) to authenticated;

do $$ declare v_caso uuid; v_d uuid; begin
  insert into public.casos(titulo,descricao,narrativa) values('Arquivo do Caso #22137',
    'Desaparecimento de cofre contendo documentos confidenciais.',
    'Às 22h37, o alarme silencioso registrou movimento no setor de arquivos. Na manhã seguinte, o cofre tinha desaparecido sem sinais de arrombamento.') returning id into v_caso;
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Dimensões do cofre',
    'A perícia mediu o espaço do cofre: 100 cm de comprimento, 80 cm de largura e 70 cm de altura.',
    'Qual o volume do cofre, em cm³? Use V = comprimento × largura × altura.','NUMERICA',1) returning id into v_d;
  insert into private.gabaritos values(v_d,'560000',0);
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Dimensões confirmadas','O cofre mede 100 × 80 × 70 cm e ocupa 560.000 cm³ (560 L).',1);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Veículos suspeitos',
    'Três compartimentos foram medidos. A: 95 × 75 × 60 cm. B: 140 × 110 × 100 cm. C: 120 × 90 × 60 cm. O cofre não foi desmontado.',
    'Qual veículo comporta o cofre considerando as três dimensões, e não apenas o volume?','MULTIPLA',2) returning id into v_d;
  insert into public.alternativas(desafio_id,texto,ordem) values(v_d,'Veículo A',1),(v_d,'Veículo B',2),(v_d,'Veículo C',3);
  insert into private.gabaritos select v_d,id::text,0 from public.alternativas where desafio_id=v_d and ordem=2;
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Comparação dimensional','A tem comprimento insuficiente; C tem altura insuficiente. Apenas B comporta o cofre sem desmontagem.',2);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Caixas encontradas',
    'Uma caixa de proteção encontrada junto à rampa mede 60 × 40 × 30 cm.',
    'Qual o volume de uma caixa, em cm³?','NUMERICA',3) returning id into v_d;
  insert into private.gabaritos values(v_d,'72000',0);
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Embalagem de proteção','Cada caixa ocupa 72.000 cm³ (72 L). Duas caixas do mesmo tipo constam no registro de saída.',3);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Marcas no chão',
    'A marca retangular na rampa mede 100 × 80 cm. A base do cofre mede 100 × 80 cm. Compare as dimensões e as áreas das bases.',
    'As marcas poderiam ter sido produzidas pela base do cofre?','MULTIPLA',4) returning id into v_d;
  insert into public.alternativas(desafio_id,texto,ordem) values(v_d,'Sim. As bases medem 100 × 80 cm e têm área de 8.000 cm².',1),
    (v_d,'Não. O volume e a área da base são a mesma medida.',2);
  insert into private.gabaritos select v_d,id::text,0 from public.alternativas where desafio_id=v_d and ordem=1;
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Trajeto confirmado','As marcas de 8.000 cm² coincidem com a base do cofre e seguem até a vaga de carga.',4);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Lacre cúbico',
    'A perícia encontrou um lacre cúbico de proteção, com arestas de 20 cm, na vaga de carga.',
    'Qual o volume desse cubo em cm³? Use V = aresta³.','NUMERICA',5) returning id into v_d;
  insert into private.gabaritos values(v_d,'8000',0);
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Lacre cúbico','O lacre de 20 cm de aresta ocupa 8.000 cm³ e foi encontrado na vaga do veículo B.',5);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Suporte prismático',
    'Um suporte de carga tem formato de prisma triangular reto. A base é um triângulo retângulo de catetos 30 cm e 40 cm; o prisma tem 60 cm de comprimento.',
    'Qual o volume do suporte em cm³? Calcule a área triangular (30 × 40 ÷ 2) e multiplique por 60.','NUMERICA',6) returning id into v_d;
  insert into private.gabaritos values(v_d,'36000',0);
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Suporte prismático','O suporte triangular ocupa 36.000 cm³. Ele estabilizava a carga no veículo B.',6);
  insert into public.desafios(caso_id,titulo,descricao,pergunta,tipo,ordem) values(v_caso,'Capacidade final',
    'O compartimento B mede 140 × 110 × 100 cm. A carga incluía o cofre (560.000 cm³), duas caixas (72.000 cm³ cada), um lacre cúbico (8.000 cm³) e um suporte triangular (36.000 cm³). A perícia verificou fisicamente a disposição.',
    'Subtraia os volumes de toda a carga do volume interno de B. Quanto resta, em cm³?','NUMERICA',7) returning id into v_d;
  insert into private.gabaritos values(v_d,'792000',0);
  insert into public.evidencias(caso_id,desafio_id,titulo,descricao,ordem) values(v_caso,v_d,'Registro de movimentação','O veículo B foi liberado às 22h41. A credencial de saída pertence a Marina Costa, responsável pela logística; o volume livre calculado é 792.000 cm³. A soma de volumes confirma a capacidade, e a perícia verificou o arranjo físico.',7);
  insert into private.solucoes values(v_caso,'B','Marina Costa');
end $$;
