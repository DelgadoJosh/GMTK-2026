extends InfoPanel
## Credits, opened from the title card.
##
## The audio attributions live in an exported string rather than in this file
## on purpose: licence text is pasted verbatim, often contains brackets, quotes
## and URLs, and should never be something you have to escape into GDScript to
## add. Edit `audio_attribution` on the Credits node in the Godot inspector --
## it is a multi-line field, so paste straight into it. Anything pasted there is
## BBCode-escaped before it is drawn.

const TITLE := "TIME KEEPER"
const MADE_FOR := "Made for the GMTK Game Jam 2026"

## Kept as an export rather than a const so the whole file stays untouched when
## a sound is swapped. One block per source; the format is entirely yours.
@export_multiline var audio_attribution: String = ""


func _build() -> String:
	var out := PackedStringArray()

	out.append("[color=%s][b]%s[/b][/color]\n[color=%s]%s[/color]"
		% [GOLD, TITLE, DIM, MADE_FOR])

	out.append(_entry("PROGRAMMING & ART", "4Penguins"))
	out.append(_entry("GAME JAM", "Game Maker's Toolkit"))
	out.append(_entry("PLAYTESTERS", "Family"))

	var audio := audio_attribution.strip_edges()
	if audio == "":
		# Visible, and obviously a placeholder rather than a claim of ownership.
		audio = ("[color=%s][i]No third-party audio credited yet. Attributions go"
			+ " in the Credits node's audio_attribution field.[/i][/color]") % DIM
	else:
		audio = escape(audio)
	out.append(_entry("AUDIO", audio))

	return "\n\n".join(out)


## A heading sits directly on top of its value, with the blank line only between
## sections. Credits that double-space every line scroll before the audio
## section is even on screen.
func _entry(heading: String, value: String) -> String:
	return _heading(heading) + "\n" + value
