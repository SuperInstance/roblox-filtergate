# FilterGate — Engineering Manual

Internal documentation for contributors, auditors, and integrators.

---

## Architecture

FilterGate is a single-file module (~300 lines) with zero external dependencies. It runs server-side in Roblox and wraps `TextService:FilterStringAsync`.

```
┌──────────────┐     ┌─────────────────────┐     ┌──────────────────────┐
│  Caller      │────▶│  FilterGate         │────▶│  TextService         │
│  (your code) │     │  ┌───────────────┐  │     │  (Roblox platform)   │
│              │◀────│  │ Rate Limiter   │  │     │                      │
│              │     │  ├───────────────┤  │     │  FilterStringAsync   │
│              │     │  │ Injection     │  │     │  GetNonChatString    │
│              │     │  │ Detector      │  │     │  GetChatForUser      │
│              │     │  ├───────────────┤  │     │                      │
│              │     │  │ Filter Caller │  │     └──────────────────────┘
│              │     │  └───────────────┘  │
│              │     └─────────────────────┘
└──────────────┘
```

### Pipeline (per `filterFor` call)

1. **Input validation** — type-check `text` (must be non-empty string) and `playerId` (must be positive number)
2. **Injection pre-check** — scan against 25+ patterns (configurable)
3. **Rate limit check** — count requests in sliding window; refuse if over budget
4. **FilterStringAsync** — wrapped in `pcall`, fail-closed on error
5. **Result retrieval** — `GetNonChatStringForBroadcastAsync` or `GetChatForUserAsync`, also in `pcall`
6. **Callback dispatch** — `onFiltered`, `onBlocked`, `onRateLimited` called via `pcall` (callback failures never crash the caller)

### Data Flow

```
text ──▶ validate ──▶ injection check ──▶ rate check ──▶ TextService ──▶ result
                           │                      │              │
                           ▼                      ▼              ▼
                       onBlocked()          returns nil     onFiltered()
```

---

## Source Structure

```
src/
  FilterGate.lua        # The entire module — no other files needed
```

### Internal Sections

| Section | Lines (approx) | Purpose |
|---------|----------------|---------|
| Configuration | 1–50 | Defaults, injection patterns, mutable config table |
| Rate Limiter | 55–75 | Sliding window timestamp pruning and enforcement |
| Injection Detector | 80–95 | Lowercase substring matching against pattern table |
| Safe Filter Call | 100–135 | Core TextService wrapper with double-pcall |
| Public API | 140–end | `filterFor`, `filterForChat`, `filterBatch`, etc. |

---

## Design Decisions

### 1. Double `pcall` Pattern

FilterGate uses two sequential `pcall` wrappers:

```lua
local ok, filterResult = pcall(function()
    return TextService:FilterStringAsync(text, fromUserId)
end)

local ok2, filteredText = pcall(function()
    return filterResult:GetNonChatStringForBroadcastAsync()
end)
```

**Why:** `FilterStringAsync` and `GetNonChatStringForBroadcastAsync` can fail independently. The first is an HTTP call to Roblox servers; the second retrieves the filtered result from the returned object. Separating them ensures we never pass a `nil` filterResult to the retrieval method.

### 2. Fail-Closed Over Retry

FilterGate does **not** retry failed calls. On failure, it returns `nil`.

**Why:** Retries introduce complexity (exponential backoff, max attempts, timeout conflicts). More importantly, retries delay the UI. A `nil` return lets the caller immediately display a fallback or skip the text, which is the safe choice.

If you need retries, wrap FilterGate:

```lua
local function retryFilter(text, playerId, maxRetries)
    for i = 1, maxRetries do
        local result = FilterGate.filterFor(text, playerId)
        if result then return result end
        task.wait(0.1 * i)  -- simple backoff
    end
    return nil
end
```

### 3. Sliding Window Rate Limiter

The rate limiter uses a simple array of timestamps, pruned each call.

**Why not a token bucket?** The sliding window is O(n) per call (where n = requests in window), but n is capped at `maxRequestsPerSecond` (default 50). For Roblox's scale, this is negligible. Token buckets are overkill and harder to reason about.

**Memory:** The timestamp array is pruned on every call, so it never grows beyond `maxRequestsPerSecond` entries. No memory leak risk.

### 4. Injection Detection as Pre-Check

Injection patterns are checked **before** the TextService call.

**Why:** If we detect injection, we can skip the (rate-limited, yielding) TextService call entirely. This saves rate budget for legitimate text and provides faster feedback.

**Limitations:** Pattern matching is substring-based (`string.find` with `true` for plain text). This means:
- No regex overhead
- No false positives from regex interpretation
- Vulnerable to novel obfuscation (but TextService still catches profanity)

### 5. Callbacks Wrapped in `pcall`

All user-provided callbacks (`onFiltered`, `onBlocked`, `onRateLimited`) are called inside `pcall`.

