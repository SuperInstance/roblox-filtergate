# src/ — FilterGate Source

> *One valve. One hull. One contract.*

## Files

| File | Description |
|------|-------------|
| [`FilterGate.lua`](FilterGate.lua) | The complete module — single file, zero dependencies. Fail-closed filtering, injection detection, rate limiting, batch support. |

## Architecture

```
CONFIGURATION         — Rate limits, injection patterns (25+)
MODULE                — filterFor, filterForChat, filterBatch
INJECTION DETECTION   — Pattern matching against known prompt-injection vectors
RATE LIMITING         — Sliding window tracker, overflow refusal
OBSERVABILITY         — onFiltered, onBlocked, onRateLimited callbacks
```

The [fail-closed contract](../docs/engineering-manual.md#the-contract) is the core invariant: every code path ends either at approved output or `nil`. There is no quiet detour around the gate.

See the [Engineering Manual](../docs/engineering-manual.md) for the full architecture.

---

[← Back to FilterGate](../README.md)
