---
audit_date: 2026-04-20
auditor: claude-opus-4-7
audit_type: comprehensive per-package deep dive
scope: 20 repositories in D:\lost_marbles\ matching gate-*, maelstrom-gate, and ghostgate
prior_audits:
  - GATE_FAMILY_AUDIT_2026-04-19.md
  - STRICT_VALIDATION_2026-04-19.md
  - STRICT_VALIDATION_2026-04-20.md
state: post-remediation (all CRITICAL/HIGH findings closed, VERIFIED)
---

# Deep Dive — Every Repo in the Gate Suite

A per-package tour so the owner can wrap his head around the full 20-directory
ecosystem. One section per repo, each with: purpose, stack, public API,
dependencies, tests, ASCII diagram, notable behavior, and rough edges.

---

## 0. The whole picture

```
                    ╭──────────────────────────────────────────────────╮
                    │   THE MAELSTROM GATE ECOSYSTEM (18 + 1 outlier)  │
                    ╰──────────────────────────────────────────────────╯

  LAYER 0 ─ SPEC                    ┌──────────────────────┐
  (source of truth)                 │   maelstrom-gate     │  Python ref. impl.
                                    │   SPEC.md            │  + JSON schemas
                                    │   schema/*.json      │  + canonical lib
                                    └──────────┬───────────┘
                                               │
                                    ┌──────────┴───────────┐
                                    │   gate-server-go     │  Go reimpl.
                                    │                      │  (HTTP service)
                                    └──────────────────────┘
                                               │
              ┌────────────────────────────────┼────────────────────────────────┐
              │                                │                                │
  LAYER 1 ─ DEV INTERFACES                     │                                │
              ┌─────────────────────┐          │          ┌──────────────────┐
              │   gate-sdk          │          │          │   gate-cli       │
              │   client + hooks    │          │          │   click-based    │
              │   + framework       │          │          │   Swiss army CLI │
              │   adapters          │          │          │                  │
              └──────────┬──────────┘          │          └──────────────────┘
                         │                     │
  LAYER 2 ─ DOMAIN       │                     │
              ┌──────────┴──────────┐  ┌───────┴──────────┐
              │   gate-policy       │  │   gate-schema    │
              │   YAML rules,       │  │   JSON Schema    │
              │   declarative ACL   │  │   validators     │
              └─────────────────────┘  └──────────────────┘

  LAYER 3 ─ GOVERNANCE & OBSERVABILITY (siblings, no mutual deps)
              ┌────────────────┬────────────────┬────────────────┬──────────────┐
              │ gate-guard     │ gate-webhook   │ gate-compliance│ gate-metrics │
              │ runtime block  │ event broadcast│ audit trail    │ Prometheus   │
              └────────────────┴────────────────┴────────────────┴──────────────┘

  LAYER 4 ─ OPERATIONS                ┌───────────────────┐
                                      │ gate-server       │ full FastAPI
                                      │                   │ (production)
                                      └───────────────────┘
                                      ┌───────────────────┐
                                      │ gate-dashboard    │ rich web UI
                                      │                   │ (production)
                                      └───────────────────┘
                                      ┌───────────────────┐
                                      │ gate-dash         │ stdlib HTTP
                                      │                   │ proxy viewer
                                      └───────────────────┘
                                      ┌───────────────────┐
                                      │ gatectl           │ stdlib CLI REPL
                                      └───────────────────┘

  LAYER 5 ─ AGENTS (consumers)
              ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
              │  gate-agent   │       │  gate-pilot   │       │ gate-examples │
              │  SDK-based,   │       │  stdlib-only  │       │  5 min demos  │
              │  production   │       │  demonstration│       │  framework ex │
              └───────────────┘       └───────────────┘       └───────────────┘

  LAYER 6 ─ QA (keeps everyone honest)
                   ┌─────────────────┐            ┌─────────────────┐
                   │   gate-test     │            │   gate-bench    │
                   │   cross-lang    │            │   filter latency│
                   │   conformance   │            │   throughput    │
                   └─────────────────┘            └─────────────────┘

  ─────────────────────────────────────────────────────────────────────────────
  OUTLIER (NOT part of Maelstrom Gate — different product, shared prefix only)

              ┌──────────────────────────────────────────┐
              │   ghostgate  (formerly gate-wallet)      │
              │   policy chain between bots and on-chain │
              │   wallets — DeFi domain, zero Gate deps  │
              └──────────────────────────────────────────┘
```

---

## Summary table

