# Checkpoint — 2026-02-20

## Summary

Floating Markdown overlay is now in a stable, polished state:

- Persistent width/layout issue resolved.
- Overlay is resizable with minimum bounds.
- Header now includes:
  - Auto-paste toggle (default OFF)
  - Split toggle with icon segments (default horizontal / left-right)
  - Subtle close control (now top-left)
- Editor supports expected command-key behavior (including Select All / `Cmd+A`).
- Preview styling updated toward GitHub-equivalent markdown rendering.
- Visual polish pass completed for a cleaner ChatGPT/Apple-inspired appearance:
  - softer glass materials
  - slightly translucent panel
  - refined card/chip/control chrome

## Validation

- `swift build` passes.
- Runtime smoke checks completed during iterative `swift run` sessions.

## Files in this checkpoint

- `MarkdownFloat/Sources/OverlayViewController.swift`
- `MarkdownFloat/Sources/OverlayPanel.swift`
- `MarkdownFloat/Resources/markdown-template.html`

## Next milestone

Extend the app into a multi-tool popup with additional tabs/modes:

1. JSON Formatter / Prettifier
   - Left: raw JSON
   - Right: prettified JSON
   - Include parse/validation error surfacing.

2. JSON Parse/Stringify Utility
   - Parse JSON string values into objects
   - Stringify JSON objects back into escaped JSON strings
   - Clear mode semantics and examples in placeholder text.
