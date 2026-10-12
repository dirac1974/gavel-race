# UI floors and screen budget (AAA Phase 2)

- Panels shrink only through `Ui.fitPanel(panel, w, h, minHeight?, minText?, minButton?)`; pass the panel's
  smallest text and button so the floor holds. The returned slide takes `(newHeight?, still?)`.
- `tests/test_clarity_floors.py` lints every literal size in `game/src/client` (except the race screen
  files): buttons >= 56 px, text >= 14 px, or the fitPanel-declared floors. No `.Scale = math.min(1, ...)`.
  Every ✕ is `Ui.closeButton`.
- Top-centre cards go through `Ui.slot(id, priority, frame)` and `Ui.topSlotPlace(width)`; toasts stack
  under `Ui.slotBottom()`. Priorities live in `GameConfig.topSlot`.
- Text colours: `C.textGood` / `C.textWarn`; `C.green`, `C.cash`, `C.orange(Dark)` are fills only
  (clarity_tests scans TextColor3 lines).
- Python heredocs: a `\n` inside a triple-quoted string becomes a real newline in the Luau file; write
  helper scripts with the Write tool instead.
