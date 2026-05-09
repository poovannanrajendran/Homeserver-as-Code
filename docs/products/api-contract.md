# API Contract (Dashboard Platform)

## 1. Conventions
- Base path: `/api/v1`
- Auth: `Authorization: Bearer <JWT>`
- Pagination: cursor-based (`next_cursor`, `limit`)
- Time filters: ISO-8601 UTC (`from`, `to`)
- Every response includes `request_id`.

## 2. Core Endpoints

## 2.1 Projects
- `GET /projects`
- `GET /projects/{projectSlug}`

Response example:
```json
{
  "request_id": "req_123",
  "data": [{"slug":"youtube-liked-videos","name":"YouTube Liked Videos","status":"active"}]
}
```

## 2.2 Runs
- `GET /projects/{projectSlug}/runs?limit=50&cursor=...&status=success|failed`
- `GET /projects/{projectSlug}/runs/{runId}`

Run details includes metrics and errors.

## 2.3 Audit
- `GET /projects/{projectSlug}/audit?resource_type=video&actor_id=...&from=...&to=...`

## 2.4 Alerts
- `GET /projects/{projectSlug}/alerts`
- `PATCH /projects/{projectSlug}/alerts/{id}` (resolve/ack)

## 3. YouTube Endpoints
- `GET /projects/{projectSlug}/youtube/videos`
  - filters: `transcript_status`, `channel`, `q`, `liked_from`, `liked_to`
- `GET /projects/{projectSlug}/youtube/videos/{videoId}`
- `POST /projects/{projectSlug}/youtube/backfill`
  - body: `{ "limit": 200, "dry_run": false }`

Video response:
```json
{
  "video_id": "abc123",
  "title": "Example",
  "channel_title": "Channel",
  "liked_at": "2026-04-04T10:00:00Z",
  "transcript_status": "en-yta"
}
```

## 4. Lloyds News Endpoints
- `GET /projects/{projectSlug}/news/articles`
  - filters: `source`, `relevance_min`, `sentiment`, `q`, `published_from`, `published_to`
- `GET /projects/{projectSlug}/news/articles/{id}`
- `GET /projects/{projectSlug}/news/digests`
- `GET /projects/{projectSlug}/news/digests/{digestRunId}`
- `POST /projects/{projectSlug}/news/digest/run`

Digest response:
```json
{
  "digest_run_id": 42,
  "status": "success",
  "item_count": 18,
  "sections": ["Top market moves", "Regulatory updates"]
}
```

## 5. Ingestion/Worker Inbound Endpoints
- `POST /internal/projects/{projectSlug}/runs/start`
- `POST /internal/projects/{projectSlug}/runs/{runId}/metric`
- `POST /internal/projects/{projectSlug}/runs/{runId}/complete`

Security:
- Internal endpoints protected with service token + IP allowlist.

## 6. Error Model
```json
{
  "request_id": "req_123",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid filter",
    "details": {"field":"from"}
  }
}
```

## 7. OpenAPI Next Step
- Convert this contract to `openapi.yaml`.
- Generate TS client for frontend and Python client for workers.
