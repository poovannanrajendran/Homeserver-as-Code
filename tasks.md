# Agentic Architecture Tasks

## Phase 0 - Confirm the baseline

- [x] Validate current OpenClaw, Ollama, and host resource baselines on `ai-node-01`
- [x] Validate `automation-runner-01` resource headroom for the control plane
- [x] Confirm the existing observability stack on `automation-runner-01`
- [x] Confirm which services remain on `docker-host-01`
- [x] Record any current CPU, RAM, and disk headroom limits
- [x] Test gate: baseline numbers are written down and reviewed before any install work starts

## Phase 1 - Hermes Agent bootstrap

- [x] Install Hermes Agent on `ai-node-01`
- [ ] Verify the official Hermes setup flow
- [ ] Evaluate the OpenClaw migration path for Hermes
- [ ] Create a lightweight execution service on `ai-node-01`
- [ ] Restrict the worker to explicit allowlisted actions
- [ ] Add a minimal audit log for each execution
- [ ] Verify the worker can complete one end-to-end sample task
- [ ] Test gate: Hermes returns a structured result from one approved sample task

## Phase 2 - Paperclip governance layer

- [x] Install Paperclip on `automation-runner-01`
- [x] Define the Paperclip control-plane responsibilities
- [x] Choose the storage backend for policy and audit state
- [x] Create the first role model
- [x] Add tool permission rules by role
- [x] Add budget limits for model and tool usage
- [x] Add approval thresholds for sensitive actions
- [x] Verify the official Paperclip onboarding flow
- [x] Import the grounding pack as background reference
- [x] Run one end-to-end audited test task
- [x] Test gate: Paperclip records one audited action with the expected role and policy

## Phase 3 - Routing and delegation

- [x] Build n8n MCP Tools workflow (`Paperclip MCP Tools (FinOSafe)`) with 5 tool chains
- [x] Wire connections in workflow JSON (`web_search`, `financial_data_api`, `qdrant_search`, `youtube_api`, `reddit_social_search`)
- [x] Configure provider credentials in n8n's credential store/runtime nodes
- [x] Confirm all 5 MCP Trigger to action-node connections in n8n
- [x] Activate workflow and verify the MCP trigger endpoints
- [x] Register the local n8n MCP proxy in the FinOSafe agent runtime
- [x] Run an end-to-end test: Paperclip `alpha-researcher` called `web_search` and `financial_data_api`
- [ ] Define how OpenClaw dispatches work to Hermes
- [ ] Define how Paperclip routes work to specific agent roles
- [ ] Create the task payload contract between control plane and worker
- [ ] Add timeout and retry behavior
- [ ] Add failure handling for rejected tools and expired tasks
- [x] Test gate: Paperclip agent can call n8n MCP tools and receive structured results

## Phase 4 - Memory and knowledge

- [ ] Decide which memory belongs in OpenClaw
- [ ] Decide which memory belongs in the worker
- [ ] Decide which state belongs in the governance layer
- [ ] Add a namespace strategy for agent-specific memory
- [ ] Verify that no unsupported per-agent config override is required
- [ ] Test gate: chosen memory namespaces survive a restart and are still readable

## Phase 5 - Observability

- [ ] Add dashboards for Hermes worker health
- [ ] Add dashboards for Paperclip controller health
- [ ] Add alerts for CPU, memory, disk, and execution failures
- [ ] Add logs for tool calls and task dispatches
- [ ] Add a health summary output after each scheduled maintenance window
- [ ] Test gate: dashboards and alerts show the new components with no broken panels

## Phase 6 - Security hardening

- [ ] Keep secrets out of tracked docs
- [ ] Keep the worker on least privilege
- [ ] Keep governance storage separate from execution storage
- [ ] Restrict network access to only required services
- [ ] Review approval flows for destructive or external-facing actions
- [ ] Test gate: no secret values are present in tracked files

## Phase 7 - Scaling decisions

- [ ] Measure whether `ai-node-01` has enough headroom for Hermes
- [ ] Measure whether `automation-runner-01` has enough headroom for Paperclip
- [ ] Split workloads only if the first deployment proves useful
- [ ] Add a second worker only when load or latency demands it
- [ ] Revisit placement if model usage increases materially
- [ ] Test gate: scaling decision is based on measured headroom, not guesswork

## Phase 8 - Documentation

- [ ] Update the architecture docs with the final placement decision
- [ ] Update the runbooks with operator commands
- [ ] Update the inventory with any new services or timers
- [ ] Update the handoff notes with the final operating model
- [ ] Keep the public docs redacted and leave secrets in local-only files
- [ ] Test gate: docs match the live deployment model and contain no secret material
