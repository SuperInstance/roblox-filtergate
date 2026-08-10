# tests/ — FilterGate Test Suite

Tests run outside of Roblox Studio using the custom [TestKit](../testkit/init.lua) framework, which mocks `TextService`, `typeof()`, and `os.clock()`.

## Files

| File | Focus | Key Tests |
|------|-------|-----------|
| [`filtergate_test.lua`](./filtergate_test.lua) | Module structure, filtering, injection detection, rate limiting, chat filtering | Input validation, all injection patterns, rate limit enforcement, batch filtering, stats |
| [`filtergate_extended_test.lua`](./filtergate_extended_test.lua) | Exhaustive injection pattern coverage, rate limiter edge cases, batch edge cases, configuration, API completeness | All 25+ injection patterns individually tested, window expiry, disable flags, callback dispatch, reset behavior |

## Coverage

90 tests total. Key areas:

- ✅ All 25+ injection patterns (individually tested, case-insensitive)
- ✅ Rate limiter: enforcement, window pruning, disable toggle
- ✅ Input validation: nil, empty string, non-string, invalid UserId
- ✅ Batch filtering: mixed results, empty arrays, all-fail scenarios
- ✅ Chat vs. broadcast: correct TextService methods used
- ✅ Configuration: all options, callback dispatch via pcall
- ✅ Stats and reset: rate-limiter introspection
- ✅ API completeness: all exported functions verified

---

← Back to [FilterGate](../README.md)
