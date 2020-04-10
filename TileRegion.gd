extends ColorRect

# Size of the grid.
var gridN : int = 5
var numEgg: int = 4
var rabbitSpeed : float = 2.0 # tiles per second.
var eggSpeed : float = 1.5 # tiles per second.

const tileScene = preload ("res://TileBackground.tscn")
const eggScene = preload ("res://EggPiece.tscn")
const bunnyScene = preload ("res://BunnyPiece.tscn")

class MoveableObject:
	var region
	# the scene object being managed.
	var objInstance
	# the tile coordinates of the current position
	var objTilePosition
	
	# the state of the object
	var target
	# end point if moving.
	var end
	# start point while moving
	var start
	# how far along move, while moving
	var progress
	
	# constructor.
	func _init (i, pos, reg):
		region = reg
		objInstance = i
		objTilePosition = pos
		setPosition ()
		
	# update display position to match objTilePosition
	func setPosition ():
		objInstance.rect_position = objTilePosition * Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size
		objInstance.rect_size = Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size

	func move (delta, speed):
		var distance = (end - start).length ()
		progress += delta * speed / distance
		if progress >= 1.0:
			progress = 1.0
			target = null
			start = end
		objTilePosition = start + progress * (end - start)
		setPosition ()

var allEggs = []
var bunny

var rabbitTarget = null
var rabbitStart = null
var rabbitEnd = null
var rabbitProgress = 0.0

func _ready():
	
	print ("Ready")
	# place a grid of tiles.
	for y in range (gridN):
		for x in range (gridN):
			var tile = tileScene.instance ()
			tile.rect_position = Vector2 (float (x) / gridN, float (y) / gridN) * rect_size
			tile.rect_size = Vector2 (1.0 / gridN, 1.0 / gridN) * rect_size
			add_child (tile)
			print ("Tile", tile.rect_position)

	for i in range (numEgg):
		var egg = MoveableObject.new (eggScene.instance (), Vector2 (randi () % gridN, randi () % gridN), self)
		allEggs.append (egg)
		add_child (egg.objInstance)
	
	bunny = MoveableObject.new (bunnyScene.instance (), Vector2 (gridN / 2, gridN / 2), self)
	bunny.start = bunny.objTilePosition
	add_child (bunny.objInstance)
	
func _process(delta):
	# Move the rabbit.
	if bunny.target != null:
		bunny.move (delta, rabbitSpeed)
		
	# Find any eggs that can move.
	for egg in allEggs:
		if egg.target == null:
			# stationary egg. See if any other stationary eggs are in sight.
			# if so, find the closest.
			var bestOther = null
			var bestDistance = null
			for otherEgg in allEggs:
				if otherEgg != egg and otherEgg.target == null:
					var posDiff = egg.objTilePosition - otherEgg.objTilePosition
					var pdx = int (posDiff.x)
					var pdy = int (posDiff.y)
					var pdistance = posDiff.length ()
					if (pdx == 0 and pdy != 0) or (pdx != 0 and pdy == 0) or (pdx != 0 and abs (pdx) == abs (pdy)):
						print ("Valid target ", egg, otherEgg)
						if bestOther == null or pdistance < bestDistance:
							bestOther = otherEgg
							bestDistance = pdistance
			if bestOther != null:
				egg.target = 1
				egg.end = bestOther.objTilePosition
				egg.start = egg.objTilePosition
				egg.progress = 0.0

	# Move the eggs.
	for egg in allEggs:
		if egg.target != null:
			egg.move (delta, eggSpeed)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			var tilePosition = ((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size)
			var intTilePosition = Vector2 (int (tilePosition.x), int (tilePosition.y))
			if event.pressed:
				print("Left button was clicked at ", event.position, tilePosition, intTilePosition)
				if bunny.target == null:
					bunny.end = intTilePosition
					bunny.target = 1
					bunny.progress = 0.0

func _draw():
    draw_line(Vector2(0,0), Vector2(50, 50), Color(255, 0, 0), 1)
