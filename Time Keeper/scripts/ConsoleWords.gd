class_name ConsoleWords
## The rocket text box doubles as a command console.
##
## Submitted text is trimmed and lowercased and checked against this table
## *before* the launch-word matcher, so a console word is never scored as a
## typo and never consumes the current target word. It works whether or not a
## launch window is open -- you shouldn't have to wait for a rocket to type a
## cheat.
##
## Adding another is a one-line change. Good candidates for later: your own
## name, `gmtk`, `fired`, `timekeeper`, `overtime`.

const WORDS := {
	"easter egg": "easter_egg",
	"cheat": "cheat",
}


## Returns the command id for a submission, or "" if it isn't a console word.
static func match_word(text: String) -> String:
	return str(WORDS.get(text.strip_edges().to_lower(), ""))
