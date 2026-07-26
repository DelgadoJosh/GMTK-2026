# Time Keeper — GMTK 2026 Plan

**Theme:** Countdown
**Engine:** Godot 4.5, Compatibility renderer
**Target:** Browser build on itch.io
**Status:** Implemented — see [README.md](README.md) for what shipped, what didn't, and the decisions this plan left open
**Revision:** 2 — incorporates decisions on open questions 1–8

---

## 1. Premise

You are the **Grand Maestro of Time Keeping (GMTK)**.

The pay is not great, so you've taken a side gig as a **Grandiose Awesome Magnificent/Maintenance Engineer who's a Joyfully Amazing Maintainer (GAME JAM)**.

The job: keep every countdown in the facility from reaching zero. All of them. At the same time. Forever.

**Goal:** survive as long as possible. Three mistakes and you're fired.

The joke does double duty — the theme is "countdown," and every failure state *is* a countdown hitting zero. The title card can spell out both acronyms letter-by-letter as an intro gag.

---

## 2. Core Loop

1. Stations appear on screen, each with its own countdown.
2. Each countdown drains in real time.
3. Servicing a station resets its countdown.
4. A countdown reaching zero = **1 mistake** (lose a heart).
5. 3 mistakes = fired = game over → score screen.
6. Over time, new stations unlock and existing ones drain faster.
7. **Bouncing between stations freezes the clocks briefly** — see §4.

The whole game is attention management. Nothing is hard alone; everything is hard together.

---

## 3. Stations

Four stations, unlocked over time, in a 2×2 grid.

### 3.1 Hourglass — *tutorial station*

| | |
|---|---|
| **Unlocks at** | 0s (start) |
| **Interaction** | Click the hourglass to flip it |
| **Countdown** | Sand drains top→bottom |
| **Service** | Flip → sand resets to full |
| **Fail** | Sand fully drained, then 1.5s grace → mistake |

- Base duration **14s**, floors at **5s** at max difficulty.
- Visual: two triangles + a sand fill whose height lerps. Flip = 180° rotation tween over 0.25s.
- Warning at 25% remaining (border pulses amber), critical at 10% (red).
- Deliberately trivial. It teaches "watch the bar, click the thing" before anything else exists.
- **Kept through late game** (per decision on Q3). The theory is that a station this dumb still demanding attention at minute four is the joke. Needs playtesting — if it reads as noise rather than comedy, retire it at 180s or give it a second chamber.

### 3.2 Wind-Up Clock

| | |
|---|---|
| **Unlocks at** | 10s |
| **Interaction** | Click **and hold** the winding key |
| **Countdown** | Mainspring tension drains 100 → 0 |
| **Service** | Hold to refill tension |
| **Fail** | Tension hits 0 → mistake. **Or** overwind → spring snaps → mistake |

- Drain: 100 tension over **20s** base, **8s** at max difficulty.
- Wind rate: **45 tension/sec** while held.
- **Overwind zone:** 90–100 is a red band on the gauge. Holding inside the red band for more than **0.6s** snaps the spring → mistake + 3s repair lockout.
- This is the first station that punishes *inattention while interacting*. You can't hold the key and stare at something else.
- **Overwind ships as-is** (per decision on Q4) with a very visible red band and an accelerating warning tick. If playtesters find it cheap, downgrade snapping from "mistake" to "3s lockout only" — that's a one-line change, keep it easy to flip.

### 3.3 Safe Keypad

| | |
|---|---|
| **Unlocks at** | 20s |
| **Interaction** | **Mouse only** — click digits on a 3×4 keypad |
| **Countdown** | Vault re-lock timer |
| **Service** | Press **9, 8, 7, 6, 5, 4, 3, 2, 1, 0** in order |
| **Fail** | Timer expires with the sequence incomplete → mistake |

The code is never arbitrary — it is *always* the descending count 9→0. That ties the station to the theme instead of just being a memory test, and it means the difficulty can live entirely in **where the digits are**, not what they are.

**Layout — 12 cells, 10 digits, 2 dead keys:**

```
1  2  3
4  5  6
7  8  9
✱  0  #
```

