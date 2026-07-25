# Time Keeper

GMTK 2026 — theme **Countdown**. Godot 4.5, Compatibility renderer, web build.

You are the Grand Maestro of Time Keeping, moonlighting as a Grandiose Awesome
Magnificent/Maintenance Engineer who's a Joyfully Amazing Maintainer. Keep every
countdown in the facility from reaching zero. Three mistakes and you're fired.

Implementation of [plan.md](plan.md). Read that first — it is the design
document and this file only covers what the code does differently.

---

## Running it

Open the project in Godot 4.5 and press play, or:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "Games/GMTK 2026/Time Keeper"
```

### Headless test suite

68 assertions covering the plan's §14 edge-case list — same-frame expiries,
dividend switching rules, shuffle input-locking, console-word precedence,
scoring boundaries:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless res://tools/SmokeTest.tscn
```

### Layout screenshot

Boots the real scene with everything unlocked and writes a PNG. Run it after
touching a station scene; hand-written `.tscn` layout breaks silently.

```bash
/Applications/Godot.app/Contents/MacOS/Godot res://tools/Screenshot.tscn --resolution 1280x720 -- out.png
```

Append `-- gameover out.png` for the score screen.

### Web export

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web"
```

Lands in `Exports/Time Keeper/v0.1.0/index.html`. Serve it over HTTP (not
`file://`) to test:

```bash
python3 -m http.server 8231
```

### Regenerating placeholders

`tools/gen_placeholders.py` and `tools/gen_audio.py` rebuild
`assets/placeholder/` and `assets/audio/`. The handmade art pass replaces those
files **by filename** — no scene edits, per plan §11. Both are excluded from the
export along with the rest of `tools/`.

The per-file checklist for that swap — every art and audio asset, its size, how
it is drawn, and which ones have constraints mirrored in code — is
[ASSETS_TODO.md](ASSETS_TODO.md). Claim rows there before you start drawing.
Don't re-run the generators once real assets land; they overwrite by filename.

---

## Controls

