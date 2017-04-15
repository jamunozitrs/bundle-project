local helperFile = require('common/HelperFile')
local helperString = require('common/HelperString')
local helperSystemInfo = require('common/HelperSystemInfo')

local isRunning
local cron
local javaProcessName
local jpsFile
local pmapFile
local regexToFind

local patternResult
local schedulerResult

local myResultMessage =
	{

		["timestamp"] = nil,
		["hostname"] = 	nil,
		["fileName"] = nil,

		testRunInfo =
			{
				["project"] = nil,
				["testRunID"] = nil,
				["valoVersion"] = nil
			},

		["address"] = nil,
		["kbytes"] = nil,
		["rss"] = nil,
		["dirty"] = nil,
		["mode"] = nil,
		["mapping"] = nil,
	}


function processPmapFile(pmapFile)

	local resultRegex
	local resultSend
	local linesFromFile
	local i

	linesFromFile = lines_from(pmapFile)

	i = 3
	while (linesFromFile[i]~=nil) do

		resultRegex = regexFind(linesFromFile[i], patternResult[1])

		if (resultRegex[0] == 1) then
			loadMessage(resultRegex, time)
			resultSend = Collector.Connector.send("MSG_PMAP", myResultMessage)

			if resultSend[0] ~= 0 then
				print("error while calling method ('" .. resultSend[1] .. "')")
			end

		end

		i=i+1

	end

end


function loadMessage(auxM)

	myResultMessage["address"] = auxM[1]
	myResultMessage["kbytes"] = auxM[2]
	myResultMessage["rss"] = auxM[3]
	myResultMessage["dirty"] = auxM[4]
	myResultMessage["mode"] = auxM[5]
	myResultMessage["mapping"] = auxM[6]

end


function taskToRun()

	local outFile
	local jPID
	local epochNow
	local timeFile

	jPID = getJPSPID(javaProcessName, jpsFile)

	if (jPID == -1) then

		print(javaProcessName .. " PID not found for pmap")

	else

		epochNow = os.time()
		timeFile = Collector.DateTime.epochToString("%Y-%m-%d_%H-%M-%S", epochNow)[1]
		outFile = pmapFile .. "_" .. timeFile .. ".out"

		myResultMessage["timestamp"] = (epochNow*1000)
		myResultMessage["fileName"] = outFile

		pmap(jPID, outFile)
		processPmapFile(outFile, epochNow)

	end

end


function OnBeforeStart(config)

	--Code...
	cron 						= config['cron']
	javaProcessName = config['javaProcessName']
	jpsFile					= config['jpsFile']
	pmapFile				= config['pmapFile']

	myResultMessage["testRunInfo"]["project"]			= config['project']
	myResultMessage["testRunInfo"]["testRunID"]  	= config['testRunID']
	myResultMessage["testRunInfo"]["valoVersion"] = config['valoVersion']
	myResultMessage["hostname"] = Collector.Network.getHostName()[1]

	regexToFind = "(\\S+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\S+)\\s+(.+)"
	patternResult = Collector.RegEx.createPattern(regexToFind)
	schedulerResult = Collector.Scheduler.createScheduler(taskToRun)

	isRunning = true
	print("The pmap bundle is running in: " .. helperSystemInfo["os-name"] .. "\n")

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