`✱` and `#` do nothing. They exist to fill the grid and, more importantly, to become **hazards once the pad shuffles** — a shuffled dead key sitting where you expected a digit.

- **Wrong key (digit or dead key) is not a mistake.** It flashes red and kills the whole pad for **1s** — the countdown keeps draining through it, so guessing costs strictly more than reading does. The entry so far is **kept**. Wiping nine correct presses for one misclick was the single most resented moment in the game.
- **Every correct digit adds 5s back to the re-lock timer**, capped at a full one (`Station.PROGRESS_TIME_BONUS`, shared with the rocket). The safe pays as you go rather than demanding the whole code in one breath. Not applied to the digit that opens the vault — see the rocket's note on why.
- Re-lock timer: **18s** base → **7s** at max.
- On success the safe swings open, holds, then re-locks and re-arms.
- LCD strip above the pad shows progress: `9 8 7 6 _ _ _ _ _ _`.

**Difficulty tiers:**

| Tier | Difficulty | Behavior |
|---|---|---|
| **0 — Standard** | `< 0.33` | Normal phone layout, fixed. Becomes muscle memory fast, which is the point — it's the "free" station until it isn't. |
| **1 — Shuffled** | `0.33 – 0.66` | Digits randomly reassigned to the 12 cells on every re-lock. |
| **2 — Arcane** *(stretch)* | `0.66 +` | Digits replaced by symbols; a codex panel shows the symbol→digit key. Re-rolls on shuffle. |

**Shuffle rules (anti-bamboozle):**

- Shuffle runs **only during the re-lock transition**, never mid-entry.
- During the **1.0s shuffle animation** the pad is **input-locked** — keys grey out, clicks do not register at all (not "register as wrong").
- **The re-lock timer is paused for the entire shuffle animation.** You never lose time to a shuffle.
- Keys tumble/flip into new positions so the movement is legible rather than an instant swap.
- Reroll if the permutation comes out identical to the previous one — a shuffle that visibly does nothing reads as a bug.

**On tier 2:** the codex-translation layer is genuinely a lot for a jam, and it's the single most likely thing to get cut. Two things make it worth trying anyway: it's additive (tiers 0 and 1 ship independently and the game is complete without it), and it pairs with the late-game rocket idea in §3.4 — see §13.3.

### 3.4 Rocket Launch

| | |
|---|---|
| **Unlocks at** | 40s |
| **Interaction** | **Keyboard** — click the box to focus, type each word, press **Enter** |
| **Countdown** | Launch-window timer for the whole sequence |
| **Service** | Type the full countdown: `ten, nine, … one, we have liftoff` |
| **Fail** | Launch window expires mid-sequence → scrubbed launch → mistake |

- Word list, in order:
  `ten` `nine` `eight` `seven` `six` `five` `four` `three` `two` `one` `we have liftoff`
- **Ghost text** shows the current target word greyed out inside the box. Typed characters overwrite the ghost in solid color.
- **Submit with Enter** (per decision on Q1). Type the word, hit Enter. Correct → accepted, box clears, ghost advances. Wrong → box shakes and clears, no heart lost, time lost.
- Because validation happens on Enter rather than per-character, **mid-word typos are allowed** — you can backspace and fix. More forgiving than strict prefix matching, and it makes Enter the deliberate commit beat.
- **Click to focus** (per decision on Q2). The box does **not** auto-steal focus when a launch window opens; the klaxon and flashing panel tell you, and walking over to click the box is part of the cost. `Esc` or clicking elsewhere releases focus.
- **Focus is held until you leave, not until you press Enter.** Godot 4.4+ ends a `LineEdit`'s editing state on submit (`keep_editing_on_text_submit`), and closing a window used to hand the caret back to nobody — so one word per click, and another trip to the mouse on every klaxon. The keypad keys are `FOCUS_NONE` for the same reason: servicing the safe must not silently cost you the rocket box.
- Both of these are explicitly marked for revisit after the first playtest — see §13.1.
- **Every accepted word adds 5s back to the launch window**, capped at a full one — the same bargain the safe keypad makes, and the same shared `Station.PROGRESS_TIME_BONUS`. Both stations ask for a long ordered sequence, so both pay as you go rather than demanding the whole thing inside one countdown.
  - The bonus is **not** applied to the word that launches (nor to the digit that opens the vault). `service()` grades the clutch bonus on the countdown as it stood, and a refill an instant before scoring would erase a genuine last-second save.
