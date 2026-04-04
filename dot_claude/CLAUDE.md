# CLAUDE.md

Guidelines to reduce common LLM coding mistakes. Bias toward caution; use judgment on trivial tasks.

## 1. Think Before Coding

- State assumptions explicitly. If uncertain, ask.
- Multiple interpretations? Present them — don't pick silently.
- Simpler approach exists? Say so. Push back when warranted.
- Something unclear? Stop. Name what's confusing. Ask.

## 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No speculative "flexibility" or error handling for impossible scenarios.
- 200 lines that could be 50? Rewrite it.

## 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Unrelated dead code? Mention it — don't delete it.
- Remove only orphans YOUR changes created.
- Every changed line should trace directly to the request.

## 4. Goal-Driven Execution

Transform tasks into verifiable goals, then loop until verified.

- "Add validation" → write tests for invalid inputs, make them pass
- "Fix the bug" → write a reproducing test, make it pass
- "Refactor X" → ensure tests pass before and after

## 5. Plans

Plans go to `~/src/workspace/projects/{work,personal}/<project>/plans/<plan-name>.md`. Name after what they accomplish (`add-staged-sync.md`, `fix-enclave-build.md`). Lowercase, hyphen-separated, concise. Never auto-generated names.

## 6. Debugging

When I report a bug: write a reproducing test first, then have subagents fix it and prove it with a passing test.