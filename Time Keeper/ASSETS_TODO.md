# Asset TODO — art, audio & text

Every visual and every sound in the game right now is a **procedurally
generated placeholder** (`tools/gen_placeholders.py`, `tools/gen_audio.py`).
Nothing here has been hand-made yet.

This file is the checklist for replacing them. Put your name in the **Owner**
column when you pick something up, tick the box when the final file is
committed.

> **Everything on this list is hand-made by a human — art, audio and every
> word of text. No AI-generated assets, no AI-written copy.** See
> [Text & dialog](#text--dialog) for what that means for the writing pass.

---

## How to swap an asset

Per plan §11, swapping is meant to be mechanical:

1. Make your file with the **exact same filename** as the placeholder.
2. Drop it over the old file in `assets/placeholder/` or `assets/audio/`.
3. Open the project in Godot — it re-imports on focus. Leave the `.import`
   file alone; it keeps the resource UID stable so nothing has to be relinked.
4. Run the layout screenshot and eyeball it:
   ```bash
   godot res://tools/Screenshot.tscn --resolution 1280x720 -- out.png
   ```

**A new filename is not a free swap.** Anything that isn't already in the
manifest below needs a scene or script change — flag it in the team channel
rather than dropping an orphan file in the folder.

Do not re-run `tools/gen_placeholders.py` / `tools/gen_audio.py` after real
assets land — they overwrite by filename and will wipe finished work.

### Rules for all art

- **Transparent RGBA PNG**, authored at ~2× its on-screen size. Note the
  placeholders do not all hit that: `clock_key`, `clock_gauge`, `safe_lcd`,
  `safe_keypad_key` and `rocket_flame` are undersized or the wrong aspect for
  their slot. Where that's true the row below gives a corrected authoring size
  in bold — use it rather than matching the placeholder.
- **Texture filtering is off project-wide** (`default_texture_filter=0`,
  nearest). Pixel art is happy. Smooth/painted art gets crunchy edges when
  scaled — author at or above the largest size it is drawn at.
- Viewport is **1280×720**, `canvas_items` stretch, `expand` aspect. Each
  station panel is exactly **624×319** at that resolution, and the game is
  played in a browser, so read-at-a-glance beats detail.
- **The art slot is not the panel.** 624×319 is the outer frame; inside it the
  title, status caption and fill bar eat the rest, leaving a `Body` of exactly
  **596×228** — the same on all four stations. That is the box station art is
  laid out in. Measure against 596×228, not 624×319.
- **596×228 is 2.6:1, and most station art is `STRETCH_KEEP_ASPECT_CENTERED`.**
  Aspect-kept art in the body is therefore *height*-bound: a square or portrait
  texture lands at ~228px tall and much narrower than the panel, centred, with
  empty space either side. It does not matter how wide you author it. The
  "Drawn as" column below gives the real on-screen pixels for each asset —
  design to those, and treat the file size as authoring headroom only.
- Current placeholder palette lives at the top of `tools/gen_placeholders.py`
  (brass / steel / glass / sand / LCD green / red). Agree on a palette before
  the first real asset lands, or the four stations will not look like one
  facility.
- Sizes marked ⚠ are **mirrored in code** — changing them means editing the
  file named in the note as well.

---

## 1. Station panels & shared chrome

Used by all four stations, so these set the look of the whole screen. Best
done first.

| ☐ | File | Size | Drawn as | Notes | Owner |
|---|---|---|---|---|---|
| ☐ | `panel_bg.png` | 96×96 | 9-patch, 24px margins — stretched to 624×319 as a station frame, 1256×46 as the HUD bar, and 387×48 as the rocket console field | ⚠ Margins are set in every station scene, `HUD.tscn` and `RocketStation.tscn`'s console frame. Keep a 96×96 / 24px-border layout or five scenes need editing. Highest-impact asset in the game — it's the station frame, the HUD bar and the rocket console. | |
| ☐ | `panel_locked.png` | 96×96 | 9-patch, 24px margins — stretched to 624×319 | Same margin rule. This is the boarded-up "NOT YOUR PROBLEM (YET)" cover over locked stations; the label is drawn on top so leave the middle readable. | |
| ☐ | `vignette.png` | 256×144 | Stretched full-screen, **tinted at runtime** | Must be **white with an alpha falloff** — it gets modulated red for a mistake and pale blue for a Time Dividend (`Main.tscn` → `Overlays`). Centre must stay fully transparent. Colour baked into the file will fight the tint. | |
| ☐ | `heart_full.png` | 64×64 | HUD, drawn at 26×26, aspect-kept | Scales up 1.6× on the lose-a-heart pop (`HUD.gd`), so it needs to hold at ~42px too. | |
| ☐ | `heart_empty.png` | 64×64 | HUD, drawn at 26×26 | Must read as *spent*, not as a second full heart, at 26px. | |

## 2. Hourglass station

| ☐ | File | Size | Drawn as | Notes | Owner |
|---|---|---|---|---|---|
| ☐ | `hourglass_frame.png` | 440×520 | Aspect-kept, drawn **193×228** — fills the body's height, ~32% of its width, centred | ⚠ **This one is a mask, not just a picture.** The plate is opaque and the two bulbs are punched *transparent*; the sand quad is drawn behind it and shaped by the holes. Bulb rects are `TOP_BULB = (48, 44, 344, 216)` and `BOTTOM_BULB = (48, 260, 344, 216)`, duplicated in `scripts/stations/HourglassStation.gd` and `tools/gen_placeholders.py`. Change the geometry → update both. | |
| ☐ | `hourglass_sand.png` | 400×400 | Stretched into a chamber ~151px wide by up to 95px tall | A plain fill swatch, not a shape. It gets squashed to an arbitrary rectangle every frame, so texture it flat/tileable — anything with a silhouette will smear. | |

Also note: the whole glass Control **rotates 180°** over 0.25s on a flip, so
the frame should look right upside down (the placeholder is symmetric on
purpose).

## 3. Wind-up clock station

| ☐ | File | Size | Drawn as | Notes | Owner |
|---|---|---|---|---|---|
| ☐ | `clock_face.png` | 480×480 | Aspect-kept in a 250×155 box on the left ~42% of the body, so drawn **155×155** | ⚠ **The entire texture rotates** a full turn as the countdown drains (`face.rotation = -fraction * TAU`). Hands are baked into the face; there is no separate hand node. Either keep it a spinning dial, or split it into face + hand — which is a scene change, so raise it first. | |
| ☐ | `clock_key.png` | 160×160 (author **256×256**) | Aspect-kept in a 215×128 box on the right ~36% of the body, so drawn **128×128** | Spins around its own centre while held (~1.4 turns/sec), so keep it **centred in its canvas** and visually obvious as a grab target — it's the click-and-hold hotspot. ⚠ The 160×160 placeholder is only 1.25× its on-screen size, short of the 2× rule above — author the real one at 256×256. | |
| ☐ | `clock_gauge.png` | 520×120 (author **1120×118**) | Stretched (not aspect-kept) to **560×59** | ⚠ The slot is 9.5:1 but the placeholder is 4.3:1, so it gets squashed to 46% of its authored height — even borders come out half as thick top/bottom as left/right. Author at the slot's aspect (2× = 1120×118) and it lands undistorted. Bezel only. The tension bar, the red overwind band and its edge line are themed `ProgressBar`/`ColorRect` chrome drawn inside a 10px/9px inset — plan §11 keeps fill bars as UI. Do **not** paint a bar or a red band into the texture; the band position is computed from `OVERWIND_MIN`. | |

## 4. Safe station

| ☐ | File | Size | Drawn as | Notes | Owner |
|---|---|---|---|---|---|
| ☐ | `safe_door.png` | 600×600 | Aspect-kept over the body, so drawn **228×228** — ~38% of the body width, centred | Only visible during the "cracked it" flash — fades in and out over ~0.6s. It's a celebration frame, so it can carry more detail than the always-on art. | |
| ☐ | `safe_keypad_key.png` | 140×140 (author **256×92**) | `TextureButton` normal texture, aspect-kept, drawn **46×46** | ⚠ The button cell is **128×46** — wide and short — but the square placeholder aspect-fits to 46×46 and covers only ~36% of it, so the clickable area is much bigger than the art. Author at the cell's 2.8:1 (2× = 256×92) to fill the key. 12 of them in a grid. Only `texture_normal` is wired — hover/pressed art would need `KeypadKey.tscn` edited. Digit label or symbol is drawn on top, so keep the centre clear. Feedback flash tints the button, so the base should be neutral enough to tint. | |
| ☐ | `safe_lcd.png` | 600×100 (author **786×52**) | Stretched (not aspect-kept) to **393×26** | ⚠ The slot is 15:1 but the placeholder is 6:1, so it squashes to 26% of its authored height. Author at the slot's aspect (2× = 786×52). Readout background. The entered code is a `Label` on top — keep contrast high and don't bake in segments. | |
| ☐ | `safe_symbol_0.png` … `safe_symbol_9.png` (10 files) | 96×96 | Aspect-kept, **34×34** on the key face and **22×22** in the codex | ⚠ Loaded by pattern `safe_symbol_%s.png` — all ten must exist. Arcane glyphs for tier 2: each must be **unmistakable from the other nine at 22px** — smaller than it sounds, so this is a silhouette job, not a detail job — and meaningless enough that the player has to consult the codex. Check both sizes. | |
| ☐ | `codex_page.png` | 400×600 | `StyleBoxTexture`, 12px texture margins, stretched over **185×278** | ⚠ 12px margin is set in `SafeStation.tscn`. It's the paper the symbol→digit legend is printed on, in a narrow strip down the right ~31% of the panel. Symbols and digit labels are drawn over it in two columns. | |

## 5. Rocket station

| ☐ | File | Size | Drawn as | Notes | Owner |
|---|---|---|---|---|---|
| ☐ | `rocket_body.png` | 120×320 | Aspect-kept, 60×120 box on the pad | Slides up and off-screen on launch. Nose points up; the flame anchors under its tail. | |
| ☐ | `rocket_flame.png` | 100×140 (author **54×128**) | Anchored under the rocket over a 26×64 slot (0.92–1.45 of its height), aspect-kept so drawn **26×37** | ⚠ The slot is 0.41:1 but the placeholder is 0.71:1, so the flame only reaches ~58% down it and the bottom of the slot sits empty. Author tall and narrow (2× = 54×128) to use the full plume length. Hidden until launch. Single static frame — no animation player, so it either reads as a plume in one image or stays abstract. | |
| ☐ | `launchpad.png` | 400×80 | Aspect-kept in a 183×50 box on the bottom ~22% of the body, so drawn **183×37** | Static. The rocket sits on it and leaves it behind. | |

The rocket's console frame reuses `panel_bg.png` and flashes red six times
when a launch window opens, so whatever you do to `panel_bg` has to survive
being modulated to a hard red.

## 6. Not created yet — needs a code or scene change

These don't exist in the repo at all. Each one is a decision, not just a file:

| ☐ | Asset | Why it's not a drop-in | Owner |
|---|---|---|---|
| ☐ | **Bitmap/pixel font** | Plan §11 calls for "one bitmap/pixel font everywhere, swapped once". The game currently uses the Godot default at 13–22px. Needs a project theme, and every label size re-checked. Also: whatever is picked must cover the characters the safe uses (the current default has no U+2731, which is why the dead key renders as a plain `*`). | |
| ☐ | **Game / tab icon** | `icon.svg` is a hand-written placeholder hourglass. The web export also has empty PWA icon slots (144, 180, 512) in `export_presets.cfg`. | |
| ☐ | **itch.io page art** | Cover image (630×500), screenshots, GIF. Not in the project, but it's the first thing a judge sees. | |
| ☐ | **Main-menu art** | The menu just tints `hourglass_frame.png` to 6% alpha as wallpaper. Fine as-is; upgrade only if there's time. | |
| ☐ | **Game-over screen art** | `GameOver.tscn` is text-only. Same — nice to have. | |

---

# Audio

## Sound effects — 14, all placeholders

All are synthesised 22.05kHz mono 16-bit WAVs from `tools/gen_audio.py`.
Same swap-by-filename rule as the art. `scripts/Sfx.gd` loads exactly this
list at boot and warns on anything missing, so **don't rename or delete**.

| ☐ | File | Now | Fires when | Owner |
|---|---|---|---|---|
| ☐ | `tick.wav` | 0.06s square blip | The urgency ladder. Plays **per station** at a fixed pitch — hourglass 0.75, clock 1.0, safe 1.35, rocket 1.8 — starting at 25% time remaining, accelerating from one every 0.5s to one every 0.11s, and rising from −14dB to −3dB. ⚠ Hardest sound in the game: it must stay countable when four of them overlap at four pitches, and it must survive being pitch-shifted 0.75×–1.8×. Keep it short and dry. | |
| ☐ | `flip.wav` | 0.30s noise + falling tone | Hourglass flipped. | |
| ☐ | `wind.wav` | 0.20s rising saw ratchet | Winding the clock. Retriggered **every 0.18s while held** at random pitch 0.95–1.15, −6dB — so it must stack into a continuous ratchet, not a machine-gun of one identical sample. | |
| ☐ | `snap.wav` | 0.35s noise crack | Mainspring snapped from overwinding. This is a failure — should sting. | |
| ☐ | `keypad_beep.wav` | 0.05s square beep | Safe key pressed (pitch 1.0→1.45 as the code fills), rocket word accepted (pitch 1.0→1.4 per word), and rejected input (pitch 0.5, −2dB). Also the menu blip. Must read as both "yes" and, pitched down, "no". | |
| ☐ | `keypad_shuffle.wav` | 0.84s scramble | Safe keypad reshuffles — input is locked while it plays, so the sound is the tell for "don't press anything yet". | |
| ☐ | `safe_open.wav` | 0.90s rising sweep + noise | Safe cracked. Reward sound. | |
| ☐ | `launch.wav` | 1.60s noise + rising rumble | Rocket launch. The biggest payoff in the game (100 pts). | |
| ☐ | `klaxon.wav` | 1.00s two-tone alarm | A launch window opens. Plays over the console flashing red — it's an *announcement* that has to cut through whatever else is ticking. | |
| ☐ | `dividend.wav` | 0.25s two-note chime | Time Dividend earned. | |
| ☐ | `mistake.wav` | 0.55s falling buzz | A heart lost. | |
| ☐ | `fired.wav` | 1.26s descending three-note | Game over — third mistake. | |
| ☐ | `unlock.wav` | 0.42s rising arpeggio | A new station unlocks. | |
| ☐ | `click.wav` | 0.04s blip | UI: menu buttons, game-over buttons, easter-egg dialog. | |

Format notes: keep 22.05kHz mono unless someone checks the web export size;
`compress/mode=2` (QOA) is set in the `.import` files, so heavy stereo files
will bloat the download. Godot loop mode is off for all of them.

## Music — there is none

**No music exists in the project, and nothing in the code plays any.**
`Sfx.gd` is a one-shot pool plus the tick ladder — there is no music player,
no music bus, and no `assets/music/` folder. Adding a track is a code change,
not a file drop.

If we want music, someone needs to own both halves:

| ☐ | Track | Notes | Owner |
|---|---|---|---|
| ☐ | **Code: music player** | An `AudioStreamPlayer` (looping stream, own bus so it can duck under the tick ladder) in `Sfx.gd` or a small `Music` autoload, plus start/stop hooks on `run_started` / `game_over`. Browsers block autoplay until a user gesture — the main-menu click already covers that, but it has to be tested in an actual export (plan §12 has this open). | |
| ☐ | **Menu loop** | Short, calm, loops cleanly. | |
| ☐ | **Shift loop** | The whole run plays under it. It has to sit *under* four overlapping tick voices without muddying them — sparse and low is safer than melodic. | |
| ☐ | **Escalation layer (stretch)** | `GameManager.get_difficulty()` already ramps 0→1; a second stem faded in against it would sell the panic. Only worth it if the base loop is done and tested. | |

Honest recommendation: the tick ladder *is* the soundtrack — it's how you read
the board without looking. Music is a stretch goal, and a bad music bed would
actively hurt the game. Do the SFX pass first.

---

# Text & dialog

**Every player-facing word in this game is hand-written by a human. Nothing
here is AI-generated, and nothing here gets AI-generated later.** That covers
station labels, button text, the fail screen, the menu gag, the easter-egg
dialog, the rocket word list — all of it. If a line needs rewriting, a person
rewrites it.

Practical reasons, not just principle:

- The jam's voice is the joke. The comedy is in specific, deliberate word
  choices ("NOT YOUR PROBLEM (YET)", "You were fired by:") and generated
  filler flattens exactly that.
- Judges read this copy. It is the most-seen "asset" in the game — every
  string is on screen for the whole run, unlike any single sprite.
- Several strings are load-bearing (see the ⚠ rows below); a rewrite that
  ignores the constraint breaks layout or gameplay, not just tone.

**If you take a writing pass:** rewrite in your own words, keep the length
budget, and note yourself in the Owner column. Don't paste in generated
alternatives "just to compare" — it contaminates the pass.

### Where the text actually lives

Unlike art and audio there is no assets folder — strings are inline in scenes
and scripts. This is the full map.

| ☐ | Where | What's in it | Notes | Owner |
|---|---|---|---|---|
| ☐ | `scenes/MainMenu.tscn` | Title, the one-paragraph pitch, "Clock in" / "Clock out", the debug hint | The pitch line is the only place the game explains itself. ⚠ Keep it short enough to not push the buttons off a 1280×720 layout. | |
| ☐ | `scripts/MainMenu.gd` → `GAG` | The GMTK / GAME JAM acronym gag that types itself out letter by letter | Two entries today. ⚠ Each letter costs `LETTER_DELAY` (0.09s) plus a `HOLD` of 1.1s, so a long acronym stalls the menu — and the expansion is drawn on one label, so watch the line breaks. Best spot in the game for more jokes; add entries, don't replace the mechanic. | |
| ☐ | `scenes/stations/*.tscn` | Station titles (`HOURGLASS`, `WIND-UP CLOCK`, `SAFE KEYPAD`, `ROCKET LAUNCH`), gauge captions (`SAND`, `TENSION`), `RE-LOCK`, the rocket's `Click the box, type the word, press Enter.` | ⚠ These sit inside the panel body — they get 596px of width per station, and a longer one clips. Check all four at once in the layout screenshot. | |
| ☐ | `scenes/stations/*.tscn` | `NOT YOUR PROBLEM (YET)` — the locked-station cover, 3 copies | ⚠ Drawn over `panel_locked.png`; change it in all three scenes or the stations disagree with each other. | |
| ☐ | `scripts/stations/RocketStation.gd` → `WORDS` | The launch countdown the player types: `ten … one`, `we have liftoff` | ⚠ **Gameplay, not flavour.** These get typed under time pressure — keep them short, unambiguous, and easy to spell. `next_label` upper-cases them. Length changes difficulty. | |
| ☐ | `scripts/stations/RocketStation.gd` | Console status lines: `NO LAUNCH SCHEDULED`, `standing by`, `standing by  (click to focus)`, `SAY: %s   (%d/%d)` | ⚠ BBCode with baked colour constants (`COLOR_TYPED` etc.) — edit the words, leave the tags. | |
| ☐ | `scripts/ConsoleWords.gd` → `WORDS` | Console/cheat words: `easter egg`, `cheat` | ⚠ Matched lowercase and trimmed. The docstring already lists candidates (`gmtk`, `fired`, `timekeeper`, `overtime`) — adding one is a one-line change. | |
| ☐ | `scenes/EasterEggDialog.tscn` + `EasterEggDialog.gd` | `You found an easter egg!`, `Every countdown is paused while you read this. You're welcome.`, `Back to work` | The default message is duplicated as a fallback arg in `EasterEggDialog.gd:18` — change both. This is the reward for curiosity; it should be worth finding. | |
| ☐ | `scenes/HUD.tscn` + `scripts/HUD.gd` | `SHIFT  00:00`, `SWITCHED!  +TIME  (%s)`, the `GAME JAM` / `ORIENTATION` header | ⚠ On screen the entire run. The dividend banner is the only positive feedback text in the game — make it feel like a reward. | |
| ☐ | `scenes/GameOver.tscn` + `scripts/GameOver.gd` | `YOU'RE FIRED`, `SHIFT SURVIVED`, `SERVICE POINTS`, `You were fired by: %s`, the per-station breakdown, `CHEATED -- not eligible for the high score`, `Another shift` / `Main menu` | ⚠ `STATION_NAMES` maps ids to display names, with the fallback `nobody, somehow`. The breakdown uses `%-14s` padding — a longer station name breaks the column alignment. Last screen a judge sees; worth the most polish per word. | |
| ☐ | `scenes/Main.tscn` | `MISTAKE` flash, the `SHIFT PAUSED` overlay | | |
| ☐ | `README.md` / itch.io page copy | Description, controls, credits | Not in-game, but it's the pitch. Same rule — hand-written. | |

`scripts/DebugPanel.gd` is dev-only and never shipped to a player, so its
strings don't need a writing pass.

### Also worth a human eye

| ☐ | Item | Notes | Owner |
|---|---|---|---|
| ☐ | **Tone pass across all four stations** | Read every string in one sitting. Right now the voice drifts between dry-corporate (`NOT YOUR PROBLEM (YET)`) and jokey (`You're welcome.`). Pick one and commit. | |
| ☐ | **Character coverage check** | Do this *after* the bitmap font lands (§6). Any em dash, curly quote or symbol a hand-written line introduces has to exist in the font, or it renders as a box. | |
