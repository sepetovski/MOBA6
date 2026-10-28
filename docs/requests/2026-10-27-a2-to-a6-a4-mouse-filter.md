# Request: decorative HUD must not swallow world clicks

- Date: 2026-10-27
- From: A2 (Camera and Input)
- To: A6 (UI) and A4 (Sim Core, debug overlay)
- Status: open. A2 does not edit `src/ui/` or the match scene.

## What

Every decorative control (labels, portraits, frames, the debug overlay's non-interactive text) must set `mouse_filter = Control.MOUSE_FILTER_IGNORE`.

## Why

`PlayerController` reads the pointer in `_unhandled_input`. A control with `MOUSE_FILTER_STOP` or `PASS` consumes the click before that, so a right-click meant as `MOVE_TO` never starts, and a press that never arrives must not start a steer hold.

Interactive controls (buttons, the future ability bar) should keep `STOP` and only cover their own rectangle.

## Proposed signature

```gdscript
label.mouse_filter = Control.MOUSE_FILTER_IGNORE
```
