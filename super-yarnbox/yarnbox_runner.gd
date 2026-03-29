extends Node2D
@onready var label: Label = $"../Label"
@onready var label_2: Label = $"../Label2"

enum nodeState
{
	INACTIVE,
	PROCESSING,
	STOPPED,
	CLOSING
}

# Question data. using this as a glorified packet.
class questionData:
	var questionText = ""
	var questionIndex = 0
	var maxLines = 0
	
	# Initialize a new question
	func _init(_questionText: String = "", _questionIndex: int = 0):
		questionText = _questionText
		questionIndex = _questionIndex
		
	func getText():
		return questionText
	
	func getIndex():
		return questionIndex
		
	func setMaxLines(_maxLines):
		maxLines = _maxLines
		
	func getMaxLines():
		return maxLines

class ifStatementData:
	var leftVar = null
	var rightVar = null
	var operator = null
	var index = null
	var elseFlag = false
	
	# Initialize a new question
	func _init(_leftVar = null, _rightVar = null, _operator = null, _index = 0, _elseFlag = false):
		leftVar = _leftVar
		rightVar = _rightVar
		operator = _operator
		index = _index
		elseFlag = _elseFlag
		
	func getIndex():
		return index

# Properties
var markerIndex: int = 0
var dataArray: Array = []
var nodeDictionary: Dictionary = {}
var currentNodeState = nodeState.INACTIVE
var declairedVariables = {}
var questionsArray: Array = []
var parentIndention = 0
var characterName = ""
var dialogue = ""
var questionContinueHistory : Array = []
var questionMaxLines : Array = []

# TODO: I'll come back for this. it's an optimization feature so it can come later
# Convert all actions into dictionary look ups
var actionsTable: Dictionary = {
	"===" : tripleEquals()
	
}

func tripleEquals():
	print("I did it.")

var statementTable: Dictionary = {}

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
		if(line.to_lower().find("---") != -1 || line.to_lower().find("if")):
			closedNodes += 1
			hasTripleDash = true
		if(line.to_lower().find("===") != -1 || line.to_lower().find("endif")):
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
	
	indexNodes()
	
	return 1

# Prints the node titles. (debugging purposes)
func printNodeTitles():
	for line in dataArray:
		if(line.to_lower().find("title") != -1):
			print_rich("[color=gray]node:[/color] " + line.substr(line.find(":") + 1, line.length() - 1).replace(" ", ""))

# Returns indent before last tab block
func getParentIndent():
	return parentIndention

# Updates indent to the current indent
func updateParentIndent():
	parentIndention = abs(dataArray[markerIndex - 1].count("\t") - dataArray[markerIndex - 1].count("    "))

# Returns indent of current line
func getCurrentIndent():
	var line = dataArray[markerIndex]
	var indent = 0

	for i in line.length():
		if line[i] == "\t":
			indent += 1
		elif line[i] == " ":
			indent += 0.25  
		else:
			break

	return int(indent)

# Indexes nodes to allow for quicker jumps.
func indexNodes():
	var indexNumber = 0
	
	for line in dataArray:
		
		if(line.to_lower().find("title") != -1):
			var nodeTitle = line.substr(line.find(":") + 1, line.length() - 1).replace(" ", "")
			nodeDictionary[nodeTitle] = indexNumber
			
		indexNumber += 1

# Goes to target node. 
# If it doesn't exist it closes the dialogue out.
func goToNode(targetNode: String):
	if(nodeDictionary.has(targetNode)):
		markerIndex = nodeDictionary[targetNode]
		currentNodeState = nodeState.PROCESSING
		print("going to: " + targetNode)
		
		#If you're doing a node jump then pop back that question history
		questionMaxLines.pop_back()
		questionContinueHistory.pop_back()
	else:
		currentNodeState = nodeState.CLOSING

# Goes to target line
# If the line doesn't exist it closes the dialogue out
func jumpToLine(targetLine: int):
	if(targetLine <= dataArray.size()):
		markerIndex = targetLine
	else:
		currentNodeState = nodeState.CLOSING

# Increments index marker and manages question history blocks
func continueLine():
	# Clear character name and dialogue.
	markerIndex += 1
	
	# If there is a question history block then update that too
	if(questionMaxLines.size() != 0):
		questionMaxLines[questionMaxLines.size() - 1] -= 1
		if(questionMaxLines[questionMaxLines.size() - 1] < 0):
			questionMaxLines.pop_back()
			jumpToLine(questionContinueHistory[questionContinueHistory.size() - 1])
			questionContinueHistory.pop_back()

