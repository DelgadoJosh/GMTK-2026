extends Node
## Temporary: prints real runtime rects for the station panels and their art
## slots so the ASSETS_TODO sizes can be checked. Delete after use.

func _ready() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.debug_unlock_overrides = {
		"hourglass": true, "clock": true, "safe": true, "rocket": true}
	await get_tree().process_frame
	for i in 6:
		await get_tree().process_frame
	print("VIEWPORT ", get_viewport().get_visible_rect().size)
	var hud := main.get_node("Root/HUD") as Control
	var grid := main.get_node("Root/StationGrid") as Control
	print("ROOT     ", (main.get_node("Root") as Control).size)
	print("HUD      ", hud.size)
	print("GRID     ", grid.size)
	for st in grid.get_children():
		var c := st as Control
		print("PANEL ", c.name, " ", c.size)
		_dump(c, c.name, 0)
	get_tree().quit()

func _dump(n: Node, path: String, depth: int) -> void:
	if depth > 5:
		return
	for child in n.get_children():
		if child is Control:
			var c := child as Control
			print("   ", "  ".repeat(depth), path, "/", c.name, "  size=", c.size,
				"  pos=", c.global_position)
			_dump(c, path + "/" + str(c.name), depth + 1)
