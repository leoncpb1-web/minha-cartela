-- Minha Cartela v0.9.1 — mesma estrutura Supabase da v0.9
-- Minha Cartela v0.9 — estrutura de teste segura para Supabase
-- Execute este arquivo UMA VEZ no SQL Editor do Supabase.
-- O conteúdo clínico (nome do medicamento, dose, histórico) será enviado pelo app
-- criptografado no navegador com AES-GCM. A chave de criptografia NÃO fica no Supabase.

begin;

create table if not exists public.med_pairs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  invite_code text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.med_pair_members (
  pair_id uuid not null references public.med_pairs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('patient','caregiver')),
  created_at timestamptz not null default now(),
  primary key (pair_id, user_id)
);

create table if not exists public.med_cartela_state (
  pair_id uuid primary key references public.med_pairs(id) on delete cascade,
  ciphertext text not null,
  iv text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users(id)
);

alter table public.med_pairs enable row level security;
alter table public.med_pair_members enable row level security;
alter table public.med_cartela_state enable row level security;

-- Funções auxiliares de autorização. SECURITY DEFINER permite avaliar associação
-- ao par sem criar recursão de RLS.
create or replace function public.is_med_pair_member(p_pair_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.med_pair_members m
    where m.pair_id = p_pair_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_med_pair_patient(p_pair_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.med_pair_members m
    where m.pair_id = p_pair_id
      and m.user_id = auth.uid()
      and m.role = 'patient'
  );
$$;

-- Cria vínculo do paciente e produz um convite de uso único.
create or replace function public.create_med_pair()
returns table(pair_id uuid, invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pair_id uuid;
  v_code text;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));

  insert into public.med_pairs(owner_id, invite_code)
  values (v_uid, v_code)
  returning id into v_pair_id;

  insert into public.med_pair_members(pair_id, user_id, role)
  values (v_pair_id, v_uid, 'patient');

  return query select v_pair_id, v_code;
end;
$$;

-- Cuidador entra usando o convite. O código é invalidado imediatamente após o uso.
create or replace function public.join_med_pair(p_invite_code text)
returns table(pair_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_pair_id uuid;
  v_owner uuid;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  select p.id, p.owner_id
    into v_pair_id, v_owner
  from public.med_pairs p
  where p.invite_code = upper(btrim(p_invite_code))
  for update;

  if v_pair_id is null then
    raise exception 'invalid or expired invite';
  end if;

  if v_owner = v_uid then
    raise exception 'owner cannot join as caregiver';
  end if;

  insert into public.med_pair_members(pair_id, user_id, role)
  values (v_pair_id, v_uid, 'caregiver')
  on conflict (pair_id, user_id) do update set role = 'caregiver';

  update public.med_pairs
  set invite_code = null
  where id = v_pair_id;

  return query select v_pair_id;
end;
$$;

-- O paciente pode gerar um novo convite quando quiser adicionar/reconectar cuidador.
create or replace function public.new_med_pair_invite(p_pair_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
begin
  if v_uid is null then
    raise exception 'authentication required';
  end if;

  if not exists (
    select 1 from public.med_pairs p
    where p.id = p_pair_id and p.owner_id = v_uid
  ) then
    raise exception 'not authorized';
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));
  update public.med_pairs set invite_code = v_code where id = p_pair_id;
  return v_code;
end;
$$;

-- O cliente só precisa enxergar a própria associação.
drop policy if exists med_members_self_select on public.med_pair_members;
create policy med_members_self_select
on public.med_pair_members
for select
to authenticated
using (user_id = auth.uid());

-- Apenas membros podem ler o estado criptografado.
drop policy if exists med_state_member_select on public.med_cartela_state;
create policy med_state_member_select
on public.med_cartela_state
for select
to authenticated
using (public.is_med_pair_member(pair_id));

-- Apenas o paciente pode criar/alterar o estado do seu vínculo.
drop policy if exists med_state_patient_insert on public.med_cartela_state;
create policy med_state_patient_insert
on public.med_cartela_state
for insert
to authenticated
with check (
  public.is_med_pair_patient(pair_id)
  and updated_by = auth.uid()
);

drop policy if exists med_state_patient_update on public.med_cartela_state;
create policy med_state_patient_update
on public.med_cartela_state
for update
to authenticated
using (public.is_med_pair_patient(pair_id))
with check (
  public.is_med_pair_patient(pair_id)
  and updated_by = auth.uid()
);

-- Reduz privilégios diretos. A criação/entrada de vínculos ocorre apenas pelas RPCs acima.
revoke all on public.med_pairs from anon, authenticated;
revoke all on public.med_pair_members from anon, authenticated;
revoke all on public.med_cartela_state from anon, authenticated;

grant select on public.med_pair_members to authenticated;
grant select, insert, update on public.med_cartela_state to authenticated;

revoke execute on function public.is_med_pair_member(uuid) from public;
revoke execute on function public.is_med_pair_patient(uuid) from public;
revoke execute on function public.create_med_pair() from public;
revoke execute on function public.join_med_pair(text) from public;
revoke execute on function public.new_med_pair_invite(uuid) from public;

grant execute on function public.is_med_pair_member(uuid) to authenticated;
grant execute on function public.is_med_pair_patient(uuid) to authenticated;
grant execute on function public.create_med_pair() to authenticated;
grant execute on function public.join_med_pair(text) to authenticated;
grant execute on function public.new_med_pair_invite(uuid) to authenticated;

alter table public.med_cartela_state replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'med_cartela_state'
  ) then
    alter publication supabase_realtime add table public.med_cartela_state;
  end if;
end $$;

commit;
