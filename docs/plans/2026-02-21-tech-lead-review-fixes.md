# Tech Lead Review Fixes — 2026-02-21

## Scope

Follow-up patch to address review findings on the new multi-tool JSON workflows.

## Fixes applied

1. Editor focus restored after mode changes
- After switching tool mode or parse/stringify sub-mode, focus returns to the editor input.
- Prevents keyboard focus getting stuck on segmented controls.

2. Input title constraint behavior corrected
- Added alternate trailing constraints for input-card title.
- When parse/stringify control is hidden, title now expands to card trailing edge.
- Prevents unnecessary truncation in Markdown and JSON formatter modes.

3. Parse error diagnostics improved
- JSON string-literal parse errors now include underlying decode details.
- Keeps a friendly top-line hint while preserving actionable specifics.

## Files changed

- `MarkdownFloat/Sources/OverlayViewController.swift`

## Validation

- `swift build` passes after patch.
