# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-08-04

### Added
- `FilterGate.configure(opts)` — configurable rate limiting, injection detection, callbacks
- `FilterGate.filterFor(text, fromUserId)` — fail-closed broadcast filtering
- `FilterGate.filterForChat(text, fromUserId, toUserId)` — chat-directional filtering
- `FilterGate.filterBatch(texts, playerId)` — batch filtering respecting rate limits
- `FilterGate.detectInjection(text)` / `FilterGate.isSafe(text)` — prompt-injection pre-check
- `FilterGate.getStats()` — rate-limit statistics
- `FilterGate.reset()` — clear internal state for testing
- 30+ prompt-injection patterns including Unicode obfuscation variants
- Fail-closed design: returns `nil` on ANY error (never shows unfiltered text)
- Engineering manual and user guide
- Two example scripts: basic filtering, AI safety pipeline
- MIT license