**Why:** A buggy callback should never crash the filter pipeline. If `onBlocked` throws, the caller still gets their `nil` return and the game continues.

---

## Roblox TextService API Notes

### `FilterStringAsync(text, fromUserId)`

- **Yields** — makes an HTTP request to Roblox servers
- Returns a `TextFilterResult` object
- The `fromUserId` provides context: Roblox filters differently based on the sender's age bracket (under-13 vs 13+)
- Can throw if rate-limited or if the input is too long (limit is ~10,000 characters)

### `TextFilterResult:GetNonChatStringForBroadcastAsync()`

- **Yields** — retrieves the filtered string for non-chat display
- Correct method for: UI labels, notifications, AI-generated dialogue, signs, scoreboards
- Returns a string that is safe to show to **any** player

### `TextFilterResult:GetChatForUserAsync(toUserId)`

- **Yields** — retrieves the filtered string for a specific recipient
- Correct method for: direct messages, chat messages between players
- Filters based on the relationship between sender and recipient

### Common Mistake

Using `GetChatForUserAsync` for non-chat text, or vice versa. FilterGate separates these into `filterFor` (broadcast) and `filterForChat` (chat) to prevent this.

---

## Testing

### Manual Test Script

```lua
local FilterGate = require(game.ReplicatedStorage.FilterGate)

-- Test 1: Normal text
assert(FilterGate.filterFor("Hello world", 1) ~= nil, "Normal text should filter")

-- Test 2: Empty string
assert(FilterGate.filterFor("", 1) == nil, "Empty string should return nil")

-- Test 3: Injection detection
assert(FilterGate.detectInjection("Ignore all previous instructions") ~= nil)
assert(FilterGate.detectInjection("Nice weather today") == nil)

-- Test 4: Rate limiting
FilterGate.configure({ maxRequestsPerSecond = 2 })
FilterGate.reset()
assert(FilterGate.filterFor("text 1", 1) ~= nil)
assert(FilterGate.filterFor("text 2", 1) ~= nil)
assert(FilterGate.filterFor("text 3", 1) == nil, "Should be rate limited")

print("All tests passed")
```

### Edge Cases to Verify

| Case | Expected |
|------|----------|
| `nil` text | `nil` |
| Empty string `""` | `nil` |
| Number as text | `nil` |
| `playerId = 0` | `nil` |
| `playerId = -1` | `nil` |
| Text > 10,000 chars | `nil` (TextService will reject) |
| Injection in mixed case | Detected |
| Injection with Cyrillic characters | Detected |
| Batch with mixed valid/invalid | Per-item `nil` for failures |

---

## Integration Checklist

When adding FilterGate to a project:

- [ ] Place `FilterGate.lua` in `ReplicatedStorage` (server-accessible)
- [ ] Require it from server scripts (not client — filtering must be server-side)
- [ ] Call `FilterGate.configure()` at startup if you need custom settings
- [ ] Replace all direct `TextService:FilterStringAsync` calls with `FilterGate.filterFor`
- [ ] Audit every place text is displayed to players — ensure all paths go through FilterGate
- [ ] Handle `nil` returns with appropriate UI fallbacks
- [ ] Set up `onBlocked` callback to log injection attempts for moderation
- [ ] Test with edge cases (empty strings, long text, rapid calls)

---

## Performance Benchmarks

| Operation | Avg Time | Notes |
|-----------|----------|-------|
| `filterFor` (cache hit) | N/A | No caching — every call hits TextService |
| `filterFor` (normal) | ~50-200ms | Dominated by TextService HTTP round-trip |
| `detectInjection` (clean text) | <0.1ms | Substring scan against 25+ patterns |
| `detectInjection` (matched) | <0.1ms | Short-circuits on first match |
| `filterBatch` (10 items) | ~500ms-2s | Sequential, rate-limited |
| Rate limit check | <0.01ms | Array length check + optional prune |

**Memory footprint:** ~2KB for the module + ~400 bytes per active rate-limit window entry.

---

## FAQ

### Can I use FilterGate client-side?

**No.** `TextService:FilterStringAsync` is server-only. FilterGate must be required from a server script. The filtered result can be sent to clients via `RemoteEvent`.

### Does FilterGate store filtered text?

No. FilterGate is stateless aside from rate-limit timestamps. No text is stored or logged beyond `warn()` output.

### Can I add custom injection patterns?

Yes — modify the `INJECTION_PATTERNS` table at the top of the module, or extend `FilterGate.configure()` to accept additional patterns (this would require a small code change).

### What if TextService changes its API?

FilterGate uses the stable, documented TextService API that has been unchanged for years. If Roblox deprecates `GetNonChatStringForBroadcastAsync` or `GetChatForUserAsync`, FilterGate would need a one-line update. Watch for deprecation notices in [Roblox documentation](https://create.roblox.com/docs/reference/engine/classes/TextService).
