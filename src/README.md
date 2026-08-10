# src/ — FilterGate Source

The entire module is a single file: [`FilterGate.lua`](./FilterGate.lua).

~300 lines of Luau. Zero external dependencies. Server-side only.

## Architecture

```
src/
  FilterGate.lua        # The entire module — no other files needed
```

### Internal Sections

| Section | Purpose |
|---------|---------|
| Configuration | Defaults, 25+ injection patterns, mutable config table |
| Rate Limiter | Sliding window timestamp pruning and enforcement |
| Injection Detector | Lowercase substring matching against pattern table |
| Safe Filter Call | Core TextService wrapper with double-pcall |
| Public API | `filterFor`, `filterForChat`, `filterBatch`, `detectInjection`, `isSafe`, `configure`, `getStats`, `reset` |

## The Pipeline

```
text ──▶ validate ──▶ injection check ──▶ rate check ──▶ TextService ──▶ result
                           │                      │              │
                           ▼                      ▼              ▼
                       onBlocked()          returns nil     onFiltered()
```

Every step can short-circuit to `nil`. No step can bypass to raw text.

## Key Design Decisions

1. **Double-pcall** — `FilterStringAsync` and `GetNonChatStringForBroadcastAsync` fail independently; separate pcalls handle each
2. **Fail-closed, not retry** — no exponential backoff; on failure, return `nil` immediately
3. **Sliding window rate limiter** — O(n) per call, but n capped at 50; simpler than token bucket
4. **Injection as pre-check** — pattern matching before TextService saves rate budget for legitimate text
5. **Callbacks in pcall** — buggy user callbacks never crash the filter pipeline

---

← Back to [FilterGate](../README.md)
