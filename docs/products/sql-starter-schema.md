# SQL Starter Schema (PostgreSQL)

## 1. Notes
- Schema is designed for one shared platform database with `project_id` scoping.
- Use migrations (Prisma/Knex/Flyway/Alembic) instead of direct manual DDL in production.
- Add partitioning later for very large `audit_events` and run logs.

## 2. Platform Core
```sql
create extension if not exists pgcrypto;

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  owner_team text,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  display_name text,
  auth_subject text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table if not exists user_project_roles (
  user_id uuid not null references users(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  role_id uuid not null references roles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, project_id, role_id)
);

create table if not exists job_runs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id),
  job_name text not null,
  trigger_type text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  status text not null,
  duration_ms bigint,
  error_summary text,
  created_at timestamptz not null default now()
);
create index if not exists idx_job_runs_project_started on job_runs(project_id, started_at desc);

create table if not exists job_run_metrics (
  id bigserial primary key,
  run_id uuid not null references job_runs(id) on delete cascade,
  metric_key text not null,
  metric_value_num numeric,
  metric_value_text text,
  created_at timestamptz not null default now()
);
create index if not exists idx_job_run_metrics_run on job_run_metrics(run_id);

create table if not exists audit_events (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  actor_type text not null,
  actor_id text,
  action text not null,
  resource_type text not null,
  resource_id text,
  before_json jsonb,
  after_json jsonb,
  metadata_json jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_project_created on audit_events(project_id, created_at desc);
create index if not exists idx_audit_resource on audit_events(resource_type, resource_id, created_at desc);
```

## 3. YouTube Liked Videos Domain
```sql
create table if not exists youtube_videos (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  video_id text not null,
  title text not null,
  channel_title text,
  url text not null,
  duration_seconds integer,
  thumbnail_url text,
  published_at timestamptz,
  liked_at timestamptz,
  transcript text,
  transcript_status text not null default 'none',
  transcript_last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, video_id)
);
create index if not exists idx_youtube_project_liked_at on youtube_videos(project_id, liked_at desc);
create index if not exists idx_youtube_project_transcript_status on youtube_videos(project_id, transcript_status);

create table if not exists youtube_sync_errors (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  run_id uuid references job_runs(id) on delete set null,
  video_id text,
  error_type text not null,
  error_message text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_youtube_errors_project_created on youtube_sync_errors(project_id, created_at desc);
```

## 4. London Lloyds News Digest Domain
```sql
create table if not exists news_sources (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  name text not null,
  source_type text not null,
  base_url text not null,
  enabled boolean not null default true,
  fetch_interval_min integer not null default 60,
  created_at timestamptz not null default now(),
  unique(project_id, name)
);

create table if not exists news_articles (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  source_id bigint not null references news_sources(id),
  canonical_url text not null,
  title text not null,
  published_at timestamptz,
  fetched_at timestamptz not null,
  raw_text text,
  language text,
  article_hash text,
  created_at timestamptz not null default now(),
  unique(project_id, canonical_url)
);
create index if not exists idx_news_articles_project_published on news_articles(project_id, published_at desc);

create table if not exists news_enrichment (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  article_id bigint not null references news_articles(id) on delete cascade,
  relevance_score numeric(5,4),
  relevance_reason text,
  summary_short text,
  summary_long text,
  sentiment text,
  entities_json jsonb,
  model_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, article_id)
);

create table if not exists news_digest_runs (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  run_id uuid references job_runs(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  status text not null,
  item_count integer not null default 0,
  error_summary text,
  created_at timestamptz not null default now()
);

create table if not exists news_digest_items (
  id bigserial primary key,
  project_id uuid not null references projects(id),
  digest_run_id bigint not null references news_digest_runs(id) on delete cascade,
  article_id bigint not null references news_articles(id) on delete cascade,
  section text not null,
  rank integer,
  created_at timestamptz not null default now(),
  unique(project_id, digest_run_id, article_id)
);
```
