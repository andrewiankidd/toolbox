---
name: debug-telemetry
description: Query Grafana Cloud (Loki logs, Tempo traces) to debug runtime issues in the downloadable/web game builds. Use this when the user reports bugs that only reproduce in shipped builds or on platforms you can't easily reproduce locally.
---

Query Grafana Cloud telemetry via HTTP API to investigate runtime bugs. The game ships with OpenTelemetry OTLP export enabled (Telemetry singleton), sending logs and traces to a Grafana Cloud stack.

## When to use this skill

- User reports a bug in a downloadable or web build ("NPCs don't spawn", "crashes on save", "blank screen on web")
- You need to see what actually happened at runtime, not just read code
- Reproducing locally would be slow, impossible (web-only), or platform-specific

Skip this skill for code-level bugs you can reason about by reading the source.

## Credentials

Config lives in `src/content/config/telemetry.yml`. The Grafana Cloud stack URL and a service account token are needed for queries. Read them with:

```bash
grep -E "^(endpoint|instance_id|api_key):" c:/git/TinnedSpaghetti/src/content/config/telemetry.yml
```

The Grafana instance URL is the OTLP endpoint's root (strip `/otlp`). For `tinnedspaghetti.grafana.net` it's `https://tinnedspaghetti.grafana.net`.

The service account token for API queries is stored in `.mcp.json` at the repo root (gitignored). Read it:

```bash
grep GRAFANA_SERVICE_ACCOUNT_TOKEN c:/git/TinnedSpaghetti/.mcp.json
```

## Datasource discovery

Every Grafana stack has auto-provisioned datasource UIDs. Discover them once per session:

```bash
TOKEN="glsa_..."
STACK="https://tinnedspaghetti.grafana.net"
curl -s -H "Authorization: Bearer $TOKEN" "$STACK/api/datasources" \
  | node -e "process.stdin.on('data',d=>JSON.parse(d).forEach(x=>console.log(x.type,x.uid)))"
```

The UIDs you care about:
- **Loki (logs)**: `grafanacloud-logs`
- **Tempo (traces)**: `grafanacloud-traces`

## Querying Loki logs

All log queries go through the datasource proxy endpoint:

```
$STACK/api/datasources/proxy/uid/grafanacloud-logs/loki/api/v1/query_range
```

**Required parameters** (nanosecond timestamps):
- `query` — LogQL expression
- `start`, `end` — nanoseconds since epoch (milliseconds × 1000000)
- `limit` — max lines

**Time range helper** (last hour):
```bash
NOW=$(date +%s)000
FROM=$((NOW - 3600000))
START_NS="${FROM}000000"
END_NS="${NOW}000000"
```

### Common queries

**All logs from town-spirit in the last hour:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -G "$STACK/api/datasources/proxy/uid/grafanacloud-logs/loki/api/v1/query_range" \
  --data-urlencode 'query={service_name="town-spirit"}' \
  --data-urlencode "start=$START_NS" --data-urlencode "end=$END_NS" \
  --data-urlencode "limit=500"
```

**Errors and warnings only:**
```bash
--data-urlencode 'query={service_name="town-spirit", severity_text=~"ERROR|WARN"}'
```

**Search by keyword (NPC, spawn, population, etc.):**
```bash
--data-urlencode 'query={service_name="town-spirit"} |~ "(?i)npc|population|spawn|bot"'
```

**Filter by platform (desktop/web/mobile):**
```bash
--data-urlencode 'query={service_name="town-spirit", platform="web"}'
```

**Specific player session (from user crash report):**
```bash
--data-urlencode 'query={service_name="town-spirit", session_id="b0ab2e4ba4a5c01a"}'
```

### Parsing the response

Loki returns `{status, data: {result: [streams]}}`. Each stream has `stream` (labels) and `values` (array of `[nanos, line]` tuples). Use node to flatten:

```bash
| node -e "
process.stdin.on('data',d=>{
  const j=JSON.parse(d);
  const streams = j.data?.result || [];
  const all = [];
  streams.forEach(s=>s.values.forEach(v=>all.push({
    t: parseInt(v[0]),
    platform: s.stream.platform,
    sev: s.stream.severity_text,
    msg: v[1]
  })));
  all.sort((a,b)=>a.t-b.t);
  console.log('Total lines:', all.length);
  all.forEach(e=>console.log('['+e.platform+' '+e.sev+']', e.msg.substring(0,200)));
})"
```

## Querying Tempo traces

Trace queries use TraceQL. The endpoint pattern is:
```
$STACK/api/datasources/proxy/uid/grafanacloud-traces/api/search
```

**Find all spans for a span name:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  -G "$STACK/api/datasources/proxy/uid/grafanacloud-traces/api/search" \
  --data-urlencode 'q={ name = "world.generate" }' \
  --data-urlencode "start=$((FROM / 1000))" --data-urlencode "end=$((NOW / 1000))" \
  --data-urlencode "limit=50"
```

**Find errored spans:**
```bash
--data-urlencode 'q={ status = error }'
```

**Find slow operations:**
```bash
--data-urlencode 'q={ duration > 5s }'
```

### Known trace spans (see `src/globals/telemetry.gd` callers)

- `world.generate` — attrs: `world.seed`, `world.radius`, `world.detail`
- `save.write` — attrs: `save.id`, `save.structures`, `save.objects`
- `save.load` — attrs: `save.id`

## Project-specific resource attributes

Every log record carries these labels (searchable in Loki):
- `service_name` = `town-spirit`
- `service_version` — from game build
- `session_id` — unique per game launch (16 hex chars)
- `platform` — `desktop` / `web` / `mobile`
- `os_type`, `os_description`, `device_model`
- `severity_text` — `ERROR` / `WARN` / `INFO` / `DEBUG`

Use these in LogQL stream selectors for fast filtering — they're indexed.

## Debugging workflow

1. **Read the bug report carefully.** Note: platform, what broke, what the user expected, any timing details.
2. **Start broad**: query for the last hour on the relevant platform. Count lines, skim for errors.
3. **Narrow by keyword**: search for terms related to the broken subsystem.
4. **Look for the session**: if the user ran the game once to repro, find their `session_id` from any matching line and filter by it to isolate their playthrough.
5. **Correlate with traces**: for timing/perf bugs, look at Tempo spans. For logic bugs, logs are usually enough.
6. **Confirm the hypothesis**: once you have a theory, grep the source at the line numbers in the log messages to verify.
7. **Report findings to the user** before making code changes. Quote specific log lines.

## Rules

- Never paste the service account token into conversation — it's stored in `.mcp.json` which is gitignored for a reason. Read it from the file, use it in curl, don't echo it.
- Loki retention is limited on the free tier — don't assume old bugs will have logs available. Query within the last 24 hours for reliability.
- If the query returns zero results, check: is telemetry enabled in the config? Did the user run the version of the build that had telemetry? Is `session_id` filter correct?
- If you see logs from an unexpected session_id, ask the user to confirm which session matches their bug report — multiple sessions may be in the same time window.
