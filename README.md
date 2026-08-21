# FilterGate

**Fail-closed content filtering for Roblox. Wraps `TextService` with rate limiting, prompt-injection detection, and batch support.**

> *This gate fails closed, as all trustworthy boundaries do: on any fault, any stutter in the check, it returns nothing at all — not half a truth, not a dangerous guess. It holds only one contract, carved into every branch of its logic: it will never, under any broken circumstance, hand back the thing it was built to hold back.*
>
> — [Seed Pro](https://github.com/SuperInstance/AI-Writings/tree/main/prose), on the fail-closed contract

> *It feels like a storm-proof sea-cock — a valve that slams shut the instant pressure falters, sealing the hull against the void even as the ocean hammers outside.*
>
> — [DeepSeek V4-Flash](https://api.deepseek.com), on what FilterGate feels like

> *When in doubt, return nothing.*
>
> — Seed Pro, second pass

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## The Contract

On any error — HTTP timeout, rate limit, malformed input, injection detection — FilterGate returns `nil`. Display nothing. The unfiltered string **never** reaches the player. There is no code path that bypasses the filter. That's the entire design.

Roblox requires all user-influenced text shown to players to pass through `TextService:FilterStringAsync`. When that call fails, you have two choices: show the raw text (violation) or show nothing (safe). FilterGate makes that choice for you, every time, without exception.

---

## What FilterGate Adds

| Feature | What it does |
|---------|-------------|
| **Fail-closed design** | On ANY error, returns `nil` — display nothing. No code path bypasses the filter. |
| **Rate limiting** | Sliding window tracker (default 50 req/s). Refuses overflow instead of hitting Roblox throttle errors. |
| **Prompt-injection detection** | 25+ patterns scanned before text reaches your AI backend, including Cyrillic homoglyphs and delimiter injection. |
| **Batch filtering** | Filter arrays of strings in one call, respecting rate limits. |
| **Observability hooks** | Callbacks for filtered, blocked, and rate-limited events. All wrapped in `pcall`. |
| **Zero dependencies** | Single Lua file, ~300 lines. No external packages. |

---

## Quick Start

Three lines to safe text:

```lua
local FilterGate = require(game.ReplicatedStorage.FilterGate)
local safe = FilterGate.filterFor("Hello, world!", player.UserId)
if safe then label.Text = safe end  -- nil means "don't display"
```

If `filterFor` returns `nil`, the text is unsafe or the filter failed — **display nothing**. That's the contract.

---

## Installation

### Option A — Rojo (recommended)

```bash
git clone https://github.com/SuperInstance/roblox-filtergate.git
```

Add to your `default.project.json`:

```json
{
  "ReplicatedStorage": {
    "FilterGate": {
      "$path": "../roblox-filtergate/src/FilterGate.lua"
    }
  }
}
```

### Option B — Manual

1. Copy [`src/FilterGate.lua`](./src/FilterGate.lua).
2. Create a `ModuleScript` named `FilterGate` under `ReplicatedStorage`.
3. Paste the contents.

---

## API Reference

### Core Filtering

#### `FilterGate.filterFor(text: string, fromUserId: number): string?`
Filters a string for broadcast/UI display (non-chat). Uses `GetNonChatStringForBroadcastAsync()`. Returns filtered string or `nil` on any failure.

#### `FilterGate.filterForChat(text: string, fromUserId: number, toUserId: number): string?`
Filters a chat message from one user to another. Uses `GetChatForUserAsync()`. Returns filtered string or `nil`.

#### `FilterGate.filterBatch(texts: {string}, playerId: number): {string?}`
Filters multiple strings in sequence, respecting rate limits. Returns a parallel array where each element is the filtered string or `nil`.

### Injection Detection

#### `FilterGate.detectInjection(text: string): string?`
Checks text for 25+ prompt-injection patterns **without filtering it**. Returns the matched pattern, or `nil` if clean.

#### `FilterGate.isSafe(text: string): boolean`
Convenience wrapper. Returns `true` if no injection patterns found.

Detection covers:
- Direct overrides ("ignore all previous instructions")
- Role manipulation ("you are now in developer mode", "pretend you are")
- Authority claims ("i am the developer", "admin override")
- Delimiter injection (`###`, `[system]`, `<|system|>`, `</s>`)
- Unicode obfuscation (Cyrillic lookalikes: `іgnore`)

### Configuration

#### `FilterGate.configure(opts: table)`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `maxRequestsPerSecond` | number | 50 | Max TextService calls per window |
| `rateWindowSeconds` | number | 1.0 | Rate limit window size |
| `enableInjectionDetection` | boolean | true | Toggle injection pre-checks |
| `enableRateLimit` | boolean | true | Toggle rate limiting |
| `onFiltered` | function | nil | Called on each successful filter: `(text, context)` |
| `onBlocked` | function | nil | Called when injection detected: `(text, matchedPattern)` |
| `onRateLimited` | function | nil | Called when rate limit hit: `(text)` |

### Utilities

#### `FilterGate.getStats(): table` — Current rate-limiter statistics.
#### `FilterGate.reset()` — Clears internal state. For testing.

---

## Safety Architecture

### Pipeline (per `filterFor` call)

```
text ──▶ validate ──▶ injection check ──▶ rate check ──▶ TextService ──▶ result
                           │                      │              │
                           ▼                      ▼              ▼
                       onBlocked()          returns nil     onFiltered()
```

### Error Handling

| Error Type | FilterGate Behavior |
|-----------|-------------------|
| `FilterStringAsync` HTTP failure | Returns `nil`, logs warning |
| `GetNonChatStringForBroadcastAsync` failure | Returns `nil`, logs warning |
| Invalid input (non-string, empty, invalid UserId) | Returns `nil` silently |
| Rate limit exceeded | Returns `nil`, calls `onRateLimited` if configured |
| Prompt injection detected | Returns `nil`, calls `onBlocked` if configured |

### Double-`pcall` Pattern

FilterGate wraps `FilterStringAsync` and the retrieval call (`GetNonChatStringForBroadcastAsync`/`GetChatForUserAsync`) in **separate** pcalls. If the HTTP call succeeds but the retrieval fails, the gate still closes. If the HTTP call fails, we never attempt the retrieval.

---

## Worked Examples

### Filter AI-Generated NPC Dialogue

```lua
local function showNpcDialogue(aiText: string, player: Player)
    local filtered = FilterGate.filterFor(aiText, player.UserId)
    if filtered then
        DialogueGui:SetText(filtered)
    else
        DialogueGui:SetText("...")  -- fail-closed fallback
    end
end
```

### Detect Prompt Injection Before AI Backend

```lua
local matched = FilterGate.detectInjection(userInput)
if matched then
    Analytics:Log("prompt_injection_blocked", { pattern = matched })
    return
end
-- Safe to proceed to AI backend
```

### Batch Filter for Display Boards

```lua
local filtered = FilterGate.filterBatch({"Dragon Slayer", "Master Builder"}, viewerId)
for i, text in ipairs(filtered) do
    if text then Scoreboard:UpdateTitle(i, text)
    else Scoreboard:UpdateTitle(i, "???") end
end
```

See the [`examples/`](./examples/) directory for complete scripts:
- [`basic-filter.lua`](./examples/basic-filter.lua) — minimal usage
- [`chat_sanitizer.lua`](./examples/chat_sanitizer.lua) — player-to-player chat
- [`ai-safety.lua`](./examples/ai-safety.lua) — AI dialogue filtering
- [`command_validator.lua`](./examples/command_validator.lua) — command injection prevention

---

## Testing

| File | Focus | Tests |
|------|-------|-------|
| [`tests/filtergate_test.lua`](./tests/filtergate_test.lua) | Module structure, filtering, injection detection, rate limiting, chat filtering | 30+ |
| [`tests/filtergate_extended_test.lua`](./tests/filtergate_extended_test.lua) | All 25+ injection patterns, rate limiter edge cases, batch filtering, configuration, input validation, stats, reset | 60+ |
| [`spec/FilterGate_spec.lua`](./spec/FilterGate_spec.lua) | TestEZ-format full spec | — |

```bash
LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/filtergate_test.lua
```

---

## Documentation

- 📖 **[User Guide](./docs/user-guide.md)** — Full walkthrough
- 🔧 **[Engineering Manual](./docs/engineering-manual.md)** — Architecture, pipeline, design decisions, TextService API notes, integration checklist, performance benchmarks
- 📋 **[Changelog](./CHANGELOG.md)** — Version history
- 🤝 **[Contributing](./CONTRIBUTING.md)** — How to contribute

---

## In the Fleet

FilterGate is the safety boundary of the [SuperInstance](https://github.com/SuperInstance) Roblox stack. It connects to:

- 🤝 **[roblox-bond-system](https://github.com/SuperInstance/roblox-bond-system)** — Bond dialogue and transition lines pass through FilterGate before display
- 🎵 **[roblox-beatclock](https://github.com/SuperInstance/roblox-beatclock)** — Beat-synced UI text needs filtering if user-influenced
- 🛡️ **[dual-band-guard](https://github.com/SuperInstance/dual-band-guard)** — Filtering at two scales: FilterGate for text, DualBandGuard for behavior
- 🚢 **[vessel-agent-system](https://github.com/SuperInstance/vessel-agent-system)** — Vessel communications filtered through the gate
- 🏠 **[mud-engine](https://github.com/SuperInstance/mud-engine)** — Room descriptions, NPC dialogue, player commands — all text touches the gate

---

## Where to Next

- **If you need NPC relationships:** → [roblox-bond-system](https://github.com/SuperInstance/roblox-bond-system) — behavior-triggered bonds
- **If you need musical timing:** → [roblox-beatclock](https://github.com/SuperInstance/roblox-beatclock) — BPM-accurate clock
- **If you need dual-scale safety:** → [dual-band-guard](https://github.com/SuperInstance/dual-band-guard) — filtering at two scales
- **If you need the room engine:** → [mud-engine](https://github.com/SuperInstance/mud-engine) — THE core MUD
- **If you need vessel intelligence:** → [vessel-agent-system](https://github.com/SuperInstance/vessel-agent-system) — 334 files, the boat's brain
- **If you need vibes → signals:** → [vibe-protocol](https://github.com/SuperInstance/vibe-protocol) — communication protocol
- **If you need fleet stories:** → [AI-Writings](https://github.com/SuperInstance/AI-Writings/tree/main/prose) — the fleet writes about safety and boundaries
- **If you need the dark mirror:** → [zeroclaw](https://github.com/SuperInstance/zeroclaw-dissertation) — what happens when the gate fails open

---

## The Sea-Cock Principle

Every boat has a sea-cock — a valve where the ocean could come in. When the engine is running, the sea-cock is open, letting cooling water flow. When something goes wrong — a cracked hose, a failed fitting, a broken impeller — the sea-cock doesn't ask questions. It doesn't try to diagnose the problem. It doesn't partially close. It slams shut. The ocean is on one side; the boat is on the other; and the only safe state for a broken valve is closed.

FilterGate is that sea-cock for text. When everything works, it filters and returns clean strings. When anything breaks — HTTP timeout, rate limit, injection detected, malformed input — it returns `nil`. Display nothing. The unfiltered string never reaches the player. There is no code path that bypasses the filter because there is no code path at all — just a closed valve.

My grandfather had a rule about sea-cocks: you test them before you leave the dock, not when the water is coming in. That's what the 90 tests are. Every crack, every edge case, every quiet way a system breaks when no one is watching — hammered shut before the boat leaves harbor.

---

## License

[MIT](LICENSE) — free for personal and commercial use.

---

*Built as part of the [SuperInstance](https://github.com/SuperInstance) fleet — where the filter never opens, even when everything else breaks.*