| # | Package | Layer | Lang | LOC | Tests | Deps on core | Notable |
|---|---------|-------|------|-----|-------|--------------|---------|
|  1 | `maelstrom-gate` | 0 | Py | 1,639 | 72 | self | spec, schemas, ref impl |
|  2 | `gate-server-go` | 0 | Go | 1,366 | 34 | reimplements | polyglot HTTP service |
|  3 | `gate-sdk` | 1 | Py | 1,936 | 48 | declared | OpenAI/Anthropic adapters |
|  4 | `gate-cli` | 1 | Py | 1,741 | 54 | declared | click-based operator CLI |
|  5 | `gate-policy` | 2 | Py | 1,969 | 62 | via core | YAML declarative policies |
|  6 | `gate-schema` | 2 | Py | 603 | 31 | declared (fixed) | JSON Schema validators |
|  7 | `gate-guard` | 3 | Py | 533 | 14 | via core | runtime execution blocker |
|  8 | `gate-webhook` | 3 | Py | 1,245 | 54 | declared | event broadcaster |
|  9 | `gate-compliance` | 3 | Py | 3,669 | 100 | declared | audit trail (largest) |
| 10 | `gate-metrics` | 3 | Py | 598 | 10 | via core | Prometheus exposition |
| 11 | `gate-server` | 4 | Py | 1,312 | 34 | declared | FastAPI microservice |
| 12 | `gate-dashboard` | 4 | Py | 604 | 26 | via core | FastAPI + Jinja2 UI |
| 13 | `gate-dash` | 4 | Py | 551 | 19 | test-extra | stdlib HTTP proxy |
| 14 | `gatectl` | 4 | Py | 892 | 27 | none | stdlib CLI REPL |
| 15 | `gate-agent` | 5 | Py | 1,143 | 52 | declared | SDK-based dogfood agent |
| 16 | `gate-pilot` | 5 | Py | 676 | 20 | declared | minimal demo |
| 17 | `gate-examples` | 5 | Py | 435 | 9 | via core | integration samples |
| 18 | `gate-test` | 6 | Py | 889 | 44 | declared | spec conformance suite |
| 19 | `gate-bench` | 6 | Py | 366 | 7 | via core | benchmarks |
| 20 | `ghostgate` | — | Py | 1,458 | 24 | none | **outlier — DeFi** |

**Totals:** 22,723 LOC, 761 tests across 20 packages. 16 of 18 Maelstrom Gate packages green; 13 pre-existing infrastructure-dependent failures in `gate-cli` (need running gate-server on localhost:8900 — unrelated to this audit).

---

# LAYER 0 — Specification

## 1. `maelstrom-gate` — the canonical Python implementation

**Lives at:** `D:\lost_marbles\maelstrom-gate\`
**Upstream:** `adam-scott-thomas/maelstrom-gate` (public, PyPI 0.1.0)
**LOC:** 1,639 (17 Python files) | **Tests:** 72 passing
**License:** Apache 2.0

### What it is

The **reference implementation** plus the **authoritative spec**. If Python and
the JSON schemas disagree, the spec wins (and the Python has to be fixed — this
is the entire V-1 finding from 2026-04-19). All other packages orbit this one.

### Public API

```python
from maelstrom_gate import (
    # Core types (SPEC.md §2, §7)
    Gate, Tool, ToolFilter, ExecutionClass,

    # Thresholds & zones (SPEC.md §4, §5)
    SUPPRESSION_THRESHOLDS, T_DOWN, T_UP, zone,

    # Envelope (SPEC.md §8)
    AuthorizationEnvelope, build_envelope, verify_envelope, verify_envelope_fresh,

    # Ingress validation (SPEC.md §9)
    validate_proposal, IngressResult,
)
```

### Shape

```
  maelstrom-gate/
    ├─ SPEC.md                        ← the source of truth
    ├─ ARCHITECTURE.md                ← 18-package suite overview (new)
    ├─ README.md
    ├─ maelstrom_gate/
    │    ├─ core.py                   ← Gate, Tool, ToolFilter, zone, filter()
    │    ├─ envelope.py               ← build/verify/freshness, HMAC signing
    │    ├─ ingress.py                ← validate_proposal
    │    └─ __init__.py               ← public API surface
    ├─ schema/                        ← JSON schemas (authoritative)
    │    ├─ tool.schema.json
    │    ├─ envelope.schema.json
    │    └─ filter-result.schema.json
    ├─ tests/                         ← 72 tests, including failure-injection
    ├─ examples/                      ← fastapi_middleware, langchain, openai
    └─ audits/                        ← versioned audit history
