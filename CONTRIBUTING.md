# Contributing to FilterGate

Thanks for your interest in FilterGate!

## Getting Started

1. **Fork & clone** the repo
2. Install [Rojo](https://rojo.space) for Studio sync
3. Run `rojo serve` to test in Studio

## Development Workflow

```bash
rojo serve
```

### Running Tests

Tests live in `spec/` and use [TestEZ](https://github.com/Roblox/testez) format.

### Code Style

- **Luau type annotations** on all public functions
- **Doc comments** on all exported APIs
- **camelCase** for functions
- **Fail-closed design**: on ANY error, return `nil` (display nothing). Never return unfiltered text.
- All `pcall` wrapping around `TextService` calls must stay — Roblox APIs fail

## Core Principle: Fail-Closed

FilterGate's contract is absolute: **never return unfiltered text**. If the filter breaks, the string doesn't show. This is a Roblox moderation requirement, not a preference.

When contributing:
- Never add a code path that returns the raw input on error
- Never swallow errors silently — `warn()` them so developers can diagnose
- Rate limit overflow returns `nil`, not the original text

## Adding Injection Patterns

New prompt-injection patterns go in the `INJECTION_PATTERNS` table. Use lowercase strings. The matcher does a literal substring search (`string.find` with `plain=true`), so include common Unicode/obfuscation variants.

## Submitting Changes

1. Feature branch: `git checkout -b feat/your-feature`
2. Test nil inputs, empty strings, Unicode, and rate-limit overflow
3. Open a PR with a clear description

## Reporting Bugs

Include:
- The input string (or a description if sensitive)
- The UserId passed
- Whether injection detection caught it
- The error reason returned

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
