local helperFile = require('common/HelperFile')
local helperString = require('common/HelperString')
local helperSystemInfo = require('common/HelperSystemInfo')

local isRunning
local cron
local javaProcessName
local jpsFile
local jmapheapFile
local jmapdumpFile

local patternResult
local schedulerResult

local myResultMessage =
	{

		["timestamp"] = nil,
		["hostname"] = 	nil,
		["fileName"] 	= nil,

		testRunInfo =
			{
				["project"] 		= nil,
				["testRunID"] 	= nil,
				["valoVersion"] = nil
			},

		HeapConfiguration =
			{
				["MinHeapFreeRatio"] 	= nil,
				["MaxHeapFreeRatio"] 	= nil,
				["MaxHeapSize_MB"] 		= nil,
				["NewSize_MB"] 				= nil,
				["MaxNewSize_MB"] 		= nil,
				["OldSize_MB"] 				= nil,
				["NewRatio"] 					= nil,
				["SurvivorRatio"] 		= nil,
				["MetaspaceSize_MB"] 	= nil,
				["CompressedClassSpaceSize_MB"] = nil,
				["MaxMetaspaceSize_MB"] = nil,
				["G1HeapRegionSize_MB"] = nil
			},

		HeapUsageYoungGen =
			{
				["Eden1SurSpace_capacity_MB"] = nil,
				["Eden1SurSpace_used_MB"] = nil,
				["Eden1SurSpace_free_MB"] = nil,
				["Eden1SurSpace_percentUsed"] = nil,
				["EdenSpace_capacity_MB"] = nil,
				["EdenSpace_used_MB"] = nil,
				["EdenSpace_free_MB"] = nil,
				["EdenSpace_percentUsed"] = nil,
				["FromSpace_capacity_MB"] = nil,
				["FromSpace_used_MB"] = nil,
				["FromSpace_free_MB"] = nil,
				["FromSpace_percentUsed"] = nil,
				["ToSpace_capacity_MB"] = nil,
				["ToSpace_used_MB"] = nil,
				["ToSpace_free_MB"] = nil,
				["ToSpace_percentUsed"] = nil
			},

		HeapUsageOldGen =
				{
					["capacity_MB"] = nil,
					["used_MB"] = nil,
					["free_MB"] = nil,
					["percentUsed"] = nil
				}
	}