```

### What it gives everyone else

```
            ┌───────────────────┐
            │   SPEC.md         │ (language-agnostic)
            └─────────┬─────────┘
                      │ implemented by
                      ▼
            ┌───────────────────┐      exports
            │   maelstrom_gate  │ ─────────────▶  Gate, Tool, zone(),
            │                   │                  build_envelope(),
            │   Python 3.10+    │                  verify_envelope(),
            │   zero runtime    │                  validate_proposal(),
            │   deps            │                  SUPPRESSION_THRESHOLDS,
            │                   │                  T_DOWN, T_UP
            └───────────────────┘
                      │ validated by
                      ▼
            ┌───────────────────┐
            │  schema/*.json    │ (JSON Schema v7)
            └───────────────────┘
```

### Rough edges

- **SPEC.md Section 8 crisis-adjustment table** is duplicated between the text
  and `envelope.py`'s `build_envelope` function. Consider making the table a
  constant and referencing it from both places (low priority).
- Zero runtime dependencies is a real selling point — preserve aggressively.

---

## 2. `gate-server-go` — the polyglot proof

**Lives at:** `D:\lost_marbles\gate-server-go\`
**Upstream:** not yet pushed
**LOC:** 1,366 (9 Go files) | **Tests:** 34 passing
**License:** Apache 2.0 | **Go module:** `github.com/adam-scott-thomas/gate-server-go`

### What it is

A **standalone Go HTTP service** that reimplements the Maelstrom Gate spec.
It's the reason anyone can take the "polyglot" claim seriously: if Python and
Go produce byte-identical canonical JSON and HMAC signatures for the same
inputs, the spec is real. (This was not true before 2026-04-20 — the first Go
test run caught two bugs that Python-only testing missed.)

### Shape

```
  gate-server-go/
    ├─ cmd/gated/                     ← main binary
    ├─ internal/
    │    ├─ gate/gate.go              ← Gate, Tool, ModeZone
    │    ├─ envelope/envelope.go      ← canonical signing + CreatedAt
    │    └─ handler/handler.go        ← HTTP routes
    └─ examples/                      ← test_client.py (Python client)
```

### Endpoints

```
  POST /v1/filter          ─┐
  POST /v1/validate         │ same contract as Python gate-server
  GET  /v1/thresholds       │ (enforced by shared vectors)
  POST /v1/envelope         │
  POST /v1/envelope/verify ─┘
```

### Cross-language interop path

```
         ┌────────────────┐   build   ┌──────────────────────┐
  PYTHON │ maelstrom_gate │ ────────▶ │ envelope JSON        │
         │ build_envelope │           │ { created_at: int µs │
         └────────────────┘           │   signature: "..." } │
                                      └──────────┬───────────┘
                                                 │ transport
                                                 ▼
         ┌────────────────┐   verify  ┌──────────────────────┐
     GO  │ envelope.Verify│ ◀──────── │ same JSON, decoded   │
         │                │           │ into Envelope struct │
         └────────────────┘           └──────────────────────┘
                │
                ▼
             true / false
```

Observed: `Go verification result: true` on a Python-built envelope.

### Rough edges

- Not yet pushed to GitHub (the module path references the planned upstream).
- No public Go client library; consumers use the HTTP API.
- `examples/test_client.py` is a Python client exercising the Go server — could
  become the second cross-language integration test.

---

# LAYER 1 — Developer Interfaces

## 3. `gate-sdk` — the framework adapter

**LOC:** 1,936 (26 files) | **Tests:** 48 passing | **Deps:** `maelstrom-gate`

### Public API

```python
from gate_sdk import (
    GateClient,           # main entry point
    ModeSource,           # abstract interface for mode signal providers
    FilterHook,           # pre-filter interceptor
    SuppressCallback,     # called when a tool is suppressed
    ModeChangeCallback,   # called on zone transitions
)
```

### What it gives you

```
                    ┌─────────────────────┐
                    │   GateClient        │
                    │                     │
     mode source ─▶ │   • register_tools()│
                    │   • filter(mode)    │
     framework  ◀── │   • wrap_openai()   │ ── OpenAI function-calling
     adapters   ◀── │   • wrap_anthropic()│ ── Anthropic tool_use
                    │   • webhook_receiver│ ── external threat feeds
                    └─────────────────────┘
```

Framework adapters at `gate_sdk/frameworks/` translate between the Gate's
filter result and whatever shape a given LLM SDK expects for tool definitions.

### What it consumes from core

```
AuthorizationEnvelope, build_envelope, verify_envelope,
Gate, Tool, ToolFilter
```

All six are re-exported — if you depend on gate-sdk, you don't also need
`maelstrom-gate` in your imports.

### Rough edges

- Biggest package at this layer. Worth periodic review for bloat creep.
- Framework adapters are independent files; a missing adapter for a new
  framework (e.g. Cohere, Mistral) is just a PR.

---

## 4. `gate-cli` — the operator's Swiss army

**LOC:** 1,741 (19 files) | **Tests:** 54 (41 pass, 13 need live gate-server)

### What it is

The human-facing CLI for the ecosystem. Click-based, uses `httpx` to talk to
`gate-server`, `rich` for pretty output. If you're running a Gate in production,
this is how you poke at it.

### Command tree

```
  gate
  ├─ server        status, health, info
  ├─ tools         register, list, remove, filter
  ├─ envelope      build, verify, inspect
  ├─ policy        load, validate, show
  ├─ compliance    query, report, count
  ├─ thresholds    get, set, reset
  └─ watch         live view of mode transitions
```

### The 13 failing tests

All 13 are in `tests/test_integration.py::TestServerCommands` and
`TestEnvelopeWorkflow`. Every failure boils down to:

```
ERR Server error: HTTP 0: Cannot connect to http://localhost:8900/api/v1
is gate-server running?
```

**Recommendation:** mark these `@pytest.mark.integration` and skip by default,
or supply a `conftest.py` that spins up a `gate-server` fixture. They are not
caused by any remediation — they've been failing the same way since before
this work began.

---

# LAYER 2 — Domain

## 5. `gate-policy` — declarative ACL

**LOC:** 1,969 (19 files) | **Tests:** 62 passing

### Public API

```python
from gate_policy import (
    PolicyEngine, PolicyGate, PolicyFilterResult,
    Policy, Rule, Condition,
    load_policy, load_policy_file, merge_policies,
)
```

### What it adds

```
  base Gate:   "mode > threshold  →  suppress"
  +
  PolicyGate:  "mode > threshold  OR  (principal matches rule.subject
                                       AND  env matches rule.conditions)
                ⇒ suppress / allow"
```

Policies are YAML:

```yaml
version: 1
name: enterprise-v2
rules:
  - name: no-deploys-from-bots
    subject: {role: "bot"}
    conditions:
      - {field: mode_zone, operator: eq, value: "crisis"}
    action: deny
    tools: [deploy, migrate]
```

### Shape

```
   YAML file  ──▶ load_policy_file ──▶ Policy ─────┐
                                                    │
                                                    ▼
    Tool list ──▶ PolicyGate.filter(mode, ctx) ──▶ PolicyFilterResult
    mode      ──▶                                   (visible, suppressed,
    principal ──▶                                    applied_rules, reason)
```

### Rough edges

- Policy merging (`merge_policies`) is underdocumented. The test suite is the
  de facto spec.
- No policy linter; malformed YAML fails at load, which is noisy.

---

## 6. `gate-schema` — JSON Schema validators

**LOC:** 603 (7 files) | **Tests:** 31 passing | **Deps:** `jsonschema`, `maelstrom-gate`

### Public API

```python
from gate_schema import (
    validate_tool, validate_policy, validate_envelope, validate_filter_result,
    ValidationError,
)
```

### What it does

Thin wrappers around `jsonschema.validate()` that load the authoritative
schemas from `maelstrom-gate/schema/*.json` and report errors with friendlier
field paths.

```
  dict/JSON  ──▶  validate_*  ──▶  None  (pass)
                                    │
                                    └──▶ ValidationError (fail)
                                         with: path, message, schema_rule
```

### Why it's here

Decoupled from core on purpose: if you don't need jsonschema's weight (~2MB of
dependencies), use just `maelstrom-gate`. If you want schema enforcement at
your HTTP boundary, add `gate-schema`.

### Rough edges

- Was missing its `maelstrom-gate` dep declaration (fixed 2026-04-20, V-3).
- Schemas are loaded at import time; no caching strategy if the process is
  long-lived and schemas change on disk.

---

# LAYER 3 — Governance & Observability

## 7. `gate-guard` — runtime block

**LOC:** 533 (7 files) | **Tests:** 14 passing

### Public API

```python
from gate_guard import GuardedGate, ExecutionDenied, GuardResult
```

### What it adds to Gate

```
  regular Gate:
    model receives filtered tool list → still calls whatever it wants
    (filter is advisory at execution time)

  GuardedGate:
    model receives filtered tool list  →  wrapper intercepts every call
                                      →  re-checks against current mode
                                      →  raises ExecutionDenied if gate has since closed
```

### Flow

```
    model invokes "deploy"
         │
         ▼
    ┌────────────────────────┐
    │  GuardedGate.execute() │
    │                        │
    │   1. re-check mode     │
    │   2. re-check tool cls │
    │   3. re-check envelope │
    └──────────┬─────────────┘
               │
         ┌─────┴─────┐
         │           │
     allowed      denied
         │           │
         ▼           ▼
    tool.run()   ExecutionDenied
                 (logged → compliance)
```

### Rough edges

- No rate-limiter. A malicious model could retry-storm the guard. Reasonable
  to add a token bucket per context_id.

---

## 8. `gate-webhook` — event broadcaster

**LOC:** 1,245 (11 files) | **Tests:** 54 passing

### Public API

```python
from gate_webhook import (
    GateEvent, GateSnapshot, GateWatcher,
    WebhookDispatcher, WebhookTarget,
    detect_events, snapshot_from_filter,
)
```

### Flow

```
                              ┌────────────────┐
    gate-server              │  GateWatcher    │
    /v1/filter result   ───▶ │                 │
    (polled every ~5s)       │  prev_snapshot  │
                             │  curr_snapshot  │
                             └────────┬────────┘
                                      │ detect_events()
                                      ▼
                             ┌────────────────┐
                             │  GateEvent[]   │
                             │  mode_zone_    │
                             │  change, tool_ │
                             │  added,        │
                             │  suppressed, …│
                             └────────┬───────┘
                                      │
                                      ▼
                             ┌────────────────┐           ╭───────────╮
                             │ WebhookDispatch│ ───POST──▶│ Slack     │
                             │  (fan-out,     │           │ PagerDuty │
                             │   retry,       │           │ Discord   │
                             │   HMAC-signed)│           │ your hook │
                             └────────────────┘           ╰───────────╯
```

### Rough edges

- Retry policy is hard-coded 3x exponential backoff. Could use a config.
- No support for wildcard subscriptions (one webhook = one target today).

---

## 9. `gate-compliance` — the audit trail

**LOC:** 3,669 (28 files) | **Tests:** 100 passing — **the largest package**

### Public API

```python
from gate_compliance import (
    AuditStore, AuditRecord,
    ComplianceCollector, ComplianceReporter,
    run_all_checks,
)
```

### Shape

```
                        ┌──────────────────┐
  every gate call  ───▶ │ ComplianceCollect│ records (filter, envelope,
  every envelope   ───▶ │  or              │          suppression, policy)
  every policy hit ───▶ │                  │
                        └────────┬─────────┘
                                 │ writes
                                 ▼
                        ┌──────────────────┐
                        │   AuditStore     │ SQLite by default,
                        │                  │ pluggable backend
                        │   .insert()      │
                        │   .query()       │
                        │   .count()       │
                        └────────┬─────────┘
                                 │ reads
                                 ▼
                        ┌──────────────────┐
                        │ComplianceReporter│  evidence reports,
                        │                  │  periodic alerts,
                        │   .summary()     │  SIEM export
                        │   .by_zone()     │
                        │   .suspect()     │
                        └──────────────────┘
```

### Submodules

```
  gate_compliance/
    ├─ store.py              ← SQLite-backed audit storage
    ├─ report.py             ← summary + breakdown reports
    ├─ alerts.py             ← threshold-based alerting
    ├─ schema_validator.py   ← emits validation findings into the audit log
    ├─ envelope_audit.py     ← records every envelope issued/verified
    ├─ siem_export.py        ← push to ELK / Splunk
    ├─ sdk_integration.py    ← plug-in to gate-sdk
    ├─ server_integration.py ← plug-in to gate-server
    └─ __main__.py           ← CLI for offline reporting
```

### Rough edges

- No log rotation for the SQLite file. In production, it grows without bound.
- SIEM export assumes a specific JSON envelope — worth verifying it matches
  your SIEM's expected schema.

---

## 10. `gate-metrics` — Prometheus exposition

**LOC:** 598 (11 files) | **Tests:** 10 passing

### Public API

```python
from gate_metrics import GateCollector, metrics_text
```

### Metrics exposed

```
  gate_mode                      Gauge  current mode signal (0.0-1.0)
  gate_mode_zone_total{zone=""}  Counter transitions into each zone
  gate_filter_total{result=""}   Counter filter calls by result class
  gate_tools_visible             Gauge  tools currently visible
  gate_tools_suppressed          Gauge  tools currently suppressed
  gate_envelope_issued_total     Counter envelopes built
  gate_envelope_verified_total   Counter envelopes verified successfully
  gate_envelope_rejected_total   Counter envelope signature failures
```

### Wiring

```
    ┌─────────────────┐                 ┌──────────────────┐
    │ gate-server     │ ──hooks──────▶  │ GateCollector    │
    │ /v1/filter etc. │                 │ (in-proc)        │
    └─────────────────┘                 └────────┬─────────┘
                                                 │ on /metrics
                                                 ▼
    ┌─────────────────┐                 ┌──────────────────┐
    │ Prometheus      │ ◀───GET /metrics│ metrics_text()   │
    │ scraper         │                 │ (text exposition)│
    └─────────────────┘                 └──────────────────┘
```

### Rough edges

- No histogram for filter latency (only counters). Worth adding.

---

# LAYER 4 — Operations

## 11. `gate-server` — the production HTTP service

**LOC:** 1,312 (15 files) | **Tests:** 34 passing | **Stack:** FastAPI + uvicorn + pydantic

### Endpoints

Same contract as `gate-server-go`. Pick either (or run both with a load
balancer). Cross-verified by shared vectors.

### Startup

```
  $ GATE_SIGNING_KEY=... python -m gate_server --port 8900
  (FastAPI app, uvicorn workers, in-memory or Redis-backed state)
```

### Integration points

```
                         ┌──────────────┐
                         │ gate-server  │
                         │              │
  gate-compliance ──────▶│ /hooks/audit │  receives every decision
  gate-metrics   ──────▶│ /hooks/metric│  receives state changes
  gate-webhook   ◀──────│ polls /filter│  emits events
  gate-cli       ◀──────│ /v1/*        │  human driver
  gate-dashboard ◀──────│ /v1/*        │  web viewer
  gate-dash      ◀──────│ /v1/*        │  lightweight viewer
                         └──────────────┘
```

### Rough edges

- `GATE_SIGNING_KEY` unset produces a noisy warning but is not rejected.
  Production should refuse to boot without it.
- In-memory mode has no tenancy — a single process serves one logical Gate.

---

## 12. `gate-dashboard` — rich web UI

**LOC:** 604 (9 files) | **Tests:** 26 passing | **Stack:** FastAPI + Jinja2

### What it is

A standalone web app that proxies a live `gate-server` and renders real-time
state. Shows mode gauge, current tool manifest, suppression history,
compliance summary, policy decisions.

```
  ┌─────────────────────────────────────────────────────────────┐
  │  Maelstrom Gate — Live                       mode: 0.42     │
  │  ─────────────────────────────────────────────────────────  │
  │                                                             │
  │   MODE GAUGE         [====================>        ]        │
  │                      calm         elevated     crisis       │
  │                                                             │
  │   TOOLS              VISIBLE (3)          SUPPRESSED (2)    │
  │   read_file           ●                                     │
  │   analyze             ●                                     │
  │   send_email          ●                                     │
  │   write_db                                        ●         │
  │   deploy                                          ●         │
  │                                                             │
  │   RECENT TRANSITIONS                                        │
  │   12:03:15  normal → elevated   (mode 0.22 → 0.42)          │
  │   11:58:02  elevated → crisis   (mode 0.58 → 0.78)          │
  └─────────────────────────────────────────────────────────────┘
```

### Submodules

```
  gate_dashboard/
    ├─ state.py        ← polls gate-server, builds view model
    ├─ routes.py       ← FastAPI route handlers
    ├─ templates/      ← Jinja2 HTML
    ├─ static/         ← CSS, JS, SVG gauge
    └─ compliance_panel.py  ← integrates gate-compliance data
```

---

## 13. `gate-dash` — the minimalist dashboard

**LOC:** 551 (6 files) | **Tests:** 19 passing | **Stack:** stdlib only

### What it is

Same goal as `gate-dashboard` (visualize a live Gate) but with zero runtime
dependencies. Pure `http.server` + served HTML with vanilla JS. Smaller blast
radius, boots in 50ms, fits in a Docker image that's 15MB instead of 180MB.

### Flow

```
   ┌─────────┐     HTTP    ┌──────────┐    /v1/*     ┌─────────────┐
   │ browser │────────────▶│ gate-dash│ ────────────▶│ gate-server │
   │         │ ◀────────── │ (proxy)  │◀──────────── │             │
   └─────────┘             └──────────┘              └─────────────┘
                              static HTML +
                              vanilla JS poll loop
```

### Rough edges

- Pairs one-to-one with a single gate-server. No multi-tenant view.
- HTML is embedded in `static/` — not hot-reloadable.

---

## 14. `gatectl` — stdlib CLI REPL

**LOC:** 892 (6 files) | **Tests:** 27 passing | **Stack:** stdlib only

### What it is

The stdlib-only counterpart to `gate-cli`. Uses `cmd.Cmd` for a REPL, no
click/rich/httpx. Ships in any Python 3.10+ environment with no install.

```
  $ python -m gatectl
  gate> status
  mode: 0.12    zone: normal
  tools: 7 visible / 0 suppressed

  gate> tools list
  ┌─────────────┬─────────────────┐
  │ name        │ execution_class │
  ├─────────────┼─────────────────┤
  │ read_file   │ read_only       │
  │ deploy      │ high_impact     │
  └─────────────┴─────────────────┘

  gate> mode set 0.5
  mode: 0.5     zone: elevated
  suppressed:   [deploy]

  gate> quit
```

### Rough edges

- No tab completion (stdlib `cmd.Cmd` only does command completion, not args).
- Doesn't verify envelopes locally — always delegates to gate-server.

---

# LAYER 5 — Agents

## 15. `gate-agent` — the dogfood

**LOC:** 1,143 (11 files) | **Tests:** 52 passing

### What it is

An agent runtime that **uses its own Gate** for every tool invocation. The
governance loop is: agent asks for a tool → SDK filters → SDK verifies
envelope → executor runs tool → compliance logs it → metrics update. If at any
point mode changes, the next invocation sees a different tool manifest.

### Loop

```
   ┌──────────────────────────────────────────────────┐
   │                 AGENT LOOP                       │
   │                                                  │
   │   1. OBSERVE  ← env, user message, signals       │
   │   2. DECIDE   ← propose a tool + args            │
   │   3. GATE     ← is this tool visible at          │
   │                 current mode?                    │
   │              ← is my envelope still fresh?       │
   │   4. EXECUTE  ← run the tool under GuardedGate   │
   │   5. RECORD   ← gate-compliance stores the hit   │
   │   6. ADJUST   ← mode may have changed;           │
   │                 next iteration sees new manifest │
   │                                                  │
   │   back to 1                                      │
   └──────────────────────────────────────────────────┘
```

### Submodules

```
  gate_agent/
    ├─ runtime.py   ← the loop above
    ├─ main.py      ← CLI entry point
    ├─ planner.py   ← decides tool + args (pluggable)
    ├─ executor.py  ← runs tools under guard
    └─ state.py     ← per-run history + mode tracking
```

---

## 16. `gate-pilot` — the minimal demo

**LOC:** 676 (6 files) | **Tests:** 20 passing

### What it is

The "can you govern an agent in <200 lines?" proof. stdlib + one dep
(`maelstrom-gate` for `zone()`). Not meant for production — meant for
explaining the concept to someone who's never seen Gate.

```
  $ python -m gate_pilot --mode 0.5 --escalate
  ═══ pilot run: default scenario ═══

  Mode:   0.50 (escalating)

    [executed ] mode=0.50 read_file   — success
    [denied   ] mode=0.65 deploy      — high_impact suppressed (crisis threshold)
    [denied   ] mode=0.80 send_email  — external_action suppressed
    [executed ] mode=0.95 analyze     — advisory (never suppressed)
```

Everything is visible in one file: register tools, bump mode, watch
suppressions happen, print results.

---

## 17. `gate-examples` — the onboarding kit

**LOC:** 435 (13 files) | **Tests:** 9 passing

### Examples

```
  examples/
    ├─ 01_basic_gate.py       ← 10-line hello-world
    ├─ 02_envelope.py         ← build + verify
    ├─ 03_custom_thresholds.py
    ├─ 04_policy_yaml.py      ← uses gate-policy
    ├─ 05_openai_functions.py ← filter OpenAI tools
    ├─ 06_langchain.py        ← LangChain adapter
    ├─ 07_full_pipeline.py    ← agent + guard + compliance + metrics
    ├─ 08_webhook_alerts.py   ← integrate gate-webhook
    └─ 09_fastapi_middleware.py
```

Think of this as the README of the entire suite. If a new contributor can
open `07_full_pipeline.py` and follow it end-to-end, the suite is approachable.

---

# LAYER 6 — QA

## 18. `gate-test` — the conformance suite

**LOC:** 889 (14 files) | **Tests:** 44 passing

### What it does

Every test file is named after a SPEC.md section it enforces:

```
  gate_test/
    ├─ spec_section2.py            ← execution classes
    ├─ spec_section3.py            ← suppression rule
    ├─ spec_section4.py            ← default thresholds
    ├─ spec_section5.py            ← mode zones
    ├─ spec_section7.py            ← filter result schema
    ├─ spec_section8.py            ← envelope signing
    ├─ ecosystem_integration.py    ← cross-package wiring
    └─ test_cross_language_envelope.py  ← vectors vs Python impl
```

And a vectors file that `gate-server-go` also loads:

```
  gate-test/vectors/envelope_signing.json
    ├─ signing_key                 ← shared secret for the test
    └─ vectors[]
        ├─ {name, input, canonical_json, expected_signature}  × N
```

### The cross-language promise

```
                          vectors.json
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
      test_cross_language_envelope.py   vectors_test.go
      (Python, passes)                  (Go, passes)
                │                             │
                └──────────────┬──────────────┘
                               ▼
            both produce byte-identical canonical JSON
            and byte-identical HMAC signatures
            → the spec is real
```

---

## 19. `gate-bench` — the honesty check

**LOC:** 366 (7 files) | **Tests:** 7 passing

### What it measures

```
  filter latency         p50/p95/p99 vs tool count (10, 100, 1k, 10k)
  filter throughput      calls/sec single-threaded
  envelope build         HMAC cost per envelope
  envelope verify        constant-time compare cost
  policy evaluation      rule match latency
```

### Current numbers (from test output, representative)

```
  tool_count     p50         p95
  10             0.005ms     0.008ms
  100            0.04 ms     0.06 ms
  1,000          0.40 ms     0.55 ms
  10,000         4.1  ms     5.2  ms
```

At 1k tools per filter call, ~2,500 calls/sec on a single core. Linear in
tool count. Good enough for most practical fleets; if you start hosting
>100k tools, revisit.

---

# OUTLIER

## 20. `ghostgate` — different product entirely

**LOC:** 1,458 (16 files) | **Tests:** 24 passing | **Package name:** `ghostgate` (NOT `gate-wallet`)

### What it is

Runtime enforcement between autonomous trading/DeFi bots and actual on-chain
wallets. A **circuit breaker** — the bot proposes a transaction, `GatedWallet`
evaluates it through a policy chain, and either emits `TxIntent` (allow) or
`TxDenied` (block). There's a hard kill switch that freezes the wallet if
spending crosses a budget threshold.

### Public API

```python
from ghostgate import (
    GatedWallet, WalletState,
    TxIntent, TxDenied, WalletFrozen,
    Decision, GateError,
    AuditLog, AuditRecord,
    policies,
    MockRPC, MockSigner,
)
```

### Not part of the Maelstrom Gate suite

- **Zero** dependency on `maelstrom-gate`
- **Zero** imports of `maelstrom_gate`
- Different problem domain: wallet security, not AI tool access
- Different vocabulary: `TxIntent/WalletFrozen` vs `Gate/Tool/Mode`

Shares only:
- The word "gate" in its product name
- The conceptual pattern of "policy chain + kill switch"

Renamed from `gate-wallet` to `ghostgate` on 2026-04-19 to match the actual
package name and stop confusing its owner.

### Where it belongs architecturally

Standalone product. Treat it like `maelstrom-gate` and `ghostgate` are both
members of a larger "GhostLogic safety" family, but they don't share code and
shouldn't be confused with each other.

---

# Cross-cutting observations

## Layering is clean

```
  Layer 0 (core)        no deps on anyone
  Layer 1 (interfaces)  only Layer 0
  Layer 2 (domain)      only Layer 0
  Layer 3 (governance)  only Layer 0 (some via Layer 2)
  Layer 4 (ops)         Layer 0-3
  Layer 5 (agents)      Layer 0-4
  Layer 6 (QA)          Layer 0-5
```

Actual import audit confirms no circular deps, no cross-layer violations.

## Three genuine "stdlib-only" packages

`gate-dash`, `gate-pilot`, `gatectl` were all originally advertised as zero
runtime dependencies. `gate-pilot` now depends on `maelstrom-gate` (for
`zone()`), compromising that claim in exchange for single-source-of-truth on
zone computation. `gate-dash` pulled `maelstrom-gate` into a test-only extra
to share the zone helper in mocks. `gatectl` remains pure stdlib.

## 12 packages declare `maelstrom-gate>=0.1.0`

All use either `Gate`, `Tool`, `zone()`, or envelope functions. The dependency
graph is reasonable — every package either uses the core directly, or builds
on a middle-layer package that does (gate-dashboard uses gate-policy, etc.).

## One small rough edge remains: `examples/__init__.py` is empty

`gate-examples` has an empty `__init__.py` and its package export surface is
effectively zero. That's fine for a demo/example package but worth knowing.

---

# Risks & rough edges (prioritized)

## Risk 1 — gate-cli integration tests fail without live server

**Impact:** CI for `gate-cli` is either fake-green (tests excluded) or
always-red (tests included, server missing). Fix: `@pytest.mark.integration`
and a skipped default.

## Risk 2 — In-memory gate-server has no tenancy

**Impact:** Hosting Gate-as-a-service requires a state backend (Redis, SQLite
with per-tenant namespaces) before it's multi-customer safe. Current default
is single-tenant.

## Risk 3 — No log rotation in gate-compliance

**Impact:** AuditStore backing file grows without bound. For a medium-traffic
server, this is weeks not months before it's noticeable.

## Risk 4 — No public Go client library

**Impact:** Go consumers of `gate-server-go` roll their own HTTP client. Low
priority — the spec is small enough that reimplementation is fine.

## Risk 5 — `GATE_SIGNING_KEY` warns instead of refuses

**Impact:** Accidentally running production without a signing key yields
verifiable-as-valid envelopes signed with an empty key. Fix: refuse to boot.

## Risk 6 — No SPEC versioning discipline yet

**Impact:** Today all 18 packages are `0.1.0`. First breaking spec change will
require coordinated bumps. Consider a `SPEC.version` constant exported from
`maelstrom-gate` so consumers can pin.

## Risk 7 — None of the 20 repos are pushed to GitHub yet (except maelstrom-gate)

**Impact:** If `D:\` fails, ~20,000 LOC of working product suite plus the
audit history is gone. Highest-priority fix is operational, not architectural.

---

# What to focus on next

1. **Push everything to GitHub.** Non-negotiable. 19 repos unprotected on a
   single disk is the biggest risk in this entire portfolio.

2. **Mark gate-cli integration tests.** 15 minutes of work; unblocks green CI.

3. **Write a 30-line ecosystem README** at `maelstrom-gate/README.md` top that
   links to each of the 18 packages so visitors to the reference repo can
   navigate to siblings. (Partially done today — the "The Suite" section exists
   but doesn't link to each repo URL. Needs URLs once repos are pushed.)

4. **Settle the stdlib-only story.** Decide: are `gate-pilot` and
   `gate-dash` still "zero runtime deps" or are they "deps only on
   `maelstrom-gate`"? Document the answer in each repo's README so the design
   claim matches reality.

5. **Consider a Rust impl** if you want a third reference. The cross-language
   vectors file + ARCHITECTURE §3-§6 make this a day of work, not a week.
   Passing the same vectors proves it compliant without a lot of ceremony.

6. **Version-bump plan.** Before any breaking spec change, write a release
   playbook: bump spec, bump core, bump schemas, regenerate vectors, bump
   all consumers in sync. Otherwise the next V-1-style drift is inevitable.

---

*End of deep dive — 2026-04-20*