# Resets index marker back to zero
func resetMarkerIndex():
	markerIndex = 0

# Processes questions so that they can be used by the system
func processQuestions():
	var questionIndent = getCurrentIndent()
	var questionMaxCounter = 0
	
	# Collect questions (question block ends if we go back to parent indention
	while(getCurrentIndent() >= questionIndent):
		if(getCurrentIndent() == questionIndent):
			if(dataArray[markerIndex].contains("->")):
				var strippedQuestion = dataArray[markerIndex].replace("->", "").strip_edges()
				questionsArray.push_back(questionData.new(strippedQuestion, markerIndex))
				if(questionsArray.size() > 0):
					questionsArray[questionsArray.size() - 2].setMaxLines(questionMaxCounter)
					questionMaxCounter = 0
			else:
				questionsArray[questionsArray.size() - 1].setMaxLines(questionMaxCounter)
				break
		else:
			questionMaxCounter += 1
		
		continueLine()	
	
	questionContinueHistory.push_back(markerIndex)

	# TODO: Debug print questions
	for question in questionsArray:
		print(question.getText())
	
	# Stop the node from proceeding until question is chosen
	currentNodeState = nodeState.STOPPED

# Performs operations on string values.
func performOperation(leftVar: float, operator, rightVar: float):
	match operator:
		"=", "to":
			return rightVar
		"+=":
			return leftVar + rightVar
		"-=":
			return leftVar - rightVar
		"*=":
			return leftVar * rightVar
		"/=":
			if(leftVar != 0 && rightVar != 0):
				return leftVar / rightVar
		_:
			push_error("Unknown operator")
			return leftVar

# Performs operation on if statements in strings
func performIfStatement(leftVar, determanator, rightVar):
	var left_num : float = 0
	var right_num : float = 0
	var numeric_comparison = false

	# Attempt numeric conversion
	if typeof(leftVar) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		if typeof(rightVar) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			# Try converting to float
			left_num = float(str(leftVar))
			right_num = float(str(rightVar))
			numeric_comparison = true
	else:
		numeric_comparison = false

	match determanator:
		"==", "is":
			return leftVar == rightVar
		"!=":
			return leftVar != rightVar
		"<":
			if numeric_comparison:
				return left_num < right_num
			else:
				return str(leftVar) < str(rightVar)
		">":
			if numeric_comparison:
				return left_num > right_num
			else:
				return str(leftVar) > str(rightVar)
		"<=":
			if numeric_comparison:
				return left_num <= right_num
			else:
				return str(leftVar) <= str(rightVar)
		">=":
			if numeric_comparison:
				return left_num >= right_num
			else:
				return str(leftVar) >= str(rightVar)
		_:
			push_error("Unknown operator: " + str(determanator))
			return false

# Returns if the system has stopped or not
func isStopped():
	return currentNodeState == nodeState.STOPPED

# Returns questions array
func getQuestions():
	return questionsArray

# Returns number of questions
func getQuestionCount():
	return questionsArray.size()

# Returns who is speaking
func getSpeaker():
	return characterName

# Returns the current dialogue
func getDialogue():
	return dialogue

# Submits returned question for the engine
func chooseQuestion(chooseIndex):
	if(questionsArray.size() == 0):
		return
	
	if(chooseIndex >= questionsArray.size()):
		jumpToLine(questionsArray[questionsArray.size() - 1].getIndex())
	else:
		jumpToLine(questionsArray[chooseIndex].getIndex())
	
	questionMaxLines.push_back(questionsArray[chooseIndex].getMaxLines())
	currentNodeState = nodeState.PROCESSING
	continueLine()
	questionsArray.clear()

# Skips unbalanced if statement blocks (flow solution)
func skipIfStatement():
	while(markerIndex <= dataArray.size() && !dataArray[markerIndex].contains("endif")):
		continueLine()
	continueLine()
	print("Skipped rest of block.")

