local helperFile = require('common/HelperFile')

local isRunning
local timeLoop
local csvPath
local linesFromFile
local heads
local line
local countFields
local countLines
local resultSend

local myResultMessage = {

	testRunInfo = {}

}


function OnBeforeStart(config)

	--Code...
	timeLoop = config['timeLoopMilli']
	csvPath = config['csvPath']

	isRunning = true

end

function OnStart()

	linesFromFile = lines_from(csvPath)

	heads = Collector.String.tokenize(linesFromFile[1], ",")

	countFields = 0
	for k,v in pairs(heads[1]) do
		countFields = countFields+1
	end

	countLines = 0
	for k,v in pairs(linesFromFile) do
		countLines = countLines+1
	end

	i = 2
	while (i<=countLines and isRunning)  do

		line = Collector.String.tokenize(linesFromFile[i], ",")

		for j=0, countFields-1 do

			nested = Collector.String.tokenize(heads[1][j], ".")

			if (nested[1][0] ~=nil) then
				myResultMessage[nested[1][0]][nested[1][1]] = line[1][j]
			else

				if heads[1][j] == "timestamp" then
						myResultMessage[heads[1][j]] = tonumber(line[1][j])
				else
						myResultMessage[heads[1][j]] = line[1][j]
				end


			end

		end

		resultSend = Collector.Connector.send("MSG_FROMCSV", myResultMessage)
		if resultSend[0] ~= 0 then
			print("error while calling method ('" .. resultSend[1] .. "')")
		end

		Collector.DateTime.sleepMilliseconds(timeLoop)
		i=i+1

	end

end

function OnBeforeStop()

	isRunning = false

end
