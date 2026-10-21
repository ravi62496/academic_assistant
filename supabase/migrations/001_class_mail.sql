-- ============================================================
-- SENTRY: Class Email Intelligence Schema
-- Migration: 001_class_mail.sql
-- ============================================================

-- 1. User Mail Settings
create table if not exists public.mail_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  mode text not null default 'selected' check (mode in ('selected', 'all')),
  sync_enabled boolean not null default true,
  gmail_history_id text,
  last_synced_at timestamptz,
  quiet_start time,
  quiet_end time,
  daily_digest boolean default false,
  created_at timestamptz default now()
);

-- 2. Allowed Email Senders (address or domain)
create table if not exists public.email_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('address', 'domain')),
  value text not null,
  label text,
  enabled boolean not null default true,
  created_at timestamptz default now(),
  unique (user_id, value)
);

-- 3. Extracted Class Updates (Tasks + Notices live here)
create table if not exists public.class_updates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  gmail_message_id text not null,
  thread_id text,
  type text not null check (type in
    ('quiz', 'exam', 'assignment', 'cancelled', 'postponed', 'rescheduled', 'room_change', 'info')),
  title text not null,
  course text,
  starts_at timestamptz,
  new_starts_at timestamptz,
  room text,
  sender text,
  confidence real not null default 0.5,
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'dismissed', 'done')),
  is_read boolean not null default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, gmail_message_id)
);

create index if not exists idx_class_updates_user_type_starts on public.class_updates (user_id, type, starts_at);
create index if not exists idx_class_updates_user_thread on public.class_updates (user_id, thread_id);

-- 4. Device Tokens for Push Notifications
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  platform text default 'android',
  updated_at timestamptz default now(),
  unique (user_id, fcm_token)
);

-- 5. Server-Side Gmail Credentials (Service Role Access Only)
create table if not exists public.gmail_credentials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  google_email text,
  updated_at timestamptz default now()
);

-- 6. Row Level Security (RLS)
alter table public.mail_settings enable row level security;
alter table public.email_sources enable row level security;
alter table public.class_updates enable row level security;
alter table public.device_tokens enable row level security;
alter table public.gmail_credentials enable row level security;

-- Client Policies: Users can only see/modify their own data
drop policy if exists "own settings" on public.mail_settings;
create policy "own settings" on public.mail_settings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own sources" on public.email_sources;
create policy "own sources" on public.email_sources
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own updates" on public.class_updates;
create policy "own updates" on public.class_updates
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own tokens" on public.device_tokens;
create policy "own tokens" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Note: gmail_credentials has NO client policy, meaning only service_role (Edge Functions) can access it.

