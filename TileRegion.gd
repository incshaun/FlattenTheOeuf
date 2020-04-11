extends ColorRect

# Size of the grid.
var gridN : int = 5
var numEgg: int = 4
var rabbitSpeed : float = 2.0 # tiles per second.
var eggSpeed : float = 0.35 # tiles per second.

var populationSize : float = 1.0
var infected : float = 0.0
const decay : float = 0.01
const infectionRate : float = 0.02

enum GameOver { Running, LossCountdown, VictoryCountdown, GameOver }
var gameOverState = GameOver.Running
const lossTime = 10;
const winTime = 5;
var countdownTimer;

const tileScene = preload ("res://TileBackground.tscn")
const eggScene = preload ("res://EggPiece.tscn")
const bunnyScene = preload ("res://BunnyPiece.tscn")
const highlightScene = preload ("res://Highlight.tscn")

# Node with the infection chart.
var infectionChart
# Node with the text field.
var feedbackLabel

enum ObjectState { Static, Moving, Holding, Carrying, BeingCarried }

class MoveableObject:
	var region
	# the scene object being managed.
	var objInstance
	# the tile coordinates of the current position
	var objTilePosition
	
	# the state of the object
	var target
	# if heading towards object, then this is the target.
	var targetObject
	# if carrying an object, then this is the object.
	var carriedObject
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
		start = pos
		target = ObjectState.Static
		setPosition ()
		
	# update display position to match objTilePosition
	func setPosition ():
		objInstance.rect_position = objTilePosition * Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size
		objInstance.rect_size = Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size

	func move (delta, speed):
		# If tracking an object, then update end position.
		if targetObject != null:
			end = targetObject.objTilePosition
			
		# Take a step towards the end position.
#		print ("VV", end, start)
		var distance = (end - start).length ()
		if distance > 0:
			progress += delta * speed / distance
		else:
			progress = 1.0
			
		# If reached the target, take actions based on state.
		if progress >= 1.0:
			progress = 1.0
			start = end
			objTilePosition = start + progress * (end - start)
			objTilePosition = Vector2 (round (objTilePosition.x), round (objTilePosition.y))
			
#			print ("At tp ", objTilePosition)
			if targetObject != null and target == ObjectState.Moving:
				target = ObjectState.Holding
				carriedObject = targetObject
				carriedObject.target = ObjectState.BeingCarried
				carriedObject.objInstance.visible = false
				targetObject = null
			elif carriedObject != null and target == ObjectState.Carrying:
				target = ObjectState.Static
				carriedObject.objTilePosition = objTilePosition
				carriedObject.setPosition ()
				carriedObject.objInstance.visible = true
				carriedObject.target = ObjectState.Static
				carriedObject = null
			else:
				target = ObjectState.Static
		else:
			objTilePosition = start + progress * (end - start)
		setPosition ()

var allEggs = []
var bunny
var highlight
var highlightedEgg = null

# Select a single egg and set the highlight on that, if the click
# point is close enough to it.
func highlightEgg (tilePos):
	var closestEgg = null
	var closestDistance = null
	for egg in allEggs:
		if egg.target == ObjectState.Static or egg.target == ObjectState.Moving:
			var dist = (egg.objTilePosition + Vector2 (0.5, 0.5) - tilePos).length ()
			if closestEgg == null or dist < closestDistance:
				closestEgg = egg
				closestDistance = dist
	
	highlightedEgg = null
	highlight.visible = false
	if highlight.get_parent () != null:
		highlight.get_parent ().remove_child (highlight)
	if closestEgg != null and closestDistance < 0.5:
		closestEgg.objInstance.add_child (highlight)
		highlight.rect_position = Vector2 (0, 0)
		highlight.visible = true
		highlightedEgg = closestEgg

# All pairs of overlapping eggs contribute to the infection rate.
# Infection slowly recovers.
func updateInfection (delta):
	var susceptible = populationSize - infected
	for egg in allEggs:
		if egg.target == ObjectState.Static:
			for otherEgg in allEggs:
				if otherEgg != egg and otherEgg.target == ObjectState.Static:
					var pdistance = (egg.objTilePosition - otherEgg.objTilePosition).length ()
					if pdistance < 0.1:
						infected += infectionRate * ((infected + 0.01) * susceptible) * delta

	infected -= infected * decay * delta
	infectionChart.addPoint (infected, delta)

# Check to see if eggs are all stable.
func stableEggScenario ():
	var stable = true
	for egg in allEggs:
		if egg.target == ObjectState.Static:
			for otherEgg in allEggs:
#				print ("E ", egg, otherEgg)
				if egg != otherEgg:
					if otherEgg.target == ObjectState.Static:
						var posDiff = egg.objTilePosition - otherEgg.objTilePosition
						var pdx = int (posDiff.x)
						var pdy = int (posDiff.y)
#						print ("PD " +  str (pdx) + " " + str (pdy) + " " + str (posDiff))
						if (pdx == 0 and pdy == 0) or (pdx == 0 and pdy != 0) or (pdx != 0 and pdy == 0) or (pdx != 0 and abs (pdx) == abs (pdy)):
							stable = false
							break
					else:
						stable = false
						break
		else:
			stable = false
			break
