-- 洗腎室交班系統 schema
-- 這是共用資料，同單位所有登入護理師都能讀寫同一份病人/排班/交班事項，
-- 跟「個人工時核對系統」那種每人資料互相隔離的設計不同。
-- 建議在獨立的 Supabase project 執行本檔，不要跟其他系統共用同一個 project。

create extension if not exists pgcrypto;

-- 護理師顯示名稱（登入用 email/password，這裡存好記的中文姓名）
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.dialysis_patients (
  pid text primary key,
  name text not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.dialysis_schedule (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  shift text not null,
  pid text not null references public.dialysis_patients(pid) on delete cascade,
  bed text,
  nurse text,
  unique (date, shift, pid)
);

create table if not exists public.dialysis_sessions (
  id uuid primary key default gen_random_uuid(),
  pid text not null references public.dialysis_patients(pid) on delete cascade,
  date date not null,
  shift text not null,
  bed text,
  nurse text,
  unique (pid, date, shift)
);

create table if not exists public.dialysis_tasks (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.dialysis_sessions(id) on delete cascade,
  text text not null,
  tag text,
  priority text,
  note text,
  done boolean not null default false,
  by text,
  time text,
  done_by text,
  done_time text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dialysis_sessions_pid on public.dialysis_sessions(pid);
create index if not exists idx_dialysis_tasks_session on public.dialysis_tasks(session_id);
create index if not exists idx_dialysis_schedule_date_shift on public.dialysis_schedule(date, shift);

-- RLS：全部僅限已登入使用者（同單位帳號）存取，資料在整個團隊間共用。
alter table public.profiles enable row level security;
alter table public.dialysis_patients enable row level security;
alter table public.dialysis_schedule enable row level security;
alter table public.dialysis_sessions enable row level security;
alter table public.dialysis_tasks enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "authenticated full access" on public.dialysis_patients;
create policy "authenticated full access" on public.dialysis_patients
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on public.dialysis_schedule;
create policy "authenticated full access" on public.dialysis_schedule
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on public.dialysis_sessions;
create policy "authenticated full access" on public.dialysis_sessions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on public.dialysis_tasks;
create policy "authenticated full access" on public.dialysis_tasks
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- 讓多裝置即時同步（護理站多台電腦同時看板）
alter publication supabase_realtime add table
  public.dialysis_patients,
  public.dialysis_schedule,
  public.dialysis_sessions,
  public.dialysis_tasks;
