# PRD: YouTube Liked Videos

## 1. Product Summary
Build an automated data product that continuously ingests liked videos, enriches metadata (including transcript where possible), and provides searchable analytics + auditable sync history.

## 2. Problem Statement
Manual review of liked videos does not scale. The user needs a reliable, queryable history with timestamps, transcript capture, and visibility into sync health and failures.

## 3. Objectives
- Sync liked videos every 60 minutes.
- Capture metadata and transcript status for each video.
- Avoid duplicates and support idempotent reruns.
- Provide dashboard visibility for run health and data quality.

## 4. Out of Scope
- Full YouTube channel analytics.
- Video download/storage.
- Public-facing UI.

## 5. Users
- Primary: Project owner/operator.
- Secondary: Read-only analysts.

## 6. Functional Requirements

### 6.1 Ingestion
- Scheduled hourly job.
- Fetch latest liked videos (delta-first strategy).
- Upsert by `video_id`.

### 6.2 Metadata capture
- Required fields:
  - `video_id`, `title`, `channel_title`, `published_at`, `liked_at`
  - `url`, `duration`, `thumbnail_url`
- Optional enrichment:
  - tags/category if available

### 6.3 Category/Tag enrichment pipeline
- Runtime host: `ai-node-01` (not the operator Mac).
- Schedule: hourly (`0 * * * *`) via host cron.
- Model endpoint: local Ollama on `ai-node-01` (`http://127.0.0.1:11434`), default model `llama3.2:1b`.
- Selection logic:
  - process only rows with missing `categories` or `tags`
  - update only missing values
  - do not overwrite already populated `categories`/`tags`
  - do not mutate ingestion timestamps
- Backfill mode:
  - one-time run can process all currently missing rows
  - ongoing hourly run handles only newly missing rows
### 6.4 Transcript pipeline
- Attempt order:
  1. existing captions (pytube)
  2. `youtube-transcript-api`
  3. `yt-dlp` CLI fallback
- Persist:
  - `transcript` (text)
  - `transcript_status` (`en-yta`, `ta-yta`, `en-ytdlp`, `none`, etc.)
  - `transcript_last_checked_at`
- Current runtime entrypoint on `automation-runner-01`:
  - `/opt/youtube-sync/Youtube_extract_liked_videos_V5.py`
- Transcript function used by that worker:
  - `get_transcript(youtube_url)`
- Main hourly driver:
  - `run(connectivity_only=False, backfill_missing_transcripts=False, start_ts=None)`
- Note: this worker covers sync + transcript capture only; category/tag enrichment is tracked separately.

### 6.5 Backfill mode
- One-time command for rows missing transcript.
- Configurable `backfill_limit`.
- Same transcript attempt order as standard flow.

### 6.6 Audit and run logs
- Each run records:
  - start/end, duration, fetched_count, inserted/updated counts, errors
- Each failure records error category and video context (when applicable).

## 7. Non-Functional Requirements
- Reliability: no data loss on restart.
- Performance: typical hourly run should complete in <2 minutes for <=50 fetched items.
- Backfill can run longer and must not block regular schedule indefinitely.
- Security: secrets in env only.

## 8. Data Model

### 8.1 Main table: `youtube_liked_videos`
- `video_id` (PK/unique)
- `title`, `url`, `channel_title`
- `published_at`, `liked_at`
- `categories`, `tags`
- `transcript`, `transcript_status`, `transcript_last_checked_at`
- `created_at`, `updated_at`

### 8.2 Operational tables
- `youtube_sync_run_logs`
- `youtube_sync_errors`

## 9. Dashboard Requirements

### 9.1 Overview
- Total videos
- New videos (24h/7d)
- Transcript coverage %
- Last successful sync time

### 9.2 Runs
- Run timeline with duration and status.
- Failure list with retry guidance.

### 9.3 Data explorer
- Search by title/channel/video ID.
- Filter by transcript status/date range.

### 9.4 Audit
- Record-level changes and run-level operations.

## 10. Success Metrics
- Sync success rate >= 99% monthly.
- Duplicate insert rate = 0.
- Transcript coverage improves over time via backfills.
- Median hourly run time < 90 seconds under normal load.

## 11. Risks and Mitigation
- API/rate limit issues: retries + backoff + alerting.
- Transcript unavailable for many shorts/music: explicit `none` status and periodic recheck policy.
- Long runs: enforce max runtime and split backfill from scheduled sync.

## 12. Milestones
1. Stable hourly ingestion
2. Transcript fallback + backfill
3. Dashboard + audit pages
4. Alerting and SLA reporting