function processJmapHeapFile(jmapHeapFile)

	local linesFromFile
	local resultRegex
	local resultSend
	local tokens

	linesFromFile = lines_from(jmapHeapFile)

	endConfiguration = false
	endUsageYoungGen = false
	endUsageOldGen = false
	spaceType = ""
	i = 1
	while (linesFromFile[i]~=nil) do

		if (linesFromFile[i] == "Heap Configuration:") then
			i = i+1

			while (not endConfiguration) do

				tokens = Collector.String.tokenize(linesFromFile[i], "=")
				resultRegex = regexFind(tokens[1][1], patternResult[1])

				if (resultRegex[0] == 1) then
					resultRegexMB = ""
					if (resultRegex[1]~=nil and resultRegex[1]~="") then
						resultRegexMB = resultRegex[1]
					else
						resultRegexMB = resultRegex[2]
					end
					myResultMessage["HeapConfiguration"][trim(tokens[1][0]) .. "_MB"] = resultRegexMB
				else
					myResultMessage["HeapConfiguration"][trim(tokens[1][0])] = trim(tokens[1][1])
				end

				i=i+1
				endConfiguration = (trim(tokens[1][0]) == "G1HeapRegionSize")
			end

		end

		if (linesFromFile[i] == "Heap Usage:") then

			while (not endUsageYoungGen) do

				if (linesFromFile[i] == "New Generation (Eden + 1 Survivor Space):") then
						spaceType = "Eden1SurSpace_"
				end

				if (linesFromFile[i] == "Eden Space:") then
						spaceType = "EdenSpace_"
				end

				if (linesFromFile[i] == "From Space:") then
						spaceType = "FromSpace_"
				end

				if (linesFromFile[i] == "To Space:") then
						spaceType = "ToSpace_"
				end

				if (string.find(linesFromFile[i], "=") ~=nil) then

					tokens = Collector.String.tokenize(linesFromFile[i], "=")
					resultRegex = regexFind(tokens[1][1], patternResult[1])

					if (resultRegex[0] == 1) then
						myResultMessage["HeapUsageYoungGen"][spaceType .. trim(tokens[1][0]) .. "_MB"] = resultRegex[1]
					else
						myResultMessage["HeapUsageYoungGen"][spaceType .. trim(tokens[1][0])] = trim(tokens[1][1])
					end

				end
				if (string.find(linesFromFile[i], "used") ~=nil) then
					tokens = Collector.String.tokenize(linesFromFile[i], "used")
					myResultMessage["HeapUsageYoungGen"][spaceType .. "percentUsed"] = string.sub(trim(tokens[1][0]),1,-2)
				end

				i=i+1
				endUsageYoungGen = (string.find(linesFromFile[i], "PS Old Generation") or string.find(linesFromFile[i], "tenured generation") ~=nil)
			end

		end

		if (endUsageYoungGen) then

			while (not endUsageOldGen) do

				if (string.find(linesFromFile[i], "=") ~=nil) then
					tokens = Collector.String.tokenize(linesFromFile[i], "=")
					resultRegex = regexFind(tokens[1][1], patternResult[1])

					if (resultRegex[0] == 1) then
						myResultMessage["HeapUsageOldGen"][trim(tokens[1][0]) .. "_MB"] = resultRegex[1]
					else
						myResultMessage["HeapUsageOldGen"][trim(tokens[1][0])] = trim(tokens[1][1])
					end

				end

				if (string.find(linesFromFile[i], "used") ~=nil) then
					tokens = Collector.String.tokenize(linesFromFile[i], "used")
					myResultMessage["HeapUsageOldGen"]["percentUsed"] = string.sub(trim(tokens[1][0]),1,-2)
				end

				i=i+1
				endUsageOldGen = (string.find(linesFromFile[i], "interned Strings occupying") ~=nil)

			end

		end

		i=i+1

	end

	resultSend = Collector.Connector.send("MSG_JMAP_HEAP", myResultMessage)
	if resultSend[0] ~= 0 then
		print("error while calling send method ('" .. resultSend[1] .. "')")
	end

end


function taskToRun()

	local jPID
	local epochNow
	local timeFile
	local heapFile
	local dumpFile

	jPID = getJPSPID(javaProcessName, jpsFile)

	if (jPID == -1) then

		print(javaProcessName .. " PID not found for jmap")

	else

		epochNow = os.time()
		timeFile = Collector.DateTime.epochToString("%Y-%m-%d_%H-%M-%S", epochNow)[1]
		heapFile = jmapheapFile .. "_" .. timeFile .. ".out"
		dumpFile = jmapdumpFile .. "_" .. timeFile .. ".out"

		myResultMessage["timestamp"] = (epochNow*1000)
		myResultMessage["fileName"] = heapFile

		jmap("heap", jPID, heapFile)
		jmap("dump", jPID, dumpFile)
		processJmapHeapFile(heapFile)

	end

end


function OnBeforeStart(config)

	--Code...
	cron 						= config['cron']
	javaProcessName = config['javaProcessName']
	jpsFile					= config['jpsFile']
	jmapheapFile		= config['jmapheapFile']
	jmapdumpFile 		= config['jmapdumpFile']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']
	myResultMessage["hostname"] = Collector.Network.getHostName()[1]

	patternResult = Collector.RegEx.createPattern("\\((.*)MB\\)|(\\d*) MB")
	schedulerResult = Collector.Scheduler.createScheduler(taskToRun)

	isRunning = true
	print("The jmap bundle is running in: " .. helperSystemInfo["os-name"] .. "\n")

end


function OnStart()

	Collector.Scheduler.addCronTask(schedulerResult[1], cron)

	while (isRunning)  do
		Collector.DateTime.sleepMilliseconds(100)
	end

end


function OnBeforeStop()
	isRunning = false
	Collector.Scheduler.destroyScheduler(schedulerResult[1])
	Collector.RegEx.destroyPattern(patternResult[1])
end
