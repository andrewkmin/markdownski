# Text Search Feature Design

## Summary

Add find-in-document text search to the overlay panel using native macOS `NSTextFinder` infrastructure.

## Approach

Use Apple's built-in `NSTextFinder` system rather than a custom search UI. This provides a transient find bar that appears at the top of each scroll view on Cmd+F, with highlighting, match counting, next/previous navigation (Cmd+G / Cmd+Shift+G), and full VoiceOver support.

### Scope

- **Editor text view (NSTextView, editable):** Enable `usesFindBar` and `isIncrementalSearchingEnabled`
- **Output text view (NSTextView, readonly, JSON modes):** Same — `usesFindBar` and `isIncrementalSearchingEnabled`
- **Preview WebView (WKWebView, markdown mode):** Enable `isFindInteractionEnabled` (macOS 13+)
- **Trigger:** Cmd+F in `EditorTextView.performKeyEquivalent`, scoped to whichever pane has focus

### What we are NOT building

- No always-visible search field in the header (violates HIG for find-in-document)
- No custom highlighting code (NSTextFinder handles this)
- No cross-pane unified search (search is scoped to focused pane)

## UI Behavior

1. User presses Cmd+F while editor has focus → find bar slides in at top of editor's NSScrollView
2. User types query → matches highlighted incrementally, count shown in find bar
3. Cmd+G / Cmd+Shift+G cycles through matches
4. Escape dismisses the find bar
5. Same behavior in output text view (JSON modes) and WKWebView (markdown preview)

## Implementation Notes

- `EditorTextView.performKeyEquivalent` already handles Cmd+A/V/C/X/Z — add Cmd+F case
- `makeBaseTextView(editable:)` is the factory for both editor and output text views — enable find bar there
- For WKWebView, `isFindInteractionEnabled` requires macOS 13+ — use `@available` check
- No header layout changes needed
- No new AppColors needed
