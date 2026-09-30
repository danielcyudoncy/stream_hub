# TV Player Focus & Remote Navigation Standards

## Core Principles

1. **Reclaiming Focus on Control Auto-Hide (`TvPlayerKeyboard` / `reclaimFocus`)**:
   - In Flutter, `FocusNode.hasFocus` returns `true` if either the node itself OR any descendant has focus.
   - When player controls auto-hide, descendant controls (such as Play/Pause) may have had focus just before being excluded with `ExcludeFocus`.
   - Never use `!node.hasFocus` to decide whether to call `node.requestFocus()`. Always check `!node.hasPrimaryFocus` so the player anchor node (`_fullscreenFocusNode`) actively reclaims primary focus.
   - If primary focus is not actively reclaimed on the player anchor, focus escapes to `_ModalScopeState` (the route scope), and subsequent remote `OK` / `Select` / D-pad events will be dropped.

2. **D-Pad Directional Key Wake-Up**:
   - When player controls are hidden, pressing any directional key (Up, Down, Left, Right) must wake up the on-screen controls (`onAnyKey()`).
   - If controls are currently hidden (`!hasChildFocus`), the directional key should be consumed (`KeyEventResult.handled`) in fullscreen so focus does not jump outside the player or off-screen.
   - Once controls are visible, directional keys return `KeyEventResult.ignored` so 2D spatial traversal moves between player buttons.

3. **TvFocusable Key Event Integrity**:
   - Never wrap TV focusable items in a widget that resets or builds `Focus(onKeyEvent: null)` (such as `FocusableActionDetector`), as it wipes `node.onKeyEvent` during rebuilds.
   - Use direct `Focus(onKeyEvent: _handleKeyEvent, ...)` in `TvFocusable`.

4. **2D Traversal in Player Controls**:
   - All interactive controls (Back, Subtitles, Audio, Fullscreen, Replay 10s, Play/Pause, Forward 10s, Seekbar) should have dedicated `FocusNode`s and explicit routing via `_handleControlKey`.
   - When controls appear, primary focus must immediately target the center Play/Pause button (`_playPauseFocusNode`).
   - Sliders/Seekbars must declare `descendantsAreFocusable: false` on their `TvFocusable` wrapper so inner slider elements do not trap or swallow focus.
