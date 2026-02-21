# QA Staff Review — 2026-02-21

## Scope

Post-review validation pass for the three-tool overlay:
- Markdown
- JSON Formatter
- JSON Parse/Stringify

## What was validated

1. Build and launch lifecycle
- `swift build` succeeds.
- `swift run` launches and runs without crash.

2. Mode and preference wiring
- Default preferences and mode persistence are wired in `UserDefaults`.
- Tool mode and JSON transform sub-mode selectors are connected to processing pipeline updates.

3. Markdown pipeline
- Input changes trigger markdown rendering path to WKWebView.

4. JSON formatter pipeline
- Valid JSON: pretty-printed and key-sorted output.
- Invalid JSON: explicit error output.

5. JSON parse/stringify pipeline
- Parse mode: JSON string literal to parsed JSON.
- Stringify mode: JSON value/object to escaped JSON string literal.
- Error path includes both friendly guidance and underlying decode detail.

6. Tech-lead review follow-ups
- Focus returns to editor after mode changes.
- Input title constraint toggles correctly when parse/stringify control is hidden.

## Residual risk

- macOS UI automation checks (System Events / AppleScript) were blocked in this environment, so fully interactive visual checks still require manual desktop smoke.

## Outcome

- No blocking issues identified in this QA pass.