- Launch window: **22s** base for the full 11-word sequence → **13s** at max. Generous alone; brutal while an hourglass is draining.
- The rocket is **intermittent**. It idles at "no launch scheduled" and a window opens every **15s** base → **10s** at max. A klaxon and flashing panel announce it.
  - The **first** window after unlock comes after **5s**, not a full gap. A station that slams in demanding attention and then does nothing for half a minute reads as broken, and it wastes the one moment the rest of the facility is calm enough to learn a new klaxon in.
  - This was 35s → 18s. Combined with the 22s window it meant the rocket was idle more often than not; it is now live roughly 60% of the time, which is a real step up in load. If the late game becomes rocket-shaped, this is the dial.
- On success: rocket tweens up off the top of the panel, bonus score, back to idle.

**Why mouse/keyboard are split:** the keypad is pointer-driven and the rocket is keyboard-driven, so late-game you're using both hands on different problems and cannot batch them. It also sidesteps the focus collision where pressing `7` for the safe types a `7` into the rocket box.

---

## 4. Time Dividend — the reward for bouncing

Servicing one station in peace should feel worse than juggling. So: **every time you make progress on a station you weren't just working on, all countdowns freeze briefly.**

**A "progress point" is:**

| Station | Progress point |
|---|---|
| Hourglass | One flip |
| Wind-up clock | One wind into the green |
| Safe | Each **correct digit** pressed |
| Rocket | Each **accepted word** |

**The rule:**

> A progress point grants a **Time Dividend** only if it came from a **different station than the previous progress point**.

That's the whole non-stacking mechanism. Ten digits on the safe in a row = one dividend (the first, earned by switching to it). Eleven rocket words in a row = one dividend. Bailing out of the rocket at word four to flip the hourglass and coming back = three dividends.

**Effect:** all station countdowns pause for **0.4s**. The shift clock keeps running, so this is pure benefit and can't be used to farm score.

**Guards against degenerate play:**

- The progress point must be **worth points** — the §6 anti-spam rule applies, so flipping a nearly-full hourglass earns no dividend.
- **0.75s global cooldown** between dividends.
- Dividends don't fire during the post-mistake freeze.

Note the self-balancing property: a fixed 0.4s freeze is worth proportionally more as timers shorten, so the mechanic quietly gets stronger exactly when the player needs it.

**Feel:** brief desaturation pulse at the screen edges, all bars visibly halt, and a "clunk" of a pendulum catching. It needs to be unmistakable — an invisible reward teaches nothing.

**Considered and left out for now:** a stacking score multiplier for consecutive distinct-station progress. The freeze alone may already teach the behavior, and there's already a clutch bonus in §6. Noted in §13.6.

---

## 5. Difficulty Progression

A single `difficulty` float, `0.0 → 1.0`, drives everything.

```
difficulty = clamp(elapsed_time / RAMP_SECONDS, 0.0, 1.0)   # RAMP_SECONDS = 240
```

Every station duration is `lerp(base, floor, difficulty)`. One number to tune, one number for the debug slider. Safe tiers key off the same float.

| Phase | Time | Active | Feel |
|---|---|---|---|
| 1 — Orientation | 0–10s | Hourglass | "This is easy." |
| 2 — Two hands | 10–20s | + Wind-up clock | "Okay, I have to plan." |
| 3 — Three-body | 20–40s | + Safe (tier 0) | "Wait—" |
| 4 — Full shift | 40–240s | + Rocket, safe → tier 1 | Everything, accelerating |
| 5 — Overtime | 240s+ | All at floor, safe → tier 2 | Endurance; score is bragging rights |

The original schedule was 25 / 60 / 100s. It reads fine on a first play and badly
on a tenth: two minutes of a game you already understand before the game starts.
The unlock ladder was pulled in to 10 / 20 / 40s. The **difficulty ramp is still
240s** — that is the next dial to turn if the middle now feels flat.

