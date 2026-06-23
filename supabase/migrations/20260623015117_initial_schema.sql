-- Catalyst Dashboard — initial schema
--
-- Tables for data synced from external services plus a cron run log:
--   • klaviyo_stats    — membership / email-marketing stats from Klaviyo
--   • outseta_stats    — billing / subscriber counts from Outseta
--   • automation_logs  — one row per cron job run (Vercel cron)
--
-- Apply with:  supabase db push   (or paste into the Supabase SQL Editor)
--
-- Security model: RLS is ENABLED with NO public policies. The browser anon key
-- (NEXT_PUBLIC_SUPABASE_ANON_KEY) therefore cannot read or write these tables.
-- Cron sync jobs write using the service-role key (which bypasses RLS), and the
-- dashboard should read server-side with the service-role key as well. Add
-- authenticated/role-scoped policies later if you expose reads to the browser.

-- Extensions ----------------------------------------------------------------
create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- Enums ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'automation_status') then
    create type automation_status as enum ('running', 'success', 'error', 'skipped');
  end if;
end
$$;

-- klaviyo_stats -------------------------------------------------------------
-- Periodic (typically daily) snapshot of a Klaviyo list/segment: membership
-- counts and email-engagement metrics. One row per list per snapshot date so
-- syncs can upsert idempotently on (snapshot_date, list_id).
create table if not exists public.klaviyo_stats (
  id               uuid primary key default gen_random_uuid(),
  snapshot_date    date        not null,
  list_id          text        not null default 'all',  -- Klaviyo list/segment id; 'all' for account-wide
  list_name        text,

  -- Membership
  total_members      integer,
  subscribed_members integer,
  new_subscribers    integer,
  unsubscribes       integer,

  -- Email engagement (period totals)
  emails_sent      integer,
  unique_opens     integer,
  unique_clicks    integer,
  bounces          integer,
  spam_complaints  integer,
  open_rate        numeric(6, 4),  -- 0.0000–1.0000
  click_rate       numeric(6, 4),

  -- Attributed revenue (Klaviyo)
  attributed_revenue numeric(14, 2),

  raw              jsonb,          -- full source payload for reference / reprocessing
  synced_at        timestamptz not null default now(),
  created_at       timestamptz not null default now(),

  constraint klaviyo_stats_unique_snapshot unique (snapshot_date, list_id)
);

create index if not exists klaviyo_stats_snapshot_date_idx
  on public.klaviyo_stats (snapshot_date desc);

-- outseta_stats -------------------------------------------------------------
-- Periodic snapshot of Outseta billing / subscriber counts. One row per plan
-- per snapshot date ('all' for an account-wide rollup) for idempotent upserts.
create table if not exists public.outseta_stats (
  id               uuid primary key default gen_random_uuid(),
  snapshot_date    date        not null,
  plan_id          text        not null default 'all',  -- Outseta plan uid; 'all' for account-wide rollup
  plan_name        text,

  -- Subscriber counts
  active_subscribers    integer,
  trialing_subscribers  integer,
  past_due_subscribers  integer,
  cancelled_subscribers integer,
  new_subscribers       integer,
  churned_subscribers   integer,

  -- Billing
  mrr              numeric(14, 2),  -- monthly recurring revenue
  arr              numeric(14, 2),  -- annual recurring revenue
  revenue          numeric(14, 2),  -- revenue booked in the period
  currency         text        not null default 'USD',

  raw              jsonb,
  synced_at        timestamptz not null default now(),
  created_at       timestamptz not null default now(),

  constraint outseta_stats_unique_snapshot unique (snapshot_date, plan_id)
);

create index if not exists outseta_stats_snapshot_date_idx
  on public.outseta_stats (snapshot_date desc);

-- automation_logs -----------------------------------------------------------
-- One row per cron job run. Insert a 'running' row at the start of a job, then
-- update it to 'success' / 'error' with finished_at and counts at the end.
create table if not exists public.automation_logs (
  id                uuid primary key default gen_random_uuid(),
  job_name          text not null,                       -- e.g. 'sync-klaviyo', 'sync-outseta'
  status            automation_status not null default 'running',
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  duration_ms       integer generated always as (
                      case
                        when finished_at is null then null
                        else (extract(epoch from (finished_at - started_at)) * 1000)::integer
                      end
                    ) stored,
  records_processed integer not null default 0,
  error_message     text,
  details           jsonb,                               -- arbitrary run metadata
  created_at        timestamptz not null default now()
);

create index if not exists automation_logs_job_name_started_idx
  on public.automation_logs (job_name, started_at desc);

create index if not exists automation_logs_status_idx
  on public.automation_logs (status);

-- Row Level Security --------------------------------------------------------
-- Enable RLS and intentionally add NO policies: the anon role gets no access.
-- The service-role key bypasses RLS, so cron syncs and server-side reads work.
alter table public.klaviyo_stats   enable row level security;
alter table public.outseta_stats   enable row level security;
alter table public.automation_logs enable row level security;