| | |
|---|---|
| Hourglass | Click the panel to flip |
| Wind-up clock | Click and **hold** the key to wind — mind the red band |
| Safe | Click 9, 8, 7 … 1, 0 in order |
| Rocket | Click the box, type each word, **Enter** |
| Debug panel | `` ` `` or **F1**, or type `cheat` in the rocket box |
| Release the text box | `Esc`, or click elsewhere |

Console words in the rocket box: `easter egg`, `cheat`. Adding more is one line
in `scripts/ConsoleWords.gd`.

---

## What's built

Everything in build order 1–14, plus 16. Safe tier 2 (arcane symbols + codex)
is in as well, and reachable from the debug panel independent of difficulty.

Not built, deliberately:

- **Step 15, handmade art.** Placeholders are generated flat shapes. This is the
  jam-compliance step and it is yours to do; the swap is mechanical.
- **The arcane rocket variant (plan §13.3).** The plan says decide only after
  phase 4 is fun. The word list is a single constant in `RocketStation.gd`, so
  it stays a one-line change.
- **Overtime events (§5 stretch)** — power flickers, boss inspection.
- **The diorama layout (§8)** — deferred to polish, as planned.
- **Score multiplier for chained switching (§13.6)** — left out on purpose so
  the freeze can be evaluated on its own.

---

## Decisions the plan left to the implementation

**Unscored progress points are ignored entirely.** Servicing above 80% earns no
points, no dividend, *and* does not claim the "last station touched" slot. The
alternative — letting a worthless flip reset your switch chain — punishes you
for a mistake you already got nothing for.

**Exactly at a scoring threshold counts** (§14 asks for a side). 80% remaining
scores; 10% remaining lands the clutch bonus. Both comparisons carry a small
epsilon, because `duration * 0.8 / duration` lands a hair above `0.8` in
floating point often enough to make the documented answer a lie.

**Paste is blocked** in the rocket box (§14 asks to decide). Pasting
`we have liftoff` is not a countdown.

**The clock's clutch bonus is judged on the lowest tension reached** since the
last green crossing, not the tension at the instant you cross 25. You always
cross at exactly 25, so the literal reading would mean the clutch never pays.

**The rocket's idle gap is its own countdown.** While idle the bar fills toward
the next window in blue rather than draining toward failure in green→red, and
the station is excluded from the audio tick ladder — an idle rocket is not an
emergency.

**Ghost text is a coloured overlay, not the `LineEdit`'s own text.** The real
text and caret are drawn transparent and a `RichTextLabel` renders every
character: typed-and-correct white, typed-and-wrong orange, untyped grey, plus a
drawn caret. Consequence: the caret always renders at the end of the string, so
arrow-keying into the middle of a word looks wrong even though the edit works.
Acceptable for a jam; a real fix means measuring glyph advances.

**A "mistake" freeze replaces a dividend freeze** rather than extending it, so
the two can't be chained into a long safe window.

---

## Architecture notes

Per plan §9. `GameManager` is the only autoload that matters (`Sfx` is a sound
pool). Stations emit; `GameManager` and `HUD` listen; stations never reference
each other.

Countdowns are floats in `_process`, not `Timer` nodes — durations change
continuously with difficulty and the freeze/time-scale/pause layers have to
apply uniformly.

Three pause concepts, deliberately not conflated:

- **freeze** — global, from a Time Dividend, a mistake, a modal, tab-out, or the
  debug toggle. `GameManager.is_frozen()`.
- **pause** — per-station, e.g. the safe's shuffle or the hourglass flip tween.
  `Station.is_timer_paused`.
- **lockout** — per-station post-failure grace. `Station.is_locked_out`.

Every station scene shares the same shell (`Background` / `Layout/Stack/{Title,
Body,Status,Bar}` / `LockedOverlay`) so the base class can own the title, the
urgency bar and the locked board. Only `Body` differs. If you add a station,
copy an existing `.tscn` and replace `Body`.

The debug panel builds its widgets in code rather than in the `.tscn`. It is a
tool with no art to swap, and forty hand-maintained widgets is forty things to
keep in sync with the game.

---

## Verified on the web build

Checked in a browser against a real export, per plan §12:

- Keyboard input reaches the `LineEdit` inside the canvas.
- `` ` `` / F1 are not swallowed — the debug panel toggles.
- Console words (`cheat`) run and flag the run.
- Tab-out pauses the shift instead of draining in the background.

Audio autoplay is unblocked by the main-menu click, but has not been listened
to in a browser. Nor has itch's iframe specifically — it is the same canvas, but
confirm before submitting.

---

## Still to playtest

The plan's §13 open questions are all still open; nothing here settles them.
The ones the debug panel exists to answer fast:

- **13.1** Does Enter feel like a commit or like busywork ×11? Should a wrong
  Enter clear the box or keep the text? That last one is `_reject_word()` in
  `RocketStation.gd` — one line.
- **13.4** Does the Time Dividend read at 0.4s? There is a `SWITCHED!` banner in
  the HUD, a screen-edge pulse and a sound; if players still don't verbalise the
  rule, lengthen the freeze.
- **13.5** Dividend exploit surface — alternate hourglass↔clock with the time
  scale cranked and watch whether it dominates.
- **13.7** Safe progress granularity — each correct digit is a progress point,
  which makes the safe the cheapest place to earn a dividend. Watch whether
  "tap in for tempo" becomes the only play.

Two more the code makes cheap to flip:

- Overwind snapping is a full mistake (§13, Q4). To downgrade it to a lockout
  only, replace `fail(SNAP_LOCKOUT)` in `ClockStation._snap()` with
  `begin_lockout(SNAP_LOCKOUT)`.
- The hourglass is kept through the late game (Q3). To retire it at 180s, give
  it a `debug_unlock_overrides`-style cutoff or just raise its floor duration.