**Veteran** (checkbox on the title card) skips the ladder entirely and opens with
all four stations live at second zero. Same ramp, no on-ramp.

### Overtime escalation (stretch)

Pressure without new systems:
- **Power flickers** — a random station dims for 2s; its bar keeps draining but you can't read it.
- **Boss inspection** — for 10s, servicing a station in its green zone scores as "wasteful" and gives no points. Forces you to run everything hot.
- Safe tier 2 and the arcane rocket variant (§13.3) both live here.

Second hourglass is **dropped** (per decision on Q7) — the grid stays 2×2.

---

## 6. Scoring

- **Primary: time survived**, shown as an in-fiction shift clock (`SHIFT TIME 03:41`). This is the high score.
- **Secondary: service points:**
  - Hourglass flip: **10**
  - Clock wound to green: **15**
  - Safe opened: **40**
  - Rocket launched: **100**
- **Clutch bonus:** ×2 when the service lands while the station is in the critical (red) zone.
- **Anti-spam:** servicing above 80% remaining awards **0** points and **no Time Dividend** (the timer still resets — it's just not worth anything). Prevents mash-farming the hourglass.
  - **The safe and the rocket are exempt.** Ten ordered clicks and eleven typed words cannot be mashed, and once correct digits refill the safe's timer a clean fast entry lands with the bar near full — zeroing that punishes exactly the play the rule was written to encourage.
  - The rule used to be invisible, which made "I serviced it and got nothing" the most confusing thing in the game. It is now stated twice on the panel: the fill bar goes **dark green** and the status line reads **NO POINTS YET**. The wind-up clock reports this whenever the spring is already in the green, since it only pays on the crossing *into* green — which is what makes hovering at the amber edge the high-roller play rather than a bug.
- **Cheated runs** (§10) are flagged and excluded from high scores.
- Game-over screen: shift time, points, per-station service counts, dividends earned, and *which station fired you*. That last line is the shareable bit.

---

## 7. Hearts / Mistakes

- 3 hearts, top-right.
- Losing one: 0.4s freeze, red vignette, a `MISTAKE` stamp, buzzer.
- The offending station gets a **2s grace lockout** so it can't fail twice in a row — otherwise a drained hourglass burns all three hearts in half a second while you're mid-rocket.
- **No heart regeneration** (per decision on Q5). Revisit only if playtest runs end so abruptly the difficulty curve never lands.
- Third mistake → `YOU'RE FIRED` → score screen → retry.

---

## 8. Screen Layout

```
┌──────────────────────────────────────────────────┐
│  GAME JAM  ·  SHIFT 02:14        ♥ ♥ ♡    1,240  │  HUD
├───────────────────────┬──────────────────────────┤
│      HOURGLASS        │      WIND-UP CLOCK       │
│      [ bar ]          │      [ gauge ]           │
├───────────────────────┼──────────────────────────┤
│      SAFE             │      ROCKET              │
│      [ keypad ]       │      [ text box ]        │
└───────────────────────┴──────────────────────────┘
                                            [ ⚙ debug ]
```

- Plain 2×2 `GridContainer`, **1280×720**, `canvas_items` stretch, `expand` aspect. Safe for itch embeds.
- Locked stations show a boarded panel reading `NOT YOUR PROBLEM (YET)`. Unlocking slams in with a shake + stamp.
- **Every panel carries a fill bar in the same place** (bottom edge) with the same colors: green → amber at 25% → red at 10% → flashing under 5%. Uniform readability is what makes the multitasking fair, whatever the art ends up being.
- Audio urgency ladder: each critical station adds a distinct looping tick. Four overlapping ticks is genuine panic and tells you the board state without looking.

**Deferred:** the "diorama" layout — hourglass large in the bottom-left foreground, other stations receding into the background — is a real improvement to make once the game is proven fun. Build the grid first; a `GridContainer` swapped for anchored positions is a contained change as long as each station scene stays self-contained and doesn't assume its size.

---

## 9. Architecture

Mirrors `Godot Delivery Truck` — one autoload manager, scenes under `scenes/`, scripts under `scripts/`.

```
Time Keeper/
├── project.godot
├── scenes/
│   ├── Main.tscn                  # HUD + StationGrid + DebugPanel + DialogLayer
│   ├── MainMenu.tscn
│   ├── GameOver.tscn
│   ├── HUD.tscn
│   ├── DebugPanel.tscn
│   ├── EasterEggDialog.tscn
│   └── stations/
│       ├── HourglassStation.tscn
│       ├── ClockStation.tscn
│       ├── SafeStation.tscn
│       └── RocketStation.tscn
├── scripts/
│   ├── GameManager.gd             # autoload
│   ├── Station.gd                 # base class
│   ├── ConsoleWords.gd            # easter eggs + cheats
│   ├── stations/…
│   ├── HUD.gd
│   └── DebugPanel.gd
└── assets/
    ├── placeholder/
    └── audio/
```

### `GameManager.gd` (autoload)

```gdscript
signal mistake_made(remaining_hearts: int)
signal station_unlocked(station_id: String)
signal score_changed(new_score: int)
signal dividend_earned(from_station: String)
signal game_over(final_time: float, final_score: int, cheated: bool)

var hearts: int = 3
var score: int = 0
var elapsed_time: float = 0.0
var difficulty: float = 0.0
var is_running: bool = false

# Time Dividend
var last_progress_station: String = ""
var dividend_cooldown: float = 0.0
var freeze_remaining: float = 0.0        # stations skip draining while > 0

# debug / cheat
var cheats_enabled: bool = false
var run_was_cheated: bool = false        # sticky, kills the high score
var debug_invincible: bool = false
var debug_difficulty_override: float = -1.0
var debug_time_scale: float = 1.0

func register_progress(station_id: String, scored: bool) -> void   # dividend logic
func register_mistake(source_station: String) -> void
func get_difficulty() -> float
```

### `Station.gd` (base class, `extends PanelContainer`)

```gdscript
class_name Station

signal serviced(station_id: String, urgency: float)
signal progress(station_id: String, scored: bool)
signal failed(station_id: String)

@export var station_id: String
@export var display_name: String
@export var base_duration: float
@export var floor_duration: float
@export var unlock_time: float

var is_unlocked: bool = false
var is_locked_out: bool = false
var is_timer_paused: bool = false        # shuffle animation, easter-egg dialog
var time_remaining: float

func get_current_duration() -> float     # lerp(base, floor, difficulty)
func get_urgency() -> float              # 0..1, 1 = about to fail
func service(points: int) -> void
func fail() -> void
func _process(delta: float) -> void      # drain; respects freeze + pause
```

Subclasses override only interaction handling. Hourglass ≈ 40 lines; rocket is the biggest at ≈ 180 with the console-word layer.

### Notes

- **Timers in `_process`, not `Timer` nodes.** Durations change continuously with difficulty, and the freeze / time-scale / shuffle-pause all need to apply uniformly. A float countdown is far simpler to reason about than restarting `Timer` nodes.
- **Signals up, calls down.** Stations emit; `GameManager` and `HUD` listen. Stations never reference each other.
- Three distinct pause concepts, don't conflate them: **freeze** (global, Time Dividend), **pause** (per-station, e.g. shuffle), **lockout** (per-station, post-failure grace).

---

## 10. Debug Mode, Cheats & Easter Eggs

### Console words

The rocket text box doubles as a command console. On Enter, the input is trimmed and lowercased and checked against a word table **before** the launch-word matcher. Matches are consumed — they never count as a typo. This works whether or not a launch window is open, so you don't have to wait for a rocket to type a cheat.

```gdscript
const CONSOLE_WORDS := {
    "easter egg": "_on_easter_egg",
    "cheat":      "_on_cheat",
}
```

| Typed | Effect |
|---|---|
| `easter egg` | Placeholder dialog: **"You found an easter egg!"** All countdowns pause while it's open. |
| `cheat` | Enables cheats + opens the debug panel. Sets `run_was_cheated = true` **permanently for the run**. |

- The easter-egg dialog **pauses the game**. Rewarding curiosity with a lost heart is a worse joke than it sounds.
- `cheat` marking the run is what lets the debug panel stay in the public build without wrecking the leaderboard. The score screen shows `CHEATED` and skips high-score submission. The flag never clears — no toggling cheats off to launder a run.
- The dictionary makes adding more a one-line change. Good spots for future eggs: your own name, `gmtk`, `fired`, `timekeeper`, `overtime`.

### Debug panel

Toggle with **`~`** (also **F1**, for browsers that swallow backtick), or by typing `cheat`. Slides in from the right. `~` is handled in `_input` before the `LineEdit` sees it.

| Control | Effect |
|---|---|
| ☑ per-station unlock (×4) | Force any station on/off, any combination |
| Difficulty slider `0.0–1.0` | Override the natural ramp — the main "make it hard now" knob |
| Time-scale slider `0.1–5.0` | Fast-forward the shift |
| `Jump to Phase 1–5` | Sets elapsed_time + unlocks to match |
| Safe tier `0 / 1 / 2` | Force layout mode independent of difficulty |
| `Shuffle now` | Trigger a keypad shuffle on demand |
| ☑ Invincible | Mistakes log to console, cost no hearts |
| `+1 / −1 heart` | Direct manipulation |
| `Force fail <station>` | Test the mistake path |
| `Force service <station>` | Test the success path |
| ☑ Freeze timers | All countdowns pause, interactions stay live |
| `Trigger dividend` | Fire a Time Dividend manually |
| Live readout | Per-station `time_remaining` / `duration` / `urgency`, plus `last_progress_station` |

Build this **immediately after** the base `Station` class. Everything after it is faster.

---

## 11. Art & Audio (placeholder → handmade)

Jam rules require assets made during the jam, so swapping must be mechanical.

- **No `ColorRect` / `Polygon2D` for anything representational.** Every visual is a `TextureRect` or `NinePatchRect` pointing at `assets/placeholder/`. Replacing art = dropping a new PNG over the old filename. Zero scene edits.
- Placeholders are flat shapes on transparent PNGs at 2× target size.
- **Exception:** urgency fill bars stay themed `ProgressBar`s — UI, not illustration, and they must stay uniform.
- Filename manifest, so the art pass has a checklist:
  ```
  hourglass_frame.png    hourglass_sand.png
  clock_face.png         clock_key.png         clock_gauge.png
  safe_door.png          safe_keypad_key.png   safe_lcd.png
  safe_symbol_0-9.png    codex_page.png
  rocket_body.png        rocket_flame.png      launchpad.png
  panel_bg.png           panel_locked.png
  heart_full.png         heart_empty.png
  ```
- One bitmap/pixel font everywhere, swapped once.
- Audio, same swap-by-filename rule: `tick`, `flip`, `wind`, `snap`, `keypad_beep`, `keypad_shuffle`, `safe_open`, `launch`, `dividend`, `mistake`, `fired`.

---

## 12. Web Export

Confirmed as the target. Compatibility renderer — nothing here needs Forward+, and Compatibility maximizes browser support.

Verify early rather than at submission:
- [x] Keyboard input reaches the `LineEdit` — checked against a real export served over HTTP. Not yet checked inside an itch iframe specifically.
- [x] `~` / F1 aren't swallowed by the browser — F1 toggles the debug panel from inside the canvas.
- [x] Tab-out pauses rather than draining in the background.
- [ ] Audio starts (browsers block autoplay until first user gesture — the main-menu click covers this, but confirm). Not yet listened to in a browser.

---

## 13. Open Questions

### Resolved this pass

- **Q1/Q2 Rocket input** → type + Enter, click to focus. *Revisit after playtest.*
- **Q3 Hourglass late-game** → keep. *Revisit after playtest.*
- **Q4 Overwind** → ship it. *Revisit after playtest.*
- **Q5 Heart regen** → none. *Revisit after playtest.*
- **Q6 Safe** → always 9→0, difficulty via shuffle then symbols.
- **Q7 Layout** → 2×2 grid, diorama layout deferred to polish.
- **Q8 Web export** → yes, Compatibility renderer.

### Still open

**13.1 — Rocket input feel.** Four things to watch: does Enter feel like a satisfying commit or like busywork ×11? Is click-to-focus a fair cost or just annoying when the klaxon fires mid-keypad? Should focus auto-grab on window open? Should the box clear on a wrong Enter, or keep the text so you can fix one letter? The last one is the cheapest to flip and probably matters most.

**13.2 — Safe tier 2 scope.** The codex-translation layer is the most likely cut. Decide at the tier-1 playtest, not before. Fallback if it's too much: keep symbols but put the key permanently on-screen next to the pad with no re-rolling — most of the disorientation, a fraction of the work.

**13.3 — The arcane late-game pivot.** Two separate "maybe" ideas point the same direction: safe tier 2 (arcane symbols) and the rocket-as-incantation idea. Together they'd give phase 5 a real identity — *the mundane maintenance job turns out to be holding back something*. Concrete proposal: the rocket's late-game word list becomes **Latin numerals** — `decem, novem, octo, septem, sex, quinque, quattuor, tres, duo, unus` — closing on `so mote it be` instead of `we have liftoff`. Same countdown structure, same mechanic, harder to type, no new systems. If both land, phase 5 sells itself. **Decide only after phase 4 is fun** — this is flavor on top of a working game, not a rescue for one that isn't.

**13.4 — Does the Time Dividend actually read?** The risk is that 0.4s is too short to notice and players never learn the rule. Watch for whether anyone verbalizes it. If not: lengthen to 0.6s, make the effect louder, or surface an explicit "SWITCHED!" popup.

**13.5 — Dividend exploit surface.** Alternating hourglass↔clock is gated by the 80% rule and the 0.75s cooldown, and that alternation is arguably the skilled play anyway. But it needs an actual check with the time-scale cranked, where inputs get cheap.

**13.6 — Score multiplier for chained switching?** Deliberately left out so the freeze can be evaluated on its own. If bouncing still feels unrewarded after 13.4, this is the next lever.

**13.7 — Safe progress-point granularity.** Each correct digit is a progress point, so the safe is the easiest station to earn a dividend from (switch in, press one key, leave). That may be fine — it makes the safe a deliberate "tap in for tempo" move — or it may be the dominant strategy. Watch it.

---

## 14. Test / Edge Case List

The debug panel exists mainly to make these fast.

Boxes ticked below are covered by the headless suite in `tools/smoke_test.gd`
(`godot --headless res://tools/SmokeTest.tscn`, 83 assertions). The unticked
ones need a human on a mouse — they are about feel, focus and input timing,
which is exactly the part a harness can't judge.

**Failure & hearts**
- [x] Two stations expire on the same frame → 1 heart or 2? (Intended: 2 — verify it isn't 3 from a cascade.)
- [x] A station expiring during the post-mistake freeze doesn't double-count.
- [x] Grace lockout actually prevents an immediate re-fail on the same station.
- [x] Third mistake and a service on the same frame → game over fires exactly once.
- [x] Mistake at 0 hearts doesn't go negative.

**Hourglass / clock**
- [ ] Clicking mid-flip-tween doesn't stack rotations or double-reset.
- [x] Wind-up: holding through the red band from below vs. starting inside it — both snap.
- [ ] Wind-up: releasing the mouse *outside* the panel still stops winding (mouse-exit while held).

**Safe**
- [ ] Rapid clicks on one key don't register duplicates from a single press.
- [x] Pressing `0` (the final digit) opens the safe; pressing anything after doesn't re-trigger.
- [x] Dead keys `*` / `#` register as wrong, not as no-ops. (Rendered `*`, not `✱` — the bundled font has no U+2731.)
- [x] Clicks during the shuffle animation register as **nothing** — not as wrong presses.
- [x] Re-lock timer is genuinely paused for the full shuffle, not just visually.
- [x] Shuffle never produces the identical previous layout (reroll path is reachable and terminates).
- [x] Shuffle never fires mid-entry, even if difficulty crosses the tier threshold at that moment.
- [x] Crossing 0.33 / 0.66 mid-entry doesn't corrupt the current attempt.
- [ ] Tier 2: codex mapping shown always matches the live pad after a reroll.

**Rocket**
- [x] Launch window opens while the player is mid-typing from a previous window.
- [x] `we have liftoff` — internal spaces handled, leading/trailing whitespace tolerated.
- [x] Enter on an empty box is a no-op, not a wrong answer.
- [x] Window expires on the final word → mistake, no partial credit.
- [x] Focus survives `Enter` and survives the window closing; released on `Esc` and on clicking another panel. Keypad clicks don't steal it.
- [ ] Typing while unfocused does nothing (and doesn't leak to the debug hotkey).
- [x] Pasting a whole word with Ctrl+V — **blocked**. Pasting `we have liftoff` is not a countdown.

**Console words**
- [x] `easter egg` matched before launch words; never counts as a typo.
- [x] Case and surrounding whitespace ignored (`  Easter Egg  ` works).
- [x] Console words work while the rocket is **idle** (no launch window open).
- [x] Easter-egg dialog pauses every countdown and resumes cleanly, including a mid-launch window.
- [ ] Dismissing the dialog restores focus sensibly.
- [x] `cheat` sets the run flag; the flag survives toggling the debug panel back off.
- [ ] Score screen shows `CHEATED` and skips high-score submission.
- [x] Typing a console word during a launch doesn't consume the current target word.

**Time Dividend**
- [x] Two progress points from the same station in a row → exactly one dividend.
- [x] A → B → A gives three dividends (each is a switch).
- [x] Ten safe digits in a row → one dividend.
- [x] Freeze pauses station countdowns but **not** the shift clock.
- [x] Freeze applies to the rocket launch window too.
- [x] Dividend suppressed for an unscored (>80% full) service.
- [x] Dividend doesn't fire during the post-mistake freeze.
- [x] Overlapping dividends don't stack into a long freeze — cooldown holds.
- [x] `last_progress_station` resets sensibly on game over / restart.

**Progression**
- [ ] Station unlocking at the exact moment another fails.
- [x] Debug difficulty override respected by *every* duration calc and by the safe tier.
- [x] Time-scale 5× doesn't let a countdown skip past 0 into negative without failing.
- [x] Jump to phase 5 from phase 1 unlocks everything with sane starting timers (not all at 0).

**Score**
- [x] Service at exactly 80% remaining — **it scores**, and the dividend rule agrees. Compared with an epsilon; the naive float compare gets it wrong.
- [x] Clutch ×2 applies on the frame the station enters critical.
- [x] Score doesn't tick after game over.

**Platform** — see §12.

---

## 15. Build Order

Ordered so there's a playable thing early and everything later is optional.

| # | Step | Outcome |
|---|---|---|
| 1 | Project setup, `GameManager` autoload, `Main.tscn` skeleton, HUD | Empty shell that counts up |
| 2 | `Station.gd` base class + dummy station with a draining bar | The core loop exists |
| 3 | **Debug panel** | Everything after this is faster |
| 4 | Hourglass station | First real, playable game |
| 5 | Game over + score screen + retry | Complete loop, shippable |
| 6 | Wind-up clock | Two-station multitasking |
| 7 | **Time Dividend** | The reason to bounce — needs 2 stations to test |
| 8 | Safe keypad, tier 0 | Three-station |
| 9 | Rocket + ghost text + Enter submit | Full game |
| 10 | Console words: `easter egg`, `cheat` | Cheap, high delight-per-hour |
| 11 | Safe tier 1 (shuffle + animation + pause) | Difficulty has somewhere to go |
| 12 | Difficulty ramp tuning + unlock timings | The actual game design work |
| 13 | Audio urgency ladder | Biggest feel-per-hour win |
| 14 | Main menu, title-card acronym gag, polish | Presentation |
| 15 | Handmade art pass (swap `assets/placeholder/`) | Jam compliance |
| 16 | Web export + itch page | Submitted |
| — | *Stretch:* safe tier 2, arcane rocket, diorama layout, overtime events | Only if 1–16 are done |

**Steps 1–5 are the minimum viable submission.** A polished one-station game with a score screen beats four broken stations. Reserve the last ~20% of the jam for export, upload, and the itch page — web export always finds a new way to be a problem.
