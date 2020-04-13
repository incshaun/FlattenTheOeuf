extends ColorRect

# Size of the grid.
var gridN : int = 5
var numEgg: int = 4
var rabbitSpeed : float = 2.0 # tiles per second.
var eggSpeed : float = 0.35 # tiles per second.

var populationSize : float = 1.0
var infected : float = 0.0
var decay : float = 0.01
var infectionRate : float = 0.02

enum GameOver { Running, LossCountdown, VictoryCountdown, GameOver }
var gameOverState = GameOver.GameOver
var lossTime = 10;
var winTime = 5;
var countdownTimer;

const tileScene = preload ("res://TileBackground.tscn")
const eggScene = preload ("res://EggPiece.tscn")
const bunnyScene = preload ("res://BunnyPiece.tscn")
const highlightScene = preload ("res://Highlight.tscn")

# Node with the infection chart.
var infectionChart
# Node with the text field.
var feedbackLabel
# Controls container, for managing settings outside of game play
var controlsContainer
# Button with level select options.
var levelSelectButton
# Video player panel
var controlMovie
var videoPlayer
# High score
var achievementLabel

class LevelDescription:
	var levelname
	var rank
	var gridN
	var numEgg
	var rabbitSpeed
	var eggSpeed
	var decay
	var infectionRate
	var lossTime
	var winTime
	
	func _init (n, r, g, ne, rs = 2.0, es = 0.35, de = 0.01, inf = 0.02, lt = 10, wt = 5):
		levelname = n
		rank = r
		gridN = g
		numEgg = ne
		rabbitSpeed = rs
		eggSpeed = es
		decay = de
		infectionRate = inf
		lossTime = lt
		winTime = wt

	func setConditions (gameObject):
		gameObject.gridN = gridN
		gameObject.numEgg = numEgg
		gameObject.rabbitSpeed = rabbitSpeed
		gameObject.eggSpeed = eggSpeed
		gameObject.decay = decay
		gameObject.infectionRate = infectionRate
		gameObject.lossTime = lossTime
		gameObject.winTime = winTime

var levels = [ \
  LevelDescription.new ("Tutorial", "Leghorn", 3, 2, 2.0, 0.01), \
  LevelDescription.new ("Over Easy", "Sous Chef", 5, 3, 2.0, 0.5), \
  LevelDescription.new ("Scrambled", "Dasypeltis scabra", 5, 4, 2.0, 0.75), \
  LevelDescription.new ("Oogenera", "Paleggontologist", 10, 8, 2.0, 0.75), \
  LevelDescription.new ("Omelette", "Deakin Game Development Graduate", 6, 6, 2.0, 0.75), \
]
# current level played.
var currentLevel = 0
# best level completed.
var bestLevel = -1

enum ObjectState { Static, Moving, Holding, Carrying, BeingCarried }

class MoveableObject:
	var region
	# the scene object being managed.
	var objInstance
	# the tile coordinates of the current position
	var objTilePosition
	
	# texture array.
	var textures
	
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
	func _init (i, pos, reg, texs = null):
		region = reg
		objInstance = i
		objTilePosition = pos
		start = pos
		target = ObjectState.Static
		textures = texs
		setPosition ()
		
	# update display position to match objTilePosition
	func setPosition ():
		objInstance.rect_position = objTilePosition * Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size
		objInstance.rect_size = Vector2 (1.0 / region.gridN, 1.0 / region.gridN) * region.rect_size

	func move (delta, speed):
		# If tracking an object, then update end position.
		if targetObject != null:
			end = targetObject.objTilePosition
		
		if textures != null:
			var texIndex = 0
			if end != null and start != null:
				var direction = end - start

				if direction.length () > 0.0:
					var angle = atan2 (direction.y, direction.x) / PI
					if angle < -0.62:
						texIndex = 7
					elif angle < -0.37:
						texIndex = 6
					elif angle < -0.12:
						texIndex = 5
					elif angle < 0.12:
						texIndex = 4
					elif angle < 0.37:
						texIndex = 3
					elif angle < 0.62:
						texIndex = 2
					elif angle < 0.87:
						texIndex = 1
					else:
						texIndex = 0
				
			objInstance.texture = textures[texIndex]
			if target == ObjectState.Holding or target == ObjectState.Carrying:
				objInstance.texture = textures[texIndex + 8]

		if target == ObjectState.Moving or target == ObjectState.Carrying:
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
		egg.objInstance.get_node ("EggParticles").visible = false
		if egg.target == ObjectState.Static:
			for otherEgg in allEggs:
				if otherEgg != egg and otherEgg.target == ObjectState.Static:
					var pdistance = (egg.objTilePosition - otherEgg.objTilePosition).length ()
					if pdistance < 0.1:
						egg.objInstance.get_node ("EggParticles").visible = true
						egg.objInstance.get_node ("EggParticles").speed_scale = 0.1 + 2.0 * infected
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
		feedbackLabel.text = ""
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
			feedbackLabel.text = "Defences oeuferwhelmed!"
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
			if currentLevel > bestLevel:
				bestLevel = currentLevel
				achievementLabel.text = "Best rank:\n" + levels[bestLevel].rank
		elif not stableEggScenario ():
			gameOverState = GameOver.Running
			feedbackLabel.text = ""
	else:
		pass

