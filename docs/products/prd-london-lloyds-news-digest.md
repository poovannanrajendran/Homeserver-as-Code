# PRD: London Lloyds News Digest

## 1. Product Summary
Create an automated intelligence digest focused on London market / Lloyd's ecosystem news, with source traceability, deduplication, summaries, and daily/periodic briefing views.

## 2. Problem Statement
Insurance market updates are fragmented across many sources. The user needs a single reliable digest with relevance scoring, timestamps, and audit trail for how each item entered the digest.

## 3. Objectives
- Collect relevant London/Lloyd's news from curated sources.
- Deduplicate and classify by theme.
- Generate concise summaries and a daily digest.
- Provide searchable historical archive and auditability.

## 4. Users
- Primary: operator/analyst.
- Secondary: leadership stakeholders consuming digest output.

## 5. Scope

### In scope
- Source ingestion (RSS, publisher pages, official market bulletins).
- Relevance filtering for Lloyd's and London insurance context.
- Summaries + tags + sentiment/impact labels.
- Dashboard and export.

### Out of scope
- Fully autonomous trading or underwriting recommendations.
- Paywalled source bypass.

## 6. Functional Requirements

### 6.1 Source ingestion
- Configurable source registry with enable/disable flags.
- Scheduled pulls (e.g., every 60 minutes) + manual refresh.
- Persist raw source payload and extraction timestamp.

### 6.2 Normalization and deduplication
- Canonical URL normalization.
- Title+source hash and semantic-near-duplicate checks.
- Merge duplicates under one canonical article record.

### 6.3 Relevance classification
- Rule + model hybrid:
  - keyword/phrase gates (`Lloyd's`, `London Market`, syndicates, reinsurance context)
  - model score for relevance confidence
- Store `relevance_score` and `relevance_reason`.

### 6.4 Summarization
- Short summary (1-3 bullets).
- Extended summary (paragraph) for detail view.
- Key entities extraction (carriers, brokers, regulators, geographies).

### 6.5 Digest generation
- Daily digest job (configurable timezone).
- Sections:
  - Top market moves
  - Regulatory and compliance updates
  - Claims/catastrophe-related notes
  - Technology/operations changes
- Output targets:
  - dashboard view
  - markdown/email payload

### 6.6 Auditability
- Track source URL, fetch time, parser version, summarizer model version.
- Track every reclassification and summary regeneration event.

## 7. Non-Functional Requirements
- Latency: source item available on dashboard within 10 minutes of fetch.
- Availability: scheduled runs succeed >= 99% monthly.
- Explainability: each digest item links to source and relevance reason.
- Operational DB resilience:
  - App runtime must retain local DB reachability (`POSTGRES_HOST=localhost`).
  - LAN clients may connect to runner Postgres on `192.168.1.30:5432`.
  - Postgres host bind should be `0.0.0.0:5432` to support both local app and LAN clients.

## 8. Data Model

### 8.1 Core tables
- `news_sources(id, name, type, base_url, enabled, fetch_interval_min)`
- `news_articles(id, source_id, canonical_url, title, published_at, fetched_at, raw_text, language, hash)`
- `news_enrichment(id, article_id, relevance_score, relevance_reason, summary_short, summary_long, sentiment, entities_json, model_version)`
- `news_digest_runs(id, started_at, ended_at, status, item_count, error_summary)`
- `news_digest_items(id, run_id, article_id, section, rank)`

### 8.2 Audit tables
- `news_audit_events(id, actor, action, resource_type, resource_id, before_json, after_json, created_at)`

## 9. Dashboard Requirements

### 9.1 Overview
- Articles ingested (24h/7d)
- Relevant items count
- Sources health
- Last successful digest run

### 9.2 Feed explorer
- Filters: date range, source, relevance band, section, sentiment.
- Search by title/entity/keyword.

### 9.3 Digest history
- Daily digest list with drill-down.
- Export to Markdown/CSV.

### 9.4 Audit
- Ingestion and enrichment lineage per article.

## 10. Success Metrics
- Precision of relevance filter (manual sampled) >= 85%.
- Digest generation success rate >= 99%.
- Duplicate rate after deduplication < 3%.
- Time-to-digest (publish to available summary) median < 2 hours.

## 11. Risks and Mitigation
- Source schema drift: parser versioning + fallback parser.
- Hallucination in summaries: strict source-grounded prompts and quote checks.
- Noise in relevance: tune thresholds with operator feedback loop.

## 12. Milestones
1. Source registry + ingestion pipeline
2. Relevance + deduplication
3. Summary and digest generation
4. Dashboard + audit + exports

## 13. Current Runtime Baseline (Automation Runner)
- App path: `/opt/automation/lloyds-market-news-digest`
- Runtime env: conda `314`
- Postgres target: `localhost:5432/lloyds_digest` (`dbuser`)
- Mongo target: Atlas `lloyds_digest_raw`
- Verified dry-run DB connectivity after LAN exposure change:
  - Postgres ping successful
  - Mongo ping successful
