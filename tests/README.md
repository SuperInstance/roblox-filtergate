# tests/ — FilterGate Test Suite

> *Sea trials. Every valve pressured, every seal verified.*

## Test Files

| File | Framework | Coverage |
|------|-----------|----------|
| [`filtergate_test.lua`](filtergate_test.lua) | [TestKit](../testkit/init.lua) | Core filtering, fail-closed behavior, configuration, rate limiting |
| [`filtergate_extended_test.lua`](filtergate_extended_test.lua) | [TestKit](../testkit/init.lua) | All 25+ injection patterns, batch filtering, edge cases, chat filtering, stats, API completeness |

## Running Tests

```bash
LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/filtergate_test.lua
LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/filtergate_extended_test.lua
```

## Key Test Categories

- **Fail-closed verification** — every error path returns `nil`, never raw text
- **Injection detection** — all 25+ patterns matched, including Unicode obfuscation
- **Rate limiting** — overflow returns `nil` without hitting Roblox throttles
- **Batch filtering** — arrays filtered in sequence, rate limits respected
- **Configuration** — `configure()` properly adjusts all settings

See also: [`spec/FilterGate_spec.lua`](../spec/FilterGate_spec.lua) for the TestEZ-format spec.

---

[← Back to FilterGate](../README.md)