# The brains of the operation. This runs the loaded in dialog.
func runDialogue():
	
	var line = dataArray[markerIndex]
	
	match(currentNodeState):
		
		nodeState.STOPPED:
			return
		
		nodeState.INACTIVE: 
			return
			
		nodeState.PROCESSING: 
			
			var splitLine;
			
			# Check if this line is the end.
			if(line.contains("===") || markerIndex >= dataArray.size()):
				currentNodeState = nodeState.CLOSING
				return
			
			# Detect a line with a name.
			if(line.contains(":") && !line.containsn("title")):
				splitLine = line.split(":", true, 0)
				characterName = ""
				dialogue = ""
				characterName = splitLine[0].strip_edges()
				dialogue = splitLine[1].strip_edges()
			# Detect a node's title.
			elif(line.containsn("title")):
				continueLine()
			# Skip comments of blank lines.	
			elif(line == "" || line.contains("//")):
				continueLine()
			# Detect the beginning of a node
			elif(line.contains("---")):
				continueLine();
			# Detect any code blocks.
			elif(line.contains("<<") && line.contains(">>")):
				
				# Creates a new defined variable
				if(line.contains("declare")):
					splitLine = line.split("=", true, 0)
					var variableName = splitLine[0].replace(" ", "").substr(splitLine[0].find("$"), splitLine[0].length() - 1)
					var variableValue = splitLine[1].replace(">>", "").replace(" ", "")
					declairedVariables[variableName] = variableValue
				if(line.contains("endif")):
					continueLine()
				if(line.contains("elif") || line.contains("else")):
					print("skipping broken if statement...")
					skipIfStatement()
				# Jumps to a defined node line
				elif(line.contains("jump")):
					var jumpLocation = line.replace("jump", "").replace(" ", "")
					jumpLocation = jumpLocation.replace("<<", "").replace(">>", "")
					goToNode(jumpLocation)
				# Sets a pre declaired varaible
				elif(line.contains("set")):
					while(line.contains("set")):
						# Get variable name
						var variableExpression = line.replace("<<", "").replace(">>", "").replace("$", "").replace("set", "")
						var variableParts = variableExpression.split(" ", false, 0)
						
						# Only execute if the variable exists.
						if(declairedVariables.has(variableParts[0])):
							var leftVar = int(declairedVariables[variableParts[0]])
							var rightVar = int(variableParts[2])
							var operator = variableParts[1]
							declairedVariables[variableParts[0]] = performOperation(leftVar, operator, rightVar)
						else:
							print_rich("[color=red]varaible has not been declaired...[/color]")
						
						# Moves the line so we can check if the next line has a set varaible before returning.
						continueLine();
						line = dataArray[markerIndex]
					return
				# Determinates an if block.
				elif(line.contains("if")):
					var statements: Array = []
					
					# Collect all if statements in block
					while(!line.contains("endif")):
						var variableExpression = line.replace("<<", "").replace(">>", "").replace("$", "").replace("if", "").replace("elif", "")
						var variableParts = variableExpression.split(" ", false, 0)
						var leftVar = null
						var rightVar = null
						var operator = null
						
						if(variableParts.size() == 3):
							leftVar = variableParts[0]
							rightVar = variableParts[2]
							operator = variableParts[1]
							
						if(line.contains("if") || line.contains("elif")):
							statements.push_back(ifStatementData.new(leftVar, rightVar, operator, markerIndex, false))
						elif(line.contains("else")):
							statements.push_back(ifStatementData.new(null, null, null, markerIndex, true))
						
						continueLine()
						
						# If there is a question history box then update that too but negatively this time
						if(questionMaxLines.size() != 0):
							questionMaxLines[questionMaxLines.size() - 1] += 1
						
						line = dataArray[markerIndex]
					
					# Test all if statements until you have a winner
					for statement in statements:
						if(statement.elseFlag == true):
							jumpToLine(statement.getIndex())
							break
						
						if(declairedVariables.has(statement.leftVar)):
							if(performIfStatement(declairedVariables[statement.leftVar], statement.operator, statement.rightVar)):
								jumpToLine(statement.getIndex())
								break
					
					# If there is no winner and no else statement continue on as if nothing happened...
					
				# continue line after any case.
				continueLine();
			# Process question and pause
			elif(line.contains("->")):
				updateParentIndent()
				processQuestions()
			# Default behavior. Just print the darn thing.
			else:
				characterName = ""
				dialogue = ""
				dialogue = dataArray[markerIndex].strip_edges()
			
		nodeState.CLOSING: 
			print("closing")
			dialogue = ""
			characterName = ""
			questionMaxLines.clear()
			questionContinueHistory.clear()
			resetMarkerIndex()
			currentNodeState = nodeState.INACTIVE
			return;

# Called when the node enters godot to string the scene tree for the first time.
func _ready() -> void:
	loadYarnFile("testScript.yarn")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	runDialogue()
	label.text = getDialogue()
	label_2.text = getSpeaker()
	
	if(Input.is_action_just_pressed("Accept")):
		if(!isStopped()):
			continueLine()
		if(currentNodeState == nodeState.INACTIVE):
			goToNode("Start")
	
	if(isStopped()):
		
		
		
		if(Input.is_action_just_pressed("Accept")):
			chooseQuestion(0)
