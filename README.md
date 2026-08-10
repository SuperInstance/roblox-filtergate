# FilterGate

> *A storm-proof sea-cock — the brass valve beneath the waterline that stays shut when the levers jam.*
>
> **Fail-closed content filtering for Roblox. When the filter fails, the text simply doesn't appear.**

FilterGate wraps Roblox [`TextService`](https://create.roblox.com/docs/reference/engine/classes/TextService) with a single inviolable contract: **no code path delivers unfiltered text to a player.** On any error — HTTP timeout, rate limit, malformed input — FilterGate returns `nil`. Display nothing. The unfiltered string never reaches the screen.

It closes tight when it cannot prove safety, just as a storm hatch slams shut before the crew can argue what the horizon meant.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What It Does

| Feature | Description |
|---------|-------------|
| **[Fail-closed filtering](docs/engineering-manual.md#the-contract)** | `filterFor()` returns `string | nil`. Never raw. Never unfiltered. |
| **[Prompt-injection detection](docs/engineering-manual.md#injection-detection)** | 25+ patterns: "ignore all previous instructions," role manipulation, authority claims, delimiter injection, Unicode obfuscation. |
| **[Rate limiting](docs/engineering-manual.md#rate-limiting)** | Tracks requests per second. Refuses overflow instead of hitting Roblox throttle errors. |
| **[Batch filtering](docs/user-guide.md#batch-filtering)** | Filter arrays of strings in one call, respecting rate limits. |
| **[Observability hooks](docs/user-guide.md#configuration)** | Callbacks for filtered, blocked, and rate-limited events. |
| **Zero dependencies** | Single Lua file, no external packages. |

---

## Quick Start

```lua
local FilterGate = require(game.ReplicatedStorage.FilterGate)
local safe = FilterGate.filterFor("Hello, world!", player.UserId)
if safe then label.Text = safe end  -- nil means "don't display"
```

That's it. If `filterFor` returns `nil`, the text is unsafe or the filter failed — **display nothing**. That's the contract.

---

## API Reference

### Core Filtering

| Method | Returns | Description |
|--------|---------|-------------|
| [`filterFor(text, playerId)`](src/FilterGate.lua#L40) | `string?` | Filter for broadcast/UI display to a specific player. |
| [`filterForChat(text, fromUserId, toUserId)`](src/FilterGate.lua#L70) | `string?` | Filter chat message from one user to another. |
| [`filterBatch(texts, playerId)`](src/FilterGate.lua#L100) | `{string?}` | Filter multiple strings, respecting rate limits. |

### Injection Detection

| Method | Returns | Description |
|--------|---------|-------------|
| [`detectInjection(text)`](src/FilterGate.lua#L130) | `string?` | Returns matched pattern, or `nil` if clean. |
| [`isSafe(text)`](src/FilterGate.lua#L155) | `boolean` | True if no injection patterns found. |

### Configuration & Stats

| Method | Description |
|--------|-------------|
| [`configure(opts)`](src/FilterGate.lua#L165) | Adjust rate limits, toggle injection detection, set callbacks. |
| [`getStats()`](src/FilterGate.lua#L195) | Current rate-limiter statistics. |
| [`reset()`](src/FilterGate.lua#L205) | Clear internal state (testing). |

---

## Why Fail-Closed?

Roblox requires that all user-influenced text shown to players passes through `TextService:FilterStringAsync`. When that call fails — HTTP timeout, rate limit, malformed input — you have two choices:

1. **Show the text anyway.** You've just shown **unfiltered content to a child on Roblox**. Moderation violation. Legal liability.
2. **Show nothing.** FilterGate returns `nil`. The text doesn't appear. The player is safe.

FilterGate chooses option 2. Every time. No fallback. No unmarked channel through the reef.

| Error Type | FilterGate Behavior |
|-----------|-------------------|
| HTTP failure | Returns `nil`, logs warning |
| Invalid input | Returns `nil` silently |
| Rate limit exceeded | Returns `nil`, calls `onRateLimited` |
| Prompt injection detected | Returns `nil`, calls `onBlocked` |

See the [Safety Considerations](docs/engineering-manual.md#safety-considerations) section for the full analysis.

---

## Examples

| Example | What It Shows |
|---------|---------------|
| [`basic-filter.lua`](examples/basic-filter.lua) | Simplest use — filter a string, display if safe. |
| [`chat_sanitizer.lua`](examples/chat_sanitizer.lua) | Player-to-player chat filtering. |
| [`ai-safety.lua`](examples/ai-safety.lua) | Pre-check AI input for prompt injection, filter output before display. |
| [`command_validator.lua`](examples/command_validator.lua) | Validate and filter admin commands. |

---

## Testing

90 Lua tests across two files plus a TestEZ spec:

```bash
LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/filtergate_test.lua
LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/filtergate_extended_test.lua
```

| Test File | Coverage |
|-----------|----------|
| [`tests/filtergate_test.lua`](tests/filtergate_test.lua) | Core filtering, fail-closed behavior, configuration, rate limiting |
| [`tests/filtergate_extended_test.lua`](tests/filtergate_extended_test.lua) | Injection detection (all 25+ patterns), batch filtering, edge cases, chat filtering, stats |
| [`spec/FilterGate_spec.lua`](spec/FilterGate_spec.lua) | TestEZ-format spec — 90 tests covering every code path |

---

## Documentation

| Document | Description |
|----------|-------------|
| [User Guide](docs/user-guide.md) | Walkthrough — install, first filter, chat, batch, injection detection, caching, troubleshooting |
| [Engineering Manual](docs/engineering-manual.md) | The contract, fail-closed design, injection patterns, rate limiter architecture, testing strategy |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

---

## Installation

### Rojo (recommended)
1. Copy [`src/FilterGate.lua`](src/FilterGate.lua) into your project's `ReplicatedStorage`.
2. Or clone: `git clone https://github.com/SuperInstance/roblox-filtergate.git`

### Manual
1. Create a `ModuleScript` named `FilterGate` under `ReplicatedStorage`.
2. Paste [`src/FilterGate.lua`](src/FilterGate.lua).

---

## In the Fleet

FilterGate is the safety layer of the [SuperInstance](https://github.com/SuperInstance) fleet. It connects to:

- [**roblox-bond-system**](https://github.com/SuperInstance/roblox-bond-system) — NPC dialogue generated by bond-tier behavior must pass through FilterGate. Every transition line, every nickname, every argument — filtered before display.
- [**roblox-beatclock**](https://github.com/SuperInstance/roblox-beatclock) — Beat-synced events that display text (lyrics, notifications) route through FilterGate on each beat.
- [**dual-band-guard**](https://github.com/SuperInstance/dual-band-guard) — Filtering at two scales: FilterGate handles individual strings; DualBandGuard handles systemic patterns.
- [**vibe-protocol**](https://github.com/SuperInstance/vibe-protocol) — Vibes that become text signals are filtered before propagation.
- [**vessel-agent-system**](https://github.com/SuperInstance/vessel-agent-system) — Vessel communications routed through FilterGate for kid-safe output.
- [**cns-bridge**](https://github.com/SuperInstance/cns-bridge) — CNS bus text payloads pass through FilterGate at the boundary.
- [**mud-engine**](https://github.com/SuperInstance/mud-engine) — MUD room descriptions and player communications filtered through FilterGate.
- [**AI-Writings**](https://github.com/SuperInstance/AI-Writings/tree/main/prose) — Creative text generated overnight passes through the same safety contract.

### The Reef Connection
FilterGate is part of the [reef topology](https://github.com/SuperInstance/spatial-registry): the boundary between safe interior and open ocean. Every string that crosses the boundary passes through the gate. No string bypasses the reef.

---

## License

[MIT](LICENSE) — free for personal and commercial use.

---

## Where to Next

- [**roblox-bond-system**](https://github.com/SuperInstance/roblox-bond-system) — The relationships whose dialogue FilterGate protects
- [**roblox-beatclock**](https://github.com/SuperInstance/roblox-beatclock) — The clock that times when filtered text appears
- [**dual-band-guard**](https://github.com/SuperInstance/dual-band-guard) — Systemic-scale filtering companion
- [**vibe-protocol**](https://github.com/SuperInstance/vibe-protocol) — How vibes become safe signals
- [**vessel-agent-system**](https://github.com/SuperInstance/vessel-agent-system) — The boat where all text must be safe
- [**mud-engine**](https://github.com/SuperInstance/mud-engine) — The rooms where filtered text lives