#	print ("St ", stable)
	return stable

# Manage victory and loss situation
func checkEndConditions (delta):
	if gameOverState == GameOver.Running:
#		print ("II", infected, infectionChart.threshold)
		if infected > infectionChart.threshold:
			gameOverState = GameOver.LossCountdown
			countdownTimer = lossTime
		elif infected < infectionChart.threshold:
			if stableEggScenario ():
				gameOverState = GameOver.VictoryCountdown
				countdownTimer = 0 # count up in this case.
	elif gameOverState == GameOver.LossCountdown:
		countdownTimer -= delta
		feedbackLabel.text = str (int (countdownTimer))
		feedbackLabel.set ("custom_colors/font_color", Color (1,0,0))
		if countdownTimer <= 0:
			feedbackLabel.text = "Resistance oeuferwhelmed!"
			gameOverState = GameOver.GameOver
		elif infected < infectionChart.threshold:
			gameOverState = GameOver.Running
			feedbackLabel.text = ""
	elif gameOverState == GameOver.VictoryCountdown:
		countdownTimer += delta
		feedbackLabel.text = str (int (countdownTimer))
		feedbackLabel.set ("custom_colors/font_color", Color (0,1,0))
		if countdownTimer > winTime:
			feedbackLabel.text = "Victory! Game oeufre"
			gameOverState = GameOver.GameOver
		elif not stableEggScenario ():
			gameOverState = GameOver.Running
			feedbackLabel.text = ""
	else:
		pass

# The body of the game loop
func playGame (delta):
	# Move the rabbit.
	if bunny.target == ObjectState.Moving or bunny.target == ObjectState.Carrying:
		bunny.move (delta, rabbitSpeed)
		
	updateInfection (delta)
	
	checkEndConditions (delta)
		
	# Find any eggs that can move.
	for egg in allEggs:
		if egg.target == ObjectState.Static:
			# stationary egg. See if any other stationary eggs are in sight.
			# if so, find the closest.
			var bestOther = null
			var bestDistance = null
			for otherEgg in allEggs:
				if otherEgg != egg and otherEgg.target == ObjectState.Static:
					var posDiff = egg.objTilePosition - otherEgg.objTilePosition
					var pdx = int (posDiff.x)
					var pdy = int (posDiff.y)
					var pdistance = posDiff.length ()
					if (pdx == 0 and pdy != 0) or (pdx != 0 and pdy == 0) or (pdx != 0 and abs (pdx) == abs (pdy)):
#						print ("Valid target ", egg, otherEgg)
						if bestOther == null or pdistance < bestDistance:
							bestOther = otherEgg
							bestDistance = pdistance
			if bestOther != null:
				egg.target = ObjectState.Moving
				egg.end = bestOther.objTilePosition
				egg.start = egg.objTilePosition
				egg.progress = 0.0

	# Move the eggs.
	for egg in allEggs:
		if egg.target == ObjectState.Moving:
			egg.move (delta, eggSpeed)
	
func _ready():

	infectionChart = get_parent ().get_node ("InfectionChart")
	feedbackLabel = get_parent ().get_node ("FeedbackLabel")
	feedbackLabel.text = ""
	
	highlight = highlightScene.instance ()
	highlight.rect_size = Vector2 (1.0 / gridN, 1.0 / gridN) * rect_size
	highlight.visible = false
	add_child (highlight)
	
	print ("Ready")
	# place a grid of tiles.
	for y in range (gridN):
		for x in range (gridN):
			var tile = tileScene.instance ()
			tile.rect_position = Vector2 (float (x) / gridN, float (y) / gridN) * rect_size
			tile.rect_size = Vector2 (1.0 / gridN, 1.0 / gridN) * rect_size
			add_child (tile)
#			print ("Tile", tile.rect_position)

	for i in range (numEgg):
		var egg = MoveableObject.new (eggScene.instance (), Vector2 (randi () % gridN, randi () % gridN), self)
		allEggs.append (egg)
		add_child (egg.objInstance)
	
	bunny = MoveableObject.new (bunnyScene.instance (), Vector2 (gridN / 2, gridN / 2), self)
	bunny.start = bunny.objTilePosition
	add_child (bunny.objInstance)
	
func _process(delta):
	if gameOverState == GameOver.Running or gameOverState == GameOver.LossCountdown or gameOverState == GameOver.VictoryCountdown:
		playGame (delta)

func _input(event):
	if event is InputEventMouseMotion:
		if bunny.target == ObjectState.Static:
			highlightEgg (((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size))
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			var tilePosition = ((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size)
			var intTilePosition = Vector2 (int (tilePosition.x), int (tilePosition.y))
			if event.pressed:
				print("Left button was clicked at ", event.position, tilePosition, intTilePosition)
				if bunny.target == ObjectState.Static:
					highlightEgg (((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size))
					bunny.end = intTilePosition
					bunny.target = ObjectState.Moving
					bunny.targetObject = highlightedEgg
					bunny.progress = 0.0
				if bunny.target == ObjectState.Holding:
					bunny.end = intTilePosition
					bunny.target = ObjectState.Carrying
					bunny.targetObject = null
					bunny.progress = 0.0