# The body of the game loop
func playGame (delta):
	# Move the rabbit.
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
		egg.move (delta, eggSpeed)
	
func setupGame ():
	print ("Ready")
	
	currentLevel = levelSelectButton.get_selected_id ()
	var level = levels [currentLevel]
	level.setConditions (self)
	
	infected = 0.0
	
	# clear any remants of previous game.
	for n in get_children ():
		remove_child (n)
		n.queue_free ()
	allEggs = []
	
	infectionChart.reset ()
	
	# add highlight marker
	highlight = highlightScene.instance ()
	highlight.rect_size = Vector2 (1.0 / gridN, 1.0 / gridN) * rect_size
	highlight.visible = false	
	add_child (highlight)

	# place a grid of tiles.
	for y in range (gridN):
		for x in range (gridN):
			var tile = tileScene.instance ()
			tile.rect_position = Vector2 (float (x) / gridN, float (y) / gridN) * rect_size
			tile.rect_size = Vector2 (1.0 / gridN, 1.0 / gridN) * rect_size
			add_child (tile)
#			print ("Tile", tile.rect_position)

	# place eggs
	for i in range (numEgg):
		var egg = MoveableObject.new (eggScene.instance (), Vector2 (randi () % gridN, randi () % gridN), self)
		allEggs.append (egg)
		add_child (egg.objInstance)
	
	# place player
	bunny = MoveableObject.new (bunnyScene.instance (), Vector2 (gridN / 2, gridN / 2), self, [\
	preload ("res://bunny1.png"), \
	preload ("res://bunny2.png"), \
	preload ("res://bunny3.png"), \
	preload ("res://bunny4.png"), \
	preload ("res://bunny5.png"), \
	preload ("res://bunny6.png"), \
	preload ("res://bunny7.png"), \
	preload ("res://bunny8.png"), \
	preload ("res://bunnycarry1.png"), \
	preload ("res://bunnycarry2.png"), \
	preload ("res://bunnycarry3.png"), \
	preload ("res://bunnycarry4.png"), \
	preload ("res://bunnycarry5.png"), \
	preload ("res://bunnycarry6.png"), \
	preload ("res://bunnycarry7.png"), \
	preload ("res://bunnycarry8.png") \
	])
	bunny.start = bunny.objTilePosition
	add_child (bunny.objInstance)

func addLevels ():
	levelSelectButton.clear ()
	for l in levels:
		levelSelectButton.add_item (l.levelname)

func _ready():

	infectionChart = get_parent ().get_node ("InfectionChart")
	feedbackLabel = get_parent ().get_node ("FeedbackLabel")
	feedbackLabel.text = ""
	controlsContainer = get_parent ().get_node ("ControlBox")
	levelSelectButton = get_parent ().get_node ("ControlBox/LevelSelectButton")
	addLevels ()
	controlMovie = get_parent ().get_node ("ControlMovie")
	videoPlayer = get_parent ().get_node ("ControlMovie/VideoPlayer")
	achievementLabel = get_parent ().get_node ("ControlBox/AchievementLabel")
	
func _process(delta):
	
	visible = false
	controlsContainer.visible = false
	
	if gameOverState == GameOver.Running or gameOverState == GameOver.LossCountdown or gameOverState == GameOver.VictoryCountdown:
		visible = true
		playGame (delta)
	elif gameOverState == GameOver.GameOver:
		controlsContainer.visible = true

func _input(event):
	if gameOverState == GameOver.Running or gameOverState == GameOver.LossCountdown or gameOverState == GameOver.VictoryCountdown:
		if event is InputEventMouseMotion:
			if bunny.target == ObjectState.Static:
				highlightEgg (((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size))
		if event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				var tilePosition = ((event.position - rect_position) * Vector2 (gridN, gridN) / rect_size)
				var intTilePosition = Vector2 (max (min (int (tilePosition.x), gridN), 0), max (min (int (tilePosition.y), gridN), 0))
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

func On_StartButton_pressed():
	gameOverState = GameOver.Running
	setupGame ()

func stopIntro ():
	videoPlayer.stop ()
	controlMovie.visible = false
	
func startIntro ():
	controlMovie.visible = true
	videoPlayer.play ()
	
func On_VideoPlayer_finished():
	stopIntro ()
