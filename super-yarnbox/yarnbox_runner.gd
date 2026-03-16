extends Node2D
@onready var label: Label = $"../Label"

enum nodeState
{
	INACTIVE,
	SEARCHING,
	PROCESSING,
	CLOSING
}

# Properties
var markerIndex: int = 0
var dataArray: Array = []
var nodeDictionary: Dictionary = {}
var currentNodeState = nodeState.INACTIVE
var declairedVariables = {}

var characterName = ""
var dialogue = ""

# Checks if the yarn file is valid (simple method)
func validYarnFileCheck(filename: String):
	var hasTitle = false
	var hasTripleEqual = false
	var hasTripleDash = false
	var closedNodes = 0;
	
	# Open file
	var file = FileAccess.open(filename, FileAccess.READ)
	
	# Load file into data Array.
	while(!file.eof_reached()):
		var line = file.get_line()
		if(line.to_lower().find("title") != -1):
			hasTitle = true
		if(line.to_lower().find("---") != -1):
			closedNodes += 1
			hasTripleDash = true
		if(line.to_lower().find("===") != -1):
			closedNodes -= 1
			hasTripleEqual = true

	file.close()
	
	if(hasTitle == true && hasTripleEqual == true && hasTripleDash == true && closedNodes == 0):
		return true
	
	return false

# Loads yarn file into array and appends the data to the end of dataArray.
func loadYarnFile(filename: String):
	
	# Check if file exists
	if(!FileAccess.file_exists(filename)):
		return -1
	
	# Check if file type is yarn.
	if(!filename.ends_with("yarn")):
		print("Invalid file type.")
		return -1
	
	# Open file
	var file = FileAccess.open(filename, FileAccess.READ)
	
	# Check if there was an error loading the file.
	if(file == null):
		print("Error loading file.")
		return -1
	
	# Check if file is valid.
	if(!validYarnFileCheck(filename)):
		print("File detected as invalid format.")
		return -1;
	
	# Load file into data Array.
	while(!file.eof_reached()):
		var line = file.get_line()
		dataArray.append(line)
	
	file.close()
	return 1

# Prints the node titles. (debugging purposes)
func printNodeTitles():
	for line in dataArray:
		if(line.to_lower().find("title") != -1):
			print_rich("[color=gray]node:[/color] " + line.substr(line.find(":") + 1, line.length() - 1).replace(" ", ""))

# Indexes nodes to allow for quicker jumps.
func indexNodes():
	var indexNumber = 0
	
	for line in dataArray:
		
		if(line.to_lower().find("title") != -1):
			var nodeTitle = line.substr(line.find(":") + 1, line.length() - 1).replace(" ", "")
			nodeDictionary[nodeTitle] = indexNumber
			
		indexNumber += 1

func goToNode(targetNode: String):
	if(nodeDictionary.has(targetNode)):
		markerIndex = nodeDictionary[targetNode]
		currentNodeState = nodeState.PROCESSING

func continueLine():
	markerIndex += 1
	

func runDialogue(targetNode: String):
	
	match(currentNodeState):
		
		nodeState.INACTIVE: 
			return
			
		nodeState.PROCESSING: 
			
			# Check if this line is the end.
			if(dataArray[markerIndex].find("===") != -1):
				currentNodeState = nodeState.CLOSING
				return
			
			# Check if this is a regular line
			
			var splitLine;
			
			if(dataArray[markerIndex].find(":") != -1 && dataArray[markerIndex].find("Title") == -1):
				splitLine = dataArray[markerIndex].split(":", true, 0)
				characterName = splitLine[0].strip_edges()
				dialogue = splitLine[1].strip_edges()
			elif(dataArray[markerIndex].find("Title") != -1):
				continueLine();
			elif(dataArray[markerIndex].find("---") != -1):
				continueLine();
			elif(dataArray[markerIndex].find("<<") != -1 && dataArray[markerIndex].find(">>") != -1):
				if(dataArray[markerIndex].find("declare") != -1):
					splitLine = dataArray[markerIndex].split("=", true, 0)
					var variableName = splitLine[0].replace(" ", "").substr(splitLine[0].find("$"), splitLine[0].length() - 1)
					var variableValue = splitLine[1].replace(" ", "").replace(">>", "")
					print(variableValue)
					declairedVariables[variableName] = 0
					continueLine();
			elif(dataArray[markerIndex] == ""):
				continueLine();
			else:
				dialogue = dataArray[markerIndex]
			
			
		nodeState.CLOSING: 
			print("closing")
			currentNodeState = nodeState.INACTIVE
			return;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	loadYarnFile("testScript.yarn")
	
	# Unit Test 1 (Loads file): Passed
	for i in dataArray:
		print(i)
	
	# Unit Test 2 (Can print all node types): Passed
	printNodeTitles()
		
	indexNodes()
	
	print(nodeDictionary["TravelTogether"])
	
	goToNode("Start")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	runDialogue("Start")
	label.text = dialogue
	if(Input.is_action_just_pressed("Accept")):
		print("pressed")
		continueLine()
		
